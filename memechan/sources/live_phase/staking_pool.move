module memechan::staking_pool {
    use std::type_name::{Self, TypeName};
    use sui::object::{Self, ID, UID};
    use sui::table::{Self, Table};
    use sui::balance::Balance;
    use sui::token::{Self, Token, TokenPolicy};
    use sui::clock::{Self, Clock};
    use sui::balance;
    use sui::dynamic_field as df;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::tx_context::{sender, TxContext};

    use memechan::token_ir;
    use memechan::utils::ticket_cap_key;
    use memechan::fee_distribution::{Self, FeeState};
    use memechan::vesting::{
        Self, VestingData, VestingConfig, accounting_key,
    };
    use clamm::interest_pool::InterestPool;
    use clamm::interest_clamm_volatile as volatile;
    use clamm::curves::Volatile;

    use clamm::pool_admin::PoolAdmin;

    friend memechan::go_live;

    struct StakingPool<phantom Meme, phantom S, phantom LP> has key, store {
        id: UID,
        amm_pool: ID,
        balance_meme: Balance<Meme>,
        balance_lp: Balance<LP>,
        vesting_config: VestingConfig,
        fee_state: FeeState<Meme, S>,
        pool_admin: PoolAdmin,
        ticket_type: TypeName,
        fields: UID,
    }

    public(friend) fun new<M, S, Meme, LP>(
        amm_pool: ID,
        balance_meme: Balance<Meme>,
        balance_lp: Balance<LP>,
        vesting_config: VestingConfig,
        pool_admin: PoolAdmin,
        fields: UID,
        ctx: &mut TxContext,
    ): StakingPool<Meme, S, LP> {

        let stake_total = balance::value(&balance_lp);

        StakingPool {
            id: object::new(ctx),
            amm_pool,
            balance_meme,
            balance_lp,
            vesting_config,
            fee_state: fee_distribution::new<Meme, S>(stake_total, ctx),
            pool_admin,
            ticket_type: type_name::get<M>(),
            fields
        }
    }

    // Yields back staked `M` in return for the underlying `Meme` token in
    // and the CLAMM `LP` tokens.
    public fun unstake<M, S, Meme, LP>(
        staking_pool: &mut StakingPool<Meme, S, LP>,
        coin_x: Token<M>,
        policy: &TokenPolicy<M>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Coin<Meme>, Coin<S>) {
        let vesting_table: &mut Table<address, VestingData> = df::borrow_mut(&mut staking_pool.fields, accounting_key());
        let vesting_data = table::borrow(vesting_table, sender(ctx));
        
        let amount_available_to_release = vesting::to_release(
            vesting_data,
            &staking_pool.vesting_config,
            clock::timestamp_ms(clock)
        );

        let release_amount = token::value(&coin_x);
        assert!(release_amount <= amount_available_to_release, 0);
        let vesting_data = table::borrow_mut(vesting_table, sender(ctx));

        let vesting_old = vesting::current_stake(vesting_data);

        let (balance_meme, balance_sui) = fee_distribution::update_stake(vesting_old, release_amount, &mut staking_pool.fee_state, ctx);

        vesting::release(vesting_data, release_amount);

        let treasury_cap_m: &mut TreasuryCap<M> = df::borrow_mut(
            &mut staking_pool.fields,
            ticket_cap_key()
        );

        coin::burn(
            treasury_cap_m,
            token_ir::to_coin(policy, coin_x, ctx),
        );

        balance::join(&mut balance_meme, balance::split(&mut staking_pool.balance_meme, release_amount));

        (
            coin::from_balance(balance_meme, ctx),
            coin::from_balance(balance_sui, ctx)
        )
    }

    public fun withdraw_fees<Meme, S, LP>(staking_pool: &mut StakingPool<Meme, S, LP>, ctx: &mut TxContext): (Coin<Meme>, Coin<S>) {
        let vesting_table: &Table<address, VestingData> = df::borrow(&staking_pool.fields, accounting_key());
        let vesting_data = table::borrow(vesting_table, sender(ctx));

        let (balance_meme, balance_sui) = fee_distribution::withdraw(&mut staking_pool.fee_state, vesting::current_stake(vesting_data), ctx);

        (
            coin::from_balance(balance_meme, ctx),
            coin::from_balance(balance_sui, ctx)
        )
    }

    

    public fun collect_fees<Meme, S, LP>(
        staking_pool: &mut StakingPool<Meme, S, LP>,
        pool: &mut InterestPool<Volatile>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let req = volatile::balances_request<LP>(pool);

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
        
        
        fee_distribution::add_fees<Meme, S>(&mut staking_pool.fee_state, coin_meme, coin_sui);
    }
}