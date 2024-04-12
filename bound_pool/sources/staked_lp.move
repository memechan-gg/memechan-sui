module amm::staked_lp {

    use sui::object::{Self, UID, delete};
    use sui::coin::{Self, Coin};
    use sui::balance::Balance;
    use sui::tx_context::TxContext;
    use sui::clock::{Self, Clock};

    use amm::errors::lp_stake_time_not_passed;

    const SELL_DELAY_MS: u64 = 12 * 3600 * 1000;

    struct StakedLP<phantom CoinX> has key, store {
        id: UID,
        balance: Balance<CoinX>,
        until_timestamp: u64,
    }

    public fun new<CoinX>(balance: Balance<CoinX>, clock: &Clock, ctx: &mut TxContext): StakedLP<CoinX> {
        StakedLP  { id: object::new(ctx), balance, until_timestamp: clock::timestamp_ms(clock) + SELL_DELAY_MS }
    }

    public fun into_coin<CoinX>(staked_lp: StakedLP<CoinX>, clock: &Clock, ctx: &mut TxContext): Coin<CoinX> {
        let StakedLP { id, balance, until_timestamp } = staked_lp;

        assert!(clock::timestamp_ms(clock) >= until_timestamp, lp_stake_time_not_passed());

        delete(id);
        
        coin::from_balance(balance, ctx)
    }
}