module memechan::token_ir {
    use std::vector;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::Balance;
    use sui::tx_context::TxContext;
    use sui::token::{Self, Token, ActionRequest, TokenPolicy, TokenPolicyCap};

    friend memechan::seed_pool;
    friend memechan::staked_lp;
    friend memechan::staking_pool;

    struct Witness has drop {}

    public fun merge<T>(tokens: vector<Token<T>>): Token<T> {
        vector::reverse(&mut tokens);

        let token = vector::pop_back(&mut tokens);
        let len = vector::length(&tokens);

        while (len > 0) {
            let token_ = vector::pop_back(&mut tokens);
            token::join(&mut token, token_);

            len = len -1;
        };

        vector::destroy_empty(tokens);

        token
    }

    public(friend) fun init_token<T>(
        treasury_cap: &TreasuryCap<T>,
        ctx: &mut TxContext
     ): (TokenPolicy<T>, TokenPolicyCap<T>) {
        let (policy, cap) = token::new_policy(treasury_cap, ctx);

        token::add_rule_for_action<T, Witness>(
            &mut policy,
            &cap,
            token::transfer_action(),
            ctx
        );
        
        token::add_rule_for_action<T, Witness>(
            &mut policy,
            &cap,
            token::spend_action(),
            ctx
        );
        
        token::add_rule_for_action<T, Witness>(
            &mut policy,
            &cap,
            token::to_coin_action(),
            ctx
        );
        
        token::add_rule_for_action<T, Witness>(
            &mut policy,
            &cap,
            token::from_coin_action(),
            ctx
        );

        (policy, cap)
    }
    
    public(friend) fun take<T>(
        policy: &TokenPolicy<T>,
        balance: &mut Balance<T>,
        amount: u64,
        ctx: &mut TxContext,
    ): Token<T> {
        let (token, req) = token::from_coin(coin::take(balance, amount, ctx), ctx);
        add_approval(&mut req, ctx);
        token::confirm_request(policy, req, ctx);
        token
    }
    
    public(friend) fun to_coin<T>(
        policy: &TokenPolicy<T>,
        token: Token<T>,
        ctx: &mut TxContext,
    ): Coin<T> {
        let (coin, req) = token::to_coin(token, ctx);
        add_approval(&mut req, ctx);
        token::confirm_request(policy, req, ctx);
        coin
    }

    public(friend) fun from_balance<T>(
        policy: &TokenPolicy<T>,
        balance: Balance<T>,
        ctx: &mut TxContext,
    ): Token<T> {
        let coin = coin::from_balance(balance, ctx);
        let (token, req) = token::from_coin(coin, ctx);
        add_approval(&mut req, ctx);
        token::confirm_request(policy, req, ctx);
        token
    }
    
    public(friend) fun into_balance<T>(
        policy: &TokenPolicy<T>,
        token: Token<T>,
        ctx: &mut TxContext,
    ): Balance<T> {
        let (coin, req) = token::to_coin(token, ctx);
        add_approval(&mut req, ctx);
        token::confirm_request(policy, req, ctx);
        coin::into_balance(coin)
    }
    
    public(friend) fun transfer<T>(
        policy: &TokenPolicy<T>,
        token: Token<T>,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let req = token::transfer(token, recipient, ctx);
        add_approval(&mut req, ctx);
        token::confirm_request(policy, req, ctx);
    }

    // === Private Functions ===

    fun add_approval<T>(
        request: &mut ActionRequest<T>,
        ctx: &mut TxContext,
    ) {
        token::add_approval(Witness {}, request, ctx);
    }
}