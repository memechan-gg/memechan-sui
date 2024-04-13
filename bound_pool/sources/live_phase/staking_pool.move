module amm::staking_pool {
    use sui::object::{Self, ID, UID};
    use sui::table::{Self, Table};
    use sui::balance::Balance;
    use sui::token::{Self, Token, TokenPolicy};
    use sui::clock::{Self, Clock};
    use sui::balance;
    use sui::coin::{Self, Coin};
    use sui::tx_context::{sender, TxContext};

    use amm::vesting::{Self, VestingData, VestingConfig};
    use amm::token_ir;

    friend amm::initialize;

    struct StakingPool<phantom CoinX, phantom Meme: key, phantom LP: key> has key, store {
        id: UID,
        amm_pool: ID,
        balance_meme: Balance<Meme>,
        balance_lp: Balance<LP>,
        balance_x: Balance<CoinX>,
        vesting_data: Table<address, VestingData>,
        vesting_config: VestingConfig,
        fields: UID,
    }

    public(friend) fun new<CoinX: key, Meme: key, LP: key>(
        amm_pool: ID,
        balance_meme: Balance<Meme>,
        balance_lp: Balance<LP>,
        vesting_config: VestingConfig,
        fields: UID,
        ctx: &mut TxContext,
    ): StakingPool<CoinX, Meme, LP> {
        StakingPool {
            id: object::new(ctx),
            amm_pool,
            balance_meme,
            balance_lp,
            balance_x: balance::zero(),
            vesting_data: table::new(ctx),
            vesting_config,
            fields
        }
    }
    
    public fun unstake<CoinX: key, Meme: key, LP: key>(
        staking_pool: &mut StakingPool<CoinX, Meme, LP>,
        coin_x: Token<CoinX>,
        policy: &TokenPolicy<CoinX>,
        clock: &Clock,
        ctx: &mut TxContext,
    ): Coin<Meme> {        
        let vesting_data = table::borrow(&staking_pool.vesting_data, sender(ctx));
        
        let amount_available_to_release = vesting::to_release(
            vesting_data,
            &staking_pool.vesting_config,
            clock::timestamp_ms(clock)
        );

        let release_amount = token::value(&coin_x);
        assert!(release_amount <= amount_available_to_release, 0);
        let vesting_data = table::borrow_mut(&mut staking_pool.vesting_data, sender(ctx));
        vesting::release(vesting_data, release_amount);

        balance::join(&mut staking_pool.balance_x, token_ir::into_balance(policy, coin_x, ctx));

        coin::from_balance(
            balance::split(&mut staking_pool.balance_meme, release_amount), ctx
        )
    }
}