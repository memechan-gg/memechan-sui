module memechan::staked_lp {
    use sui::object::{Self, UID, delete};
    use sui::balance::{Self, Balance};
    use sui::tx_context::TxContext;
    use sui::clock::{Self, Clock};
    use sui::token::{Token, TokenPolicy};
    use memechan::token_ir;

    use memechan::errors::lp_stake_time_not_passed;

    const SELL_DELAY_MS: u64 = 12 * 3600 * 1000;

    struct StakedLP<phantom CoinX> has key, store {
        id: UID,
        balance: Balance<CoinX>,
        until_timestamp: u64,
    }

    public fun new<CoinX>(balance: Balance<CoinX>, clock: &Clock, ctx: &mut TxContext): StakedLP<CoinX> {
        StakedLP  { id: object::new(ctx), balance, until_timestamp: clock::timestamp_ms(clock) + SELL_DELAY_MS }
    }

    public fun into_token<CoinX>(staked_lp: StakedLP<CoinX>, clock: &Clock, policy: &TokenPolicy<CoinX>, ctx: &mut TxContext): Token<CoinX> {
        let StakedLP { id, balance, until_timestamp } = staked_lp;

        assert!(clock::timestamp_ms(clock) >= until_timestamp, lp_stake_time_not_passed());

        delete(id);
        
        token_ir::from_balance(policy, balance, ctx)
    }

    public fun balance<CoinX>(staked_lp: &StakedLP<CoinX>): u64 {
        balance::value(&staked_lp.balance)
    }

    // Note: inherits latest timestamp, use with care.
    public entry fun join<T>(self: &mut StakedLP<T>, c: StakedLP<T>) {
        let StakedLP { id, balance, until_timestamp } = c;
        
        let ts = if (until_timestamp > self.until_timestamp) {until_timestamp} else {self.until_timestamp};
        self.until_timestamp = ts;
        object::delete(id);
        balance::join(&mut self.balance, balance);
    }

    public fun split<T>(
        self: &mut StakedLP<T>, split_amount: u64, ctx: &mut TxContext
    ): StakedLP<T> {
        StakedLP {
            id: object::new(ctx),
            balance: balance::split(&mut self.balance, split_amount),
            until_timestamp: self.until_timestamp,
        }
    }

    #[test_only]
    public fun destroy_for_testing<CoinX>(staked_lp: StakedLP<CoinX>) {
        let StakedLP { id, balance, until_timestamp: _ }  = staked_lp;
        balance::destroy_for_testing(balance);
        delete(id);
    }
}