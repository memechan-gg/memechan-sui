module memechan::staking_pool {
    use sui::object::{Self, ID, UID};
    use sui::table::{Self, Table};
    use sui::balance::Balance;
    use sui::token::{Self, Token, TokenPolicy, TokenPolicyCap};
    use sui::clock::{Self, Clock};
    use sui::balance;
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

    friend memechan::go_live;

    struct StakingPool<phantom S, phantom Meme, phantom LP> has key, store {
        id: UID,
        amm_pool: ID,
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

        let (balance_meme, balance_sui) = fee_distribution::withdraw_fees_and_update_stake(
            vesting_old,
            release_amount,
            &mut staking_pool.fee_state,
            ctx
        );

        vesting::release(vesting_data, release_amount);

        coin::burn(
            &mut staking_pool.meme_cap,
            token_ir::to_coin(policy, coin_x, ctx),
        );

        balance::join(&mut balance_meme, balance::split(&mut staking_pool.balance_meme, release_amount));

        (
            coin::from_balance(balance_meme, ctx),
            coin::from_balance(balance_sui, ctx)
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

        let min_amounts = vector[1, 1,];

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
        let vesting_data = table::borrow(&staking_pool.vesting_table, sender(ctx));

        let amount_available_to_release = vesting::to_release(
            vesting_data,
            &staking_pool.vesting_config,
            clock::timestamp_ms(clock)
        );

        amount_available_to_release
    }

}