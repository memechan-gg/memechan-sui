module memechan::bound_curve_amm {
    use std::type_name;
    use std::debug::print;

    use sui::object::{Self, UID};
    use sui::dynamic_field as df;
    use sui::table::{Self, Table};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::share_object;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, CoinMetadata, TreasuryCap};
    use sui::clock::Clock;
    use sui::math;
    use sui::token::{Self, Token, TokenPolicy};

    use memechan::math256::pow_2;
    use memechan::utils::mist;
    use suitears::math256::sqrt_down;

    use memechan::index::{Self, Registry, policies_mut};
    use memechan::utils;
    use memechan::errors;
    use memechan::staked_lp;
    use memechan::events;
    use memechan::admin::Admin;
    use memechan::fees::{Self, Fees};
    use memechan::curves::Bound;
    use memechan::staked_lp::StakedLP;
    use memechan::token_ir;

    friend memechan::initialize;

    // === Constants ===

    const DEFAULT_ADMIN_FEE: u256 = 5_000_000_000_000_000; // 0.5%

    const DEFAULT_PRICE_FACTOR: u64 = 2;
    const DEFAULT_MAX_M_LP: u256 = 200_000_000_000_000;
    const DEFAULT_MAX_M: u256 = 900_000_000_000_000;
    const DEFAULT_MAX_S: u256 =      30_000;

    const DECIMALS_ALPHA: u256 = 1_000_000; // consider increase
    const DECIMALS_BETA: u256 = 1_000_000; // consider increase
    // const DECIMALS_ALPHA: u256 = 1_000_000_000_000; // consider increase
    // const DECIMALS_BETA: u256 = 1_000_000_000_000; // consider increase


    /// The amount of Mist per Sui token based on the fact that mist is
    /// 10^-9 of a Sui token
    const DECIMALS_S: u256 = 1_000_000_000;

    public fun default_admin(): u256 { DEFAULT_ADMIN_FEE }
    public fun default_price_factor(): u64 { DEFAULT_PRICE_FACTOR }
    public fun default_gamma_m(): u256 { DEFAULT_MAX_M }
    public fun default_omega_m(): u256 { DEFAULT_MAX_M_LP }
    public fun default_gamma_s(): u256 { DEFAULT_MAX_S }
    // public fun decimals_m(): u256 { DECIMALS_M }
    // public fun decimals_y(): u256 { DECIMALS_S }

    // Errors

    const EBondingCurveMustBeNegativelySloped: u64 = 1;
    const EBondingCurveInterceptMustBePositive: u64 = 1;

    // === Structs ===
    
    struct SeedPool has key {
        id: UID,
        fields: UID,
    }

    struct PoolStateKey has drop, copy, store {}
    struct AccountingDfKey has drop, copy, store {}

    struct PoolState<phantom M, phantom S, phantom Meme> has store {
        /// X --> sMeme token, representing ownership of Meme coin
        balance_m: Balance<M>,
        /// Y --> quote coin, usually SUI
        balance_s: Balance<S>,
        admin_balance_m: Balance<M>,
        admin_balance_s: Balance<S>,
        launch_balance: Balance<Meme>,
        fees: Fees,
        config: Config,
        locked: bool,
    }

    fun gamma_s_mist<M, S, Meme>(
        self: &PoolState<M, S, Meme>,
    ): u64 {
        mist(self.config.gamma_s)
    }

    struct Config has store, drop {
        alpha_abs: u256, // |alpha|, because alpha is negative
        beta: u256,
        price_factor: u64,
        // In sui denomination
        gamma_s: u64,
        // In raw denomination
        gamma_m: u64, // DEFAULT_MAX_M * DECIMALS_M = 900_000_000_000_000
        // In raw denomination
        omega_m: u64, // DEFAULT_MAX_M_LP * DECIMALS_M = 200_000_000_000_000
    }

    struct SwapAmount has store, drop, copy {
        amount_in: u64,
        amount_out: u64,
        admin_fee_in: u64,
        admin_fee_out: u64,
    }

    // === DEX ===

    #[lint_allow(share_owned)]
    public fun new_default<M, S, Meme>(
        registry: &mut Registry,
        ticket_coin_cap: TreasuryCap<M>,
        meme_coin_cap: TreasuryCap<Meme>,
        ticket_coin_metadata: &mut CoinMetadata<M>,
        meme_coin_metadata: &CoinMetadata<Meme>,
        ctx: &mut TxContext
    ) {
        new<M, S, Meme>(
            registry,
            ticket_coin_cap,
            meme_coin_cap,
            ticket_coin_metadata,
            meme_coin_metadata,
            DEFAULT_ADMIN_FEE,
            DEFAULT_ADMIN_FEE,
            DEFAULT_PRICE_FACTOR,
            (default_gamma_s() as u64),
            (default_gamma_m() as u64),
            (default_omega_m() as u64),
            ctx,
        );
    }
    
    #[lint_allow(share_owned)]
    public fun new<M, S, Meme>(
        registry: &mut Registry,
        ticket_coin_cap: TreasuryCap<M>,
        meme_coin_cap: TreasuryCap<Meme>,
        ticket_coin_metadata: &mut CoinMetadata<M>,
        meme_coin_metadata: &CoinMetadata<Meme>,
        fee_in_percent: u256,
        fee_out_percent: u256,
        price_factor: u64,
        gamma_s: u64,
        gamma_m: u64,
        omega_m: u64,
        ctx: &mut TxContext
    ) {
        utils::assert_ticket_coin_integrity<M, S, Meme>(ticket_coin_metadata);
        utils::assert_coin_integrity<M, S, Meme>(&ticket_coin_cap, ticket_coin_metadata, &meme_coin_cap, meme_coin_metadata);

        coin::update_name(&ticket_coin_cap, ticket_coin_metadata, utils::get_ticket_coin_name(meme_coin_metadata));
        coin::update_symbol(&ticket_coin_cap, ticket_coin_metadata, utils::get_ticket_coin_symbol(meme_coin_metadata));

        let launch_coin = coin::mint<Meme>(
            &mut meme_coin_cap,
            ((gamma_m + omega_m) as u64),
            ctx);

        let balance_m: Balance<M> = balance::increase_supply(coin::supply_mut(&mut ticket_coin_cap), (gamma_m as u64));
        let coin_m_value = balance::value(&balance_m);

        let pool = new_pool_internal<Bound, M, S, Meme>(
            registry,
            balance_m,
            coin::zero(ctx),
            launch_coin,
            fee_in_percent,
            fee_out_percent,
            price_factor,
            gamma_s,
            gamma_m,
            omega_m,
            ctx,
        );
        let pool_address = object::uid_to_address(&pool.id);

        let (policy, policy_address) = token_ir::init_token<M>(&mut pool.id, &ticket_coin_cap, ctx);
        table::add(policies_mut(registry), type_name::get<M>(), policy_address);

        events::new_pool<Bound, M, S>(pool_address, coin_m_value, 0, policy_address);

        token::share_policy(policy);
        sui::transfer::public_transfer(ticket_coin_cap, @0x2);
        sui::transfer::public_transfer(meme_coin_cap, @0x2);
        share_object(pool);
    }

    public fun compute_alpha_abs(
        gamma_s: u256,
        gamma_m: u256,
        omega_m: u256,
        price_factor: u64,
    ): u256 {
        let left = omega_m * (price_factor as u256);
        assert!(left < gamma_m, EBondingCurveMustBeNegativelySloped);

        // We compute |alpha|, hence the subtraction is switched
        (2 * ( gamma_m - left ) * DECIMALS_ALPHA) / (pow_2((gamma_s as u256)))
    }
    
    public fun compute_beta(
        gamma_s: u256,
        gamma_m: u256,
        omega_m: u256,
        price_factor: u64,
    ): u256 {
        let left = (2 * gamma_m);
        let right = omega_m * (price_factor as u256);
        assert!(left > right, EBondingCurveInterceptMustBePositive);
      
        (( left - right ) * DECIMALS_BETA) / gamma_s
    }

    // === Public-View Functions ===

    public fun ticket_coin_supply<M, S, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<M, S, Meme>(pool);
        balance::value(&pool_state.balance_m)
    }

    public fun meme_coin_supply<M, S, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<M, S, Meme>(pool);
        balance::value(&pool_state.launch_balance)
    }

    public fun balance_m<M, S, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<M, S, Meme>(pool);
        balance::value(&pool_state.balance_m)
    }

    public fun balance_s<M, S, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<M, S, Meme>(pool);
        balance::value(&pool_state.balance_s)
    }

    public fun fees<M, S, Meme>(pool: &SeedPool): Fees {
        let pool_state = pool_state<M, S, Meme>(pool);
        pool_state.fees
    }

    public fun is_ready_to_launch<M, S, Meme>(pool: &SeedPool): bool {
        let pool_state = pool_state<M, S, Meme>(pool);
        pool_state.locked
    }

    public fun admin_balance_m<M, S, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<M, S, Meme>(pool);
        balance::value(&pool_state.admin_balance_m)
    }

    public fun admin_balance_s<M, S, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<M, S, Meme>(pool);
        balance::value(&pool_state.admin_balance_s)
    }

    // === Admin Functions ===

    public fun take_fees<M, S, Meme>(
        _: &Admin,
        pool: &mut SeedPool,
        policy: &TokenPolicy<M>,
        ctx: &mut TxContext
    ): (Token<M>, Coin<S>) {
        let pool_state = pool_state_mut<M, S, Meme>(pool);

        let amount_x = balance::value(&pool_state.admin_balance_m);
        let amount_y = balance::value(&pool_state.admin_balance_s);

        add_from_token_acc(pool, amount_x, sender(ctx));

        let pool_state = pool_state_mut<M, S, Meme>(pool);

        (
            token_ir::take(policy, &mut pool_state.admin_balance_m, amount_x, ctx),
            coin::take(&mut pool_state.admin_balance_s, amount_y, ctx)
        )
    }

    // === Private Functions ===

    fun new_pool_internal<Curve, M, S, Meme>(
        registry: &mut Registry,
        coin_m: Balance<M>,
        coin_s: Coin<S>,
        launch_coin: Coin<Meme>,
        fee_in_percent: u256,
        fee_out_percent: u256,
        price_factor: u64,
        gamma_s: u64,
        gamma_m: u64,
        omega_m: u64,
        ctx: &mut TxContext
    ): SeedPool {
        let coin_m_value = balance::value(&coin_m);
        let coin_s_value = coin::value(&coin_s);
        let launch_coin_value = coin::value(&launch_coin);

        assert!(coin_m_value == (gamma_m as u64), errors::provide_both_coins());
        assert!(coin_s_value == 0, errors::provide_both_coins());
        assert!(launch_coin_value == ((gamma_m + omega_m) as u64), errors::provide_both_coins());
        
        index::assert_new_pool<Curve, M, S>(registry);

        let pool_state = PoolState {
            balance_m: coin_m,
            balance_s: coin::into_balance(coin_s),
            fees: new_fees(
                fee_in_percent,
                fee_out_percent,
            ),
            locked: false,
            launch_balance: coin::into_balance(launch_coin),
            admin_balance_m: balance::zero(),
            admin_balance_s: balance::zero(),
            config: Config {
                alpha_abs: compute_alpha_abs(
                    (gamma_s as u256),
                    (gamma_m as u256),
                    (omega_m as u256),
                    price_factor,
                ),
                beta: compute_beta(
                    (gamma_s as u256),
                    (gamma_m as u256),
                    (omega_m as u256),
                    price_factor,
                ),
                gamma_s,
                gamma_m,
                omega_m,
                price_factor,
            }
        };

        let pool = SeedPool {
            id: object::new(ctx),
            fields: object::new(ctx),
        };

        let pool_address = object::uid_to_address(&pool.id);

        df::add(fields_mut(&mut pool), PoolStateKey {}, pool_state);
        df::add(fields_mut(&mut pool), AccountingDfKey {}, table::new<address, u64>(ctx));
        
        index::add_seed_pool<Curve, M, S>(registry, pool_address);
        //table::add(&mut registry.lp_coins, type_name::get<LpCoin>(), pool_address);

        pool
    }

    public fun sell_meme<M, S, Meme>(
        pool: &mut SeedPool,
        coin_m: Token<M>,
        coin_s_min_value: u64,
        policy: &TokenPolicy<M>,
        ctx: &mut TxContext
    ): Coin<S> {
        assert!(token::value(&coin_m) != 0, errors::no_zero_coin());

        let pool_address = object::uid_to_address(&pool.id);
        let pool_state = pool_state_mut<M, S, Meme>(pool);
        assert!(!pool_state.locked, errors::pool_is_locked());

        let coin_in_amount = token::value(&coin_m);
        
        let swap_amount = swap_amounts(
            pool_state, 
            coin_in_amount, 
            coin_s_min_value, 
            false,
        );

        if (swap_amount.admin_fee_in != 0) {
            balance::join(&mut pool_state.admin_balance_m, token_ir::into_balance(policy, token::split(&mut coin_m, swap_amount.admin_fee_in, ctx), ctx));
        };

        if (swap_amount.admin_fee_out != 0) {
            balance::join(&mut pool_state.admin_balance_s, balance::split(&mut pool_state.balance_s, swap_amount.admin_fee_out));
        };

        balance::join(&mut pool_state.balance_m, token_ir::into_balance(policy, coin_m, ctx));

        events::swap<M, S, SwapAmount>(pool_address, coin_in_amount, swap_amount);

        let coin_s = coin::take(&mut pool_state.balance_s, swap_amount.amount_out, ctx);

        // We keep track of how much each address ownes of coin_m
        subtract_from_token_acc(pool, coin_in_amount, sender(ctx));
        coin_s
    }

    public fun compute_delta_m<M, S, Meme>(
        self: &PoolState<M, S, Meme>,
        s_a: u64,
        s_b: u64,
    ): u64 {
        let s_a = (s_a as u256);
        let s_b = (s_b as u256);

        let alpha_abs = &self.config.alpha_abs;
        let beta = &self.config.beta;

        let left = (*beta * (s_b - s_a) / (DECIMALS_BETA * DECIMALS_S));
        let right = ( *alpha_abs * ((pow_2(s_b) / pow_2(DECIMALS_S)) - (pow_2(s_a) / pow_2(DECIMALS_S))) ) / (2 * DECIMALS_ALPHA);

        ((left - right) as u64)
    }
    
    public fun compute_delta_s<M, S, Meme>(
        self: &PoolState<M, S, Meme>,
        // s_a: u64,
        s_b: u64,
        delta_m: u64,
    ): u64 {
        let s_b = (s_b as u256);
        print(&s_b);
        let delta_m = (delta_m as u256);

        let alpha_abs = self.config.alpha_abs;
        let beta = self.config.beta;

        let b_hat_abs = (
            (2 * beta * DECIMALS_ALPHA * DECIMALS_S) - (2 * alpha_abs * s_b * DECIMALS_BETA)
            ) / (DECIMALS_ALPHA * DECIMALS_BETA * DECIMALS_S);
        
        // SQRT
        let sqrt_term = sqrt_down((
            (pow_2(b_hat_abs) * DECIMALS_ALPHA) + (8 * delta_m * alpha_abs)
        ) / DECIMALS_ALPHA);


        // let sqrt_i_term = pow_2(
        //     2 * (
        //         (*beta * DECIMALS_ALPHA * DECIMALS_S) - (*alpha_abs * s_a * DECIMALS_BETA)
                
        //         ) / (DECIMALS_ALPHA * DECIMALS_BETA * DECIMALS_S)
        // ) * DECIMALS_ALPHA;

        // let sqrt_ii_term = (8 * *alpha_abs * delta_m);

        // let sqrt_term = sqrt_down(
        //     (sqrt_i_term - sqrt_ii_term) / DECIMALS_ALPHA
        // );

        
        print(&sqrt_term);
        print(&b_hat_abs);
        let num = sqrt_term - b_hat_abs;

        let delta_s = ((num * DECIMALS_ALPHA * DECIMALS_S) / (2 * alpha_abs) as u64);

        print(&delta_s);

        abort(0);

        ((num * DECIMALS_ALPHA * DECIMALS_S) / (2 * alpha_abs) as u64)
    }

    public fun buy_meme<M, S, Meme>(
        pool: &mut SeedPool,
        coin_s: &mut Coin<S>,
        coin_m_min_value: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): StakedLP<M> {
        assert!(coin::value(coin_s) != 0, errors::no_zero_coin());

        let pool_address = object::uid_to_address(&pool.id);
        let pool_state = pool_state_mut<M, S, Meme>(pool);
        assert!(!pool_state.locked, errors::pool_is_locked());

        let coin_in_amount = coin::value(coin_s);

        let swap_amount = swap_amounts(
            pool_state, 
            coin_in_amount, 
            coin_m_min_value,
            true,
        );

        if (swap_amount.admin_fee_in != 0) {
            balance::join(&mut pool_state.admin_balance_s, coin::into_balance(coin::split(coin_s, swap_amount.admin_fee_in, ctx)));
        };

        if (swap_amount.admin_fee_out != 0) {
            balance::join(&mut pool_state.admin_balance_m, balance::split(&mut pool_state.balance_m, swap_amount.admin_fee_out)); 
        };

        balance::join(&mut pool_state.balance_s, coin::into_balance(coin::split(coin_s, swap_amount.amount_in, ctx)));

        events::swap<S, M, SwapAmount>(pool_address, coin_in_amount,swap_amount);

        let swap_amount = swap_amount.amount_out;
        let staked_lp = staked_lp::new(balance::split(&mut pool_state.balance_m, swap_amount), clock, ctx);

        if (balance::value(&pool_state.balance_m) == 0) {
            pool_state.locked = true;
        };

        // We keep track of how much each address ownes of coin_m
        add_from_token_acc(pool, swap_amount, sender(ctx));
        staked_lp
    }

    fun new_fees(
        fee_in_percent: u256,
        fee_out_percent: u256,
    ): Fees {
        fees::new(fee_in_percent, fee_out_percent)
    }

    fun balances<M, S, Meme>(state: &PoolState<M, S, Meme>): (u64, u64) {
        ( 
            balance::value(&state.balance_m), 
            balance::value(&state.balance_s)
        )
    }

    fun buy_meme_swap_amounts<M, S, Meme>(
        self: &PoolState<M, S, Meme>,
        delta_s: u64,
        min_delta_m: u64,
    ): SwapAmount {
        let (m_t0, s_t0) = balances(self);

        let p = &self.config;

        let max_delta_s = (gamma_s_mist(self)) - s_t0;
        
        let admin_fee_in = fees::get_fee_in_amount(&self.fees, delta_s);
        let is_max = delta_s - admin_fee_in >= max_delta_s;
        
        let net_delta_s = math::min(delta_s - admin_fee_in, max_delta_s);

        let delta_m = if (is_max) {
            m_t0
        } else {
            compute_delta_m(self, s_t0, s_t0 + net_delta_s)
        };

        let admin_fee_out = fees::get_fee_out_amount(&self.fees, delta_m);
        let net_delta_m = delta_m - admin_fee_out;

        assert!(net_delta_m >= min_delta_m, errors::slippage());
        
        SwapAmount {
            amount_in: net_delta_s,
            amount_out: net_delta_m,
            admin_fee_in,
            admin_fee_out,
        }
    }

    fun sell_meme_swap_amounts<M, S, Meme>(
        self: &PoolState<M, S, Meme>,
        delta_m: u64,
        min_delta_s: u64,
    ): SwapAmount {
        let (m_b, s_b) = balances(self);

        let p = &self.config;

        let max_delta_m = (p.gamma_m as u64) - m_b; // TODO: confirm
        
        let admin_fee_in = fees::get_fee_in_amount(&self.fees, delta_m);
        let is_max = delta_m - admin_fee_in > max_delta_m; // TODO: shouldn't it be >=?
        
        let net_delta_m = math::min(delta_m - admin_fee_in, max_delta_m);

        let delta_s = if (is_max) {
            s_b // TODO: confirm
        } else {
            compute_delta_s(self, s_b, net_delta_m)
        };

        let admin_fee_out = fees::get_fee_out_amount(&self.fees, delta_s);
        let net_delta_s = delta_s - admin_fee_out;

        assert!(net_delta_s >= min_delta_s, errors::slippage());
        
        SwapAmount {
            amount_in: net_delta_m,
            amount_out: net_delta_s,
            admin_fee_in,
            admin_fee_out,
        }
    }

    fun swap_amounts<M, S, Meme>(
        self: &PoolState<M, S, Meme>,
        coin_in_amount: u64,
        coin_out_min_value: u64,
        buy_meme: bool,
    ): SwapAmount {
        if (buy_meme) {
            buy_meme_swap_amounts(self, coin_in_amount, coin_out_min_value)
        } else {
            sell_meme_swap_amounts(self, coin_in_amount, coin_out_min_value)
        }
    }

    fun pool_state<M, S, Meme>(pool: &SeedPool): &PoolState<M, S, Meme> {
        df::borrow(fields(pool), PoolStateKey {})
    }

    fun pool_state_mut<M, S, Meme>(pool: &mut SeedPool): &mut PoolState<M, S, Meme> {
        df::borrow_mut(fields_mut(pool), PoolStateKey {})
    }

    fun subtract_from_token_acc(
        pool: &mut SeedPool,
        amount: u64,
        beneficiary: address,
    ) {
        let accounting: &mut Table<address, u64> = df::borrow_mut(fields_mut(pool), AccountingDfKey {});

        let position = table::borrow_mut(accounting, beneficiary);
        *position = *position - amount;
    }
    
    fun add_from_token_acc(
        pool: &mut SeedPool,
        amount: u64,
        beneficiary: address,
    ) {
        let accounting: &mut Table<address, u64> = df::borrow_mut(fields_mut(pool), AccountingDfKey {});

        if (!table::contains(accounting, beneficiary)) {
            table::add(accounting, beneficiary, 0);
        };

        let position = table::borrow_mut(accounting, beneficiary);
        *position = *position + amount;
    }

    public fun fields(pool: &SeedPool): &UID { &pool.fields }
    fun fields_mut(pool: &mut SeedPool): &mut UID { &mut pool.fields }

    // Not safe to expose!
    public(friend) fun destroy_pool<M, S, Meme>(pool: SeedPool): (
        Balance<M>,
        Balance<S>,
        Balance<M>,
        Balance<S>,
        Balance<Meme>,
        Fees,
        Config,
        bool,
        UID, // Fields
    ) {
        let state = df::remove(fields_mut(&mut pool), PoolStateKey {});
        

        let SeedPool { id, fields } = pool;
        object::delete(id);

        let PoolState {
            balance_m,
            balance_s,
            admin_balance_m,
            admin_balance_s,
            launch_balance,
            fees,
            config,
            locked,
        } = state;

        (
            balance_m,
            balance_s,
            admin_balance_m,
            admin_balance_s,
            launch_balance,
            fees,
            config,
            locked,
            fields,
        )
    }

    // === Test Functions ===

    #[test_only]
    public fun unlock_for_testing<M, S, Meme>(pool: &mut SeedPool) {
        let pool_state = pool_state_mut<M, S, Meme>(pool);
        pool_state.locked = false;
    }
    
    #[test_only]
    public fun seed_liquidity<M, S, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<M, S, Meme>(pool);
        balance::value(&pool_state.launch_balance)
    }

    #[test_only]
    public fun set_liquidity<M, S, Meme>(pool: &mut SeedPool, coin_m: Token<M>, coin_s: Coin<S>) {
        let pool_state = pool_state_mut<M, S, Meme>(pool);
        let balance_m = balance::withdraw_all(&mut pool_state.balance_m);
        let balance_s = balance::withdraw_all(&mut pool_state.balance_s);

        balance::destroy_for_testing(balance_m);
        balance::destroy_for_testing(balance_s);

        let coin_m_amount = token::value(&coin_m);
        token::burn_for_testing(coin_m);
        
        balance::join(&mut pool_state.balance_m, balance::create_for_testing(coin_m_amount));
        balance::join(&mut pool_state.balance_s, coin::into_balance(coin_s));
    }

    #[test]
    public fun test_alpha_abs() {
        let alpha_abs = compute_alpha_abs(
            default_gamma_s(),
            default_gamma_m(),
            default_omega_m(),
            default_price_factor(),
        );
        assert!(alpha_abs == 1_111_111_111_111, 0);

        let alpha_abs = compute_alpha_abs(
            63_000,
            1_400_000_000_000_000,
            280_000_000_000_000,
            2,
        );
        assert!(alpha_abs == 423_280_423_280, 0);
        
        let alpha_abs = compute_alpha_abs(
            47_000,
            1_800_000_000_000_000,
            620_000_000_000_000,
            2,
        );
        assert!(alpha_abs == 507_016_749_660, 0);
        
        let alpha_abs = compute_alpha_abs(
            1000,
            6_900_000_000_000_000,
            1_830_000_000_000_000,
            2,
        );
        assert!(alpha_abs == 6_480_000_000_000_000 , 0);
        
        let alpha_abs = compute_alpha_abs(
            3_4000,
            5_600_000_000_000_000,
            1_800_000_000_000_000,
            2,
        );
        assert!(alpha_abs == 3_460_207_612_456, 0);
        
        let alpha_abs = compute_alpha_abs(
            9_1000,
            3_300_000_000_000_000,
            660_000_000_000_000,
            2,
        );
        assert!(alpha_abs == 478_203_115_565, 0);
    }

    #[test]
    public fun test_beta() {
        let beta = compute_beta(
            default_gamma_s(),
            default_gamma_m(),
            default_omega_m(),
            default_price_factor(),
        );
        assert!(beta == 46_666_666_666_666_666, 0);

        let beta = compute_beta(
            63_000,
            1_400_000_000_000_000,
            280_000_000_000_000,
            2,
        );
        assert!(beta ==  35_555_555_555_555_555, 0);
        
        let beta = compute_beta(
            47_000,
            1_800_000_000_000_000,
            620_000_000_000_000,
            2,
        );
        assert!(beta == 50_212_765_957_446_808, 0);
        
        let beta = compute_beta(
            1000,
            6_900_000_000_000_000,
            1_830_000_000_000_000,
            2,
        );
        assert!(beta == 10_140_000_000_000_000_000, 0);
        
        let beta = compute_beta(
            3_4000,
            5_600_000_000_000_000,
            1_800_000_000_000_000,
            2,
        );
        assert!(beta == 223_529_411_764_705_882, 0);
        
        let beta = compute_beta(
            9_1000,
            3_300_000_000_000_000,
            660_000_000_000_000,
            2,
        );
        assert!(beta == 58_021_978_021_978_021, 0);
    }
}