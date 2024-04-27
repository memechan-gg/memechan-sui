module memechan::staking_pool {
    use sui::object::{Self, ID, UID};
    use sui::table::{Self, Table};
    use sui::balance::Balance;
    use sui::token::{Self, Token, TokenPolicy};
    use sui::clock::{Self, Clock};
    use sui::balance;
    use sui::coin::{Self, Coin};
    use sui::tx_context::{sender, TxContext};

    use memechan::vesting::{Self, VestingData, VestingConfig};
    use memechan::token_ir;
    use memechan::fee_distribution::{Self, FeeState};

    use clamm::pool_admin::PoolAdmin;

    friend memechan::initialize;

    struct StakingPool<phantom CoinX, phantom Meme, phantom LP> has key, store {
        id: UID,
        amm_pool: ID,
        balance_meme: Balance<Meme>,
        balance_lp: Balance<LP>,
        balance_x: Balance<CoinX>,
        vesting_data: Table<address, VestingData>,
        vesting_config: VestingConfig,
        fee_state: FeeState<Meme, LP>,
        pool_admin: PoolAdmin,
        fields: UID,
    }

    public(friend) fun new<CoinX, Meme, LP>(
        amm_pool: ID,
        balance_meme: Balance<Meme>,
        balance_lp: Balance<LP>,
        vesting_config: VestingConfig,
        pool_admin: PoolAdmin,
        fields: UID,
        ctx: &mut TxContext,
    ): StakingPool<CoinX, Meme, LP> {

        let stake_total = balance::value(&balance_lp);

        StakingPool {
            id: object::new(ctx),
            amm_pool,
            balance_meme,
            balance_lp,
            balance_x: balance::zero(),
            vesting_data: table::new(ctx), // TODO: vesting data should be populated
            vesting_config,
            fee_state: fee_distribution::new(stake_total, ctx),
            pool_admin,
            fields
        }
    }

    public fun unstake<CoinX, Meme, LP>(
        staking_pool: &mut StakingPool<CoinX, Meme, LP>,
        coin_x: Token<CoinX>,
        policy: &TokenPolicy<CoinX>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): (Coin<Meme>, Coin<LP>) {        
        let vesting_data = table::borrow(&staking_pool.vesting_data, sender(ctx));
        
        let amount_available_to_release = vesting::to_release(
            vesting_data,
            &staking_pool.vesting_config,
            clock::timestamp_ms(clock)
        );

        let release_amount = token::value(&coin_x);
        assert!(release_amount <= amount_available_to_release, 0);
        let vesting_data = table::borrow_mut(&mut staking_pool.vesting_data, sender(ctx));

        let vesting_old = vesting::current_stake(vesting_data);

        let (balance_meme, balance_sui) = fee_distribution::update_stake(vesting_old, release_amount, &mut staking_pool.fee_state, ctx);

        vesting::release(vesting_data, release_amount);

        balance::join(&mut staking_pool.balance_x, token_ir::into_balance(policy, coin_x, ctx));

        balance::join(&mut balance_meme, balance::split(&mut staking_pool.balance_meme, release_amount));

        (
            coin::from_balance(balance_meme, ctx),
            coin::from_balance(balance_sui, ctx)
        )
    }

    public fun withdraw_fees<CoinX, Meme, LP>(staking_pool: &mut StakingPool<CoinX, Meme, LP>, ctx: &mut TxContext): (Coin<Meme>, Coin<LP>) {
        
        let vesting_data = table::borrow(&staking_pool.vesting_data, sender(ctx));

        let (balance_meme, balance_sui) = fee_distribution::withdraw(&mut staking_pool.fee_state, vesting::current_stake(vesting_data), ctx);

        (
            coin::from_balance(balance_meme, ctx),
            coin::from_balance(balance_sui, ctx)
        )
    }

    public fun add_fees<CoinX, Meme, LP>(staking_pool: &mut StakingPool<CoinX, Meme, LP>, coin_meme: Coin<Meme>, coin_sui: Coin<LP>) {
        fee_distribution::add_fees(&mut staking_pool.fee_state, coin_meme, coin_sui);
    }
}