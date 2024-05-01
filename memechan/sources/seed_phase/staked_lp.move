module memechan::staked_lp {
    use sui::object::{Self, UID, delete};
    use sui::balance::{Self, Balance};
    use sui::tx_context::TxContext;
    use sui::clock::{Self, Clock};
    use sui::token::{Token, TokenPolicy};
    use memechan::token_ir;

    friend memechan::seed_pool;

    // ===== Constants =====

    const DEFAULT_SELL_DELAY_MS: u64 = 12 * 3600 * 1000;
    public fun default_sell_delay_ms(): u64 { DEFAULT_SELL_DELAY_MS }
    
    // ===== Errors =====

    const ELPStakeTimeNotPassed: u64 = 0;

    // ===== Structs =====

    struct StakedLP<phantom Meme> has key, store {
        id: UID,
        balance: Balance<Meme>,
        until_timestamp: u64,
    }

    // ===== Public Functions =====

    public fun into_token<Meme>(staked_lp: StakedLP<Meme>, clock: &Clock, policy: &TokenPolicy<Meme>, ctx: &mut TxContext): Token<Meme> {
        let StakedLP { id, balance, until_timestamp } = staked_lp;

        assert!(clock::timestamp_ms(clock) >= until_timestamp, ELPStakeTimeNotPassed);

        delete(id);
        
        token_ir::from_balance(policy, balance, ctx)
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

    // ===== Getters =====

    public fun balance<Meme>(staked_lp: &StakedLP<Meme>): u64 {
        balance::value(&staked_lp.balance)
    }
    
    public fun until_ts<Meme>(staked_lp: &StakedLP<Meme>): u64 {
        staked_lp.until_timestamp
    }

    // ===== Friend Functions =====

    public(friend) fun new<Meme>(balance: Balance<Meme>, sell_delay_ms: u64, clock: &Clock, ctx: &mut TxContext): StakedLP<Meme> {
        StakedLP  { id: object::new(ctx), balance, until_timestamp: clock::timestamp_ms(clock) + sell_delay_ms }
    }


    // ===== Test Functions =====

    #[test_only]
    public fun destroy_for_testing<Meme>(staked_lp: StakedLP<Meme>) {
        let StakedLP { id, balance, until_timestamp: _ }  = staked_lp;
        balance::destroy_for_testing(balance);
        delete(id);
    }

    #[test_only]
    public fun into_token_for_testing<Meme>(staked_lp: StakedLP<Meme>, policy: &TokenPolicy<Meme>, ctx: &mut TxContext): Token<Meme> {
        let StakedLP { id, balance, until_timestamp: _ } = staked_lp;

        delete(id);
        
        token_ir::from_balance(policy, balance, ctx)
    }
}