module memechan::token_ir {
    use sui::object::{Self, UID, id_to_address};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::Balance;
    use sui::tx_context::TxContext;
    use sui::dynamic_field as df;
    use sui::token::{Self, Token, ActionRequest, TokenPolicy};

    friend memechan::bound_curve_amm;
    friend memechan::staked_lp;
    friend memechan::staking_pool;

    struct Witness has drop {}

    struct PolicyCapDfKey<phantom T> has store, copy, drop {}

    public(friend) fun init_token<T>(
        pool_uid: &mut UID,
        treasury_cap: &TreasuryCap<T>,
        ctx: &mut TxContext
     ): (TokenPolicy<T>, address) {
        let (policy, cap) = token::new_policy(treasury_cap, ctx);
        let policy_id = object::id(&policy);

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

        df::add(pool_uid, PolicyCapDfKey<T> {}, cap);

        (policy, id_to_address(&policy_id))
    }

    // coin::take(&mut pool_state.admin_balance_y, amount_y, ctx)
    
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