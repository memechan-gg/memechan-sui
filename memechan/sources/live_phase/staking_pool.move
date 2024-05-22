module memechan::staking_pool {
    use sui::object::{Self, ID, UID};
    use sui::table::{Self, Table};
    use sui::balance::{Self, Balance};
    use sui::token::{Self, Token, TokenPolicy, TokenPolicyCap};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::tx_context::{sender, TxContext};

    use memechan::token_ir;
    use memechan::fee_distribution::{Self, FeeState};
    use memechan::vesting::{
        Self, VestingData, VestingConfig,
    };
    use clamm::interest_pool::InterestPool;
    use clamm::interest_clamm_volatile as volatile;
    use clamm::curves::Volatile;

    use clamm::pool_admin::PoolAdmin;

    #[test_only]
    use sui::test_utils::assert_eq;

    const PRECISION: u128 = 1_000_000_000; // 1e9

    friend memechan::go_live;

    struct StakingPool<phantom S, phantom Meme, phantom LP> has key, store {
        id: UID,
        amm_pool: ID,
        // Deprecated!
        balance_meme: Balance<Meme>,
        balance_lp: Balance<LP>,
        vesting_table: Table<address, VestingData>,
        meme_cap: TreasuryCap<Meme>,
        policy_cap: TokenPolicyCap<Meme>,
        vesting_config: VestingConfig,
        fee_state: FeeState<S, Meme>,
        pool_admin: PoolAdmin,
    }

    public(friend) fun new<S, Meme, LP>(
        amm_pool: ID,
        stake_total: u64,
        balance_lp: Balance<LP>,
        vesting_config: VestingConfig,
        pool_admin: PoolAdmin,
        meme_cap: TreasuryCap<Meme>,
        policy_cap: TokenPolicyCap<Meme>,
        vesting_table: Table<address, VestingData>,
        ctx: &mut TxContext,
    ): StakingPool<S, Meme, LP> {
        let staking_pool = StakingPool {
            id: object::new(ctx),
            amm_pool,
            // Deprecated!
            balance_meme: balance::zero(),
            balance_lp,
            meme_cap,
            policy_cap,
            vesting_table,
            vesting_config,
            fee_state: fee_distribution::new<S, Meme>(stake_total, ctx),
            pool_admin,
        };

        staking_pool
    }

    // Yields back staked `M` in return for the underlying `Meme` token in
    // and the CLAMM `LP` tokens.
    public fun unstake<S, Meme, LP>(
        staking_pool: &mut StakingPool<S, Meme, LP>,
        coin_x: Token<Meme>,
        policy: &TokenPolicy<Meme>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Coin<Meme>, Coin<S>) {
        let vesting_data = table::borrow(&staking_pool.vesting_table, sender(ctx));
        
        let amount_available_to_release = vesting::to_release(
            vesting_data,
            &staking_pool.vesting_config,
            clock::timestamp_ms(clock)
        );

        let release_amount = token::value(&coin_x);
        assert!(release_amount <= amount_available_to_release, 0);
        let vesting_data = table::borrow_mut(&mut staking_pool.vesting_table, sender(ctx));

        let vesting_old = vesting::current_stake(vesting_data);

        let (meme_fee_bal, sui_fee_bal) = fee_distribution::withdraw_fees_and_update_stake(
            vesting_old,
            release_amount,
            &mut staking_pool.fee_state,
            ctx
        );

        vesting::release(vesting_data, release_amount);

        let stake = token_ir::to_coin(policy, coin_x, ctx);
        let stake_bal = coin::balance_mut(&mut stake);

        balance::join(stake_bal, meme_fee_bal);

        (
            stake,
            coin::from_balance(sui_fee_bal, ctx)
        )
    }

    public fun withdraw_fees<S, Meme, LP>(staking_pool: &mut StakingPool<S, Meme, LP>, ctx: &mut TxContext): (Coin<Meme>, Coin<S>) {
        let vesting_data = table::borrow(&staking_pool.vesting_table, sender(ctx));
        let (balance_meme, balance_sui) = fee_distribution::withdraw_fees(&mut staking_pool.fee_state, vesting::current_stake(vesting_data), ctx);

        (
            coin::from_balance(balance_meme, ctx),
            coin::from_balance(balance_sui, ctx)
        )
    }

    public fun get_fees<S, Meme, LP>(staking_pool: &StakingPool<S, Meme, LP>, ctx: &mut TxContext): (u64, u64) {
        if (!table::contains(&staking_pool.vesting_table, sender(ctx))) return (0, 0);

        let vesting_data = table::borrow(&staking_pool.vesting_table, sender(ctx));
        let (meme_amount, sui_amount) = fee_distribution::get_fees_to_withdraw(
            &staking_pool.fee_state,
            vesting::current_stake(vesting_data),
            ctx
        );

        (meme_amount, sui_amount)
    }

    // TODO: Add getters
    public fun collect_fees<S, Meme, LP>(
        staking_pool: &mut StakingPool<S, Meme, LP>,
        pool: &mut InterestPool<Volatile>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let req = volatile::balances_request<LP>(pool);
        volatile::read_balance<S, LP>(pool, &mut req);
        volatile::read_balance<Meme, LP>(pool, &mut req);

        let lp_coin = volatile::claim_admin_fees<LP>(
            pool,
            &staking_pool.pool_admin,
            clock,
            req,
            ctx,
        );

        if (coin::value(&lp_coin) == 0) {
            coin::destroy_zero(lp_coin);
            return
        };

        let min_amounts = vector[1, 1,];

        let staking_pool_balance = balance::value(&staking_pool.balance_lp);
        let total_lp_balance = volatile::lp_coin_supply<LP>(pool);

        let amount_to_take = calculate_admin_amount(total_lp_balance, staking_pool_balance, coin::value(&lp_coin));
        
        // The default admin fees are 20% of all the fees. 
        let extra_fees = coin::take(&mut staking_pool.balance_lp, amount_to_take, ctx);

        coin::join(&mut lp_coin, extra_fees);

        let (coin_sui, coin_meme) = volatile::remove_liquidity_2_pool<S, Meme, LP>(
            pool,
            lp_coin,
            min_amounts,
            ctx,
        );
        
        fee_distribution::add_fees<S, Meme>(&mut staking_pool.fee_state, coin_meme, coin_sui);
    }

    public fun vesting_table<S, Meme, LP>(pool: &StakingPool<S, Meme, LP>): &Table<address, VestingData> {
        &pool.vesting_table
    }
    public fun vesting_table_len<S, Meme, LP>(pool: &StakingPool<S, Meme, LP>): u64 {
        table::length(&pool.vesting_table)
    }

    public fun available_amount_to_unstake<S, Meme, LP>(
        staking_pool: &mut StakingPool<S, Meme, LP>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): u64 {
        if (!table::contains(&staking_pool.vesting_table, sender(ctx))) return 0;

        let vesting_data = table::borrow(&staking_pool.vesting_table, sender(ctx));

        let amount_available_to_release = vesting::to_release(
            vesting_data,
            &staking_pool.vesting_config,
            clock::timestamp_ms(clock)
        );

        amount_available_to_release
    }

    public fun total_supply<S, Meme, LP>(staking_pool: &StakingPool<S, Meme, LP>): u64 {
        coin::total_supply(&staking_pool.meme_cap)
    }

    public fun fee_state<S, Meme, LP>(staking_pool: &StakingPool<S, Meme, LP>): &FeeState<S, Meme> {
        &staking_pool.fee_state
    }

    public fun balance_lp<S, Meme, LP>(staking_pool: &StakingPool<S, Meme, LP>): &Balance<LP> {
        &staking_pool.balance_lp
    }
    
    public fun end_ts<S, Meme, LP>(self: &StakingPool<S, Meme, LP>): u64 { vesting::end_ts(&self.vesting_config) }

    fun calculate_admin_amount(total_lp_balance:u64, staking_pool_balance: u64, admin_amount: u64): u64 {
        let (staking_pool_balance, total_lp_balance, admin_amount) = (
            (staking_pool_balance as u128),
            (total_lp_balance as u128),
            (admin_amount as u128) * 4
        );

        let percentage_owned = staking_pool_balance * PRECISION / total_lp_balance;

        ((admin_amount * percentage_owned / PRECISION) as u64) / 2
    }

    public(friend) fun remove_extra_liquidity_start<S, Meme, LP>(
        self: &mut StakingPool<S, Meme, LP>,
        ctx: &mut TxContext
    ): Coin<LP> {
        let lp_balance = balance::value(&self.balance_lp);
        coin::from_balance(balance::split(&mut self.balance_lp, lp_balance), ctx)
    }
    
    public(friend) fun remove_extra_liquidity_collect<S, Meme, LP>(
        self: &mut StakingPool<S, Meme, LP>,
        meme_coins: Coin<Meme>,
        lp_coin: Coin<LP>,
    ) {
        coin::burn(&mut self.meme_cap, meme_coins);
        balance::join(&mut self.balance_lp, coin::into_balance(lp_coin));
    }

    // Tests

    #[test]
    fun test_calculate_admin_amount() {

        // We own 20% of all protocol fees.
        // This means that the remaining 80% fees can be found by calculating our amount * 4
        // We only take 50% of the trading fees we earned to compensate other LPs for IP.
        // 8 * 0.2 / 2 = 0.8 ~ 0
        assert_eq(calculate_admin_amount(100, 20, 2), 0);

        // 12 * 0.2 / 2 = 1.2 ~ 1 (we own 20% trading fees)
        assert_eq(calculate_admin_amount(100, 20, 3), 1);
        
        // 12 / 2 = 6 (we own all trading fees)
        assert_eq(calculate_admin_amount(100, 100, 3), 6);
        // 12 / 2 = 6 (we own half of all trading fees)
        assert_eq(calculate_admin_amount(100, 50, 3), 3);
    }
}