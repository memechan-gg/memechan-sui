module amm::staked_lp {
    use sui::object::{Self, UID, delete};
    use sui::balance::Balance;
    use sui::tx_context::TxContext;
    use sui::clock::{Self, Clock};
    use sui::token::{Token, TokenPolicy};
    use amm::token_ir;

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

    public fun into_coin<CoinX>(staked_lp: StakedLP<CoinX>, clock: &Clock, policy: &TokenPolicy<CoinX>, ctx: &mut TxContext): Token<CoinX> {
        let StakedLP { id, balance, until_timestamp } = staked_lp;

        assert!(clock::timestamp_ms(clock) >= until_timestamp, lp_stake_time_not_passed());

        delete(id);
        
        token_ir::from_balance(policy, balance, ctx)
    }
}