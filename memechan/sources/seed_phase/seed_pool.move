module memechan::seed_pool {
    use std::type_name;

    use sui::object::{Self, UID, id, id_to_address};
    use sui::table::{Self, Table};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::share_object;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::clock::Clock;
    use sui::math;
    use sui::token::{Self, Token, TokenPolicy, TokenPolicyCap};

    use suitears::math256::sqrt_down;

    use memechan::math256::pow_2;
    use memechan::index::{Self, Registry, policies_mut};
    use memechan::utils::mist;
    use memechan::staked_lp;
    use memechan::events;
    use memechan::admin::Admin;
    use memechan::fees::{Self, Fees};
    use memechan::staked_lp::{StakedLP, default_sell_delay_ms};
    use memechan::token_ir;
    use memechan::vesting::{
        VestingData, notional_mut, new_vesting_data
    };

    friend memechan::go_live;

    // ===== Constants =====

    const DEFAULT_ADMIN_FEE: u256 = 5_000_000_000_000_000; // 0.5%

    const DEFAULT_PRICE_FACTOR: u64 = 2;
    const DEFAULT_MAX_M_LP: u256 = 200_000_000_000_000;
    const DEFAULT_MAX_M: u256 = 900_000_000_000_000;
    const DEFAULT_MAX_S: u256 =      30_000;

    const DECIMALS_ALPHA: u256 = 1_000_000;
    const DECIMALS_BETA: u256 = 1_000_000;
    /// The amount of Mist per Sui token based on the fact that mist is
    /// 10^-9 of a Sui token
    const DECIMALS_S: u256 = 1_000_000_000;

    public fun default_admin_fee(): u256 { DEFAULT_ADMIN_FEE }
    public fun default_price_factor(): u64 { DEFAULT_PRICE_FACTOR }
    public fun default_gamma_m(): u256 { DEFAULT_MAX_M }
    public fun default_omega_m(): u256 { DEFAULT_MAX_M_LP }
    public fun default_gamma_s(): u256 { DEFAULT_MAX_S }
    public fun decimals_alpha(): u64 { (DECIMALS_ALPHA as u64) }
    public fun decimals_beta(): u64 { (DECIMALS_BETA as u64) }
    public fun decimals_s(): u64 { (DECIMALS_S as u64) }

    // ===== Errors =====

    const ENoZeroCoin: u64 = 0;
    const EBondingCurveMustBeNegativelySloped: u64 = 1;
    const EBondingCurveInterceptMustBePositive: u64 = 2;
    const EPoolIsLocked: u64 = 3;
    const EMemeSupplyNotGamma: u64 = 4;
    const EQuoteSupplyNotZero: u64 = 5;
    const EMemeTotalSupplyNotGammaOmega: u64 = 6;
    const EMemeCoinsShouldHaveZeroTotalSupply: u64 = 7;
    const ESlippage: u64 = 8;

    // ===== Structs =====
    
    struct SeedPool<phantom S, phantom Meme> has key {
        id: UID,
        /// X --> sMeme token, representing ownership of Meme coin
        balance_m: Balance<Meme>,
        /// Y --> quote coin, usually SUI
        balance_s: Balance<S>,
        admin_balance_m: Balance<Meme>,
        admin_balance_s: Balance<S>,
        launch_balance: Balance<Meme>,
        accounting: Table<address, VestingData>,
        meme_cap: TreasuryCap<Meme>,
        policy_cap: TokenPolicyCap<Meme>,
        fees: Fees,
        params: Params,
        locked: bool,
    }

    struct Params has store, drop {
        alpha_abs: u256, // |alpha|, because alpha is negative
        beta: u256,
        price_factor: u64,
        // In sui denomination
        gamma_s: u64,
        // In raw denomination
        gamma_m: u64, // DEFAULT_MAX_M * DECIMALS_M = 900_000_000_000_000
        // In raw denomination
        omega_m: u64, // DEFAULT_MAX_M_LP * DECIMALS_M = 200_000_000_000_000
        sell_delay_ms: u64,
    }

    struct SwapAmount has store, drop, copy {
        amount_in: u64,
        amount_out: u64,
        admin_fee_in: u64,
        admin_fee_out: u64,
    }

    // ===== Entry Functions =====

    #[lint_allow(share_owned)]
    public entry fun new_default<S, Meme>(
        registry: &mut Registry,
        meme_coin_cap: TreasuryCap<Meme>,
        ctx: &mut TxContext
    ) {
        let pool = new_<S, Meme>(
            registry,
            meme_coin_cap,
            DEFAULT_ADMIN_FEE,
            DEFAULT_ADMIN_FEE,
            DEFAULT_PRICE_FACTOR,
            (default_gamma_s() as u64),
            (default_gamma_m() as u64),
            (default_omega_m() as u64),
            default_sell_delay_ms(),
            ctx,
        );

        share_object(pool);
    }
    
    #[lint_allow(share_owned)]
    public entry fun new<S, Meme>(
        registry: &mut Registry,
        meme_coin_cap: TreasuryCap<Meme>,
        fee_in_percent: u256,
        fee_out_percent: u256,
        price_factor: u64,
        gamma_s: u64,
        gamma_m: u64,
        omega_m: u64,
        sell_delay_ms: u64,
        ctx: &mut TxContext
    ) {
        let pool = new_<S, Meme>(
            registry,
            meme_coin_cap,
            fee_in_percent,
            fee_out_percent,
            price_factor,
            gamma_s,
            gamma_m,
            omega_m,
            sell_delay_ms,
            ctx,
        );
        share_object(pool);
    }

    public entry fun transfer<S, Meme>(
        pool: &mut SeedPool<S, Meme>,
        policy: &TokenPolicy<Meme>,
        token: Token<Meme>,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let amount = token::value(&token);

        subtract_from_token_acc(pool, amount, sender(ctx));
        add_from_token_acc(pool, amount, recipient);
        token_ir::transfer(
            policy,
            token,
            recipient,
            ctx,
        );
    }

    // ===== Swap Functions =====

    public fun buy_meme<S, Meme>(
        pool: &mut SeedPool<S, Meme>,
        coin_s: &mut Coin<S>,
        coin_m_min_value: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): StakedLP<Meme> {
        assert!(coin::value(coin_s) != 0, ENoZeroCoin);

        let pool_address = object::uid_to_address(&pool.id);
        assert!(!pool.locked, EPoolIsLocked);

        let coin_in_amount = coin::value(coin_s);

        let swap_amount = swap_amounts(
            pool,
            coin_in_amount,
            coin_m_min_value,
            true,
        );

        if (swap_amount.admin_fee_in != 0) {
            balance::join(&mut pool.admin_balance_s, coin::into_balance(coin::split(coin_s, swap_amount.admin_fee_in, ctx)));
        };

        if (swap_amount.admin_fee_out != 0) {
            balance::join(&mut pool.admin_balance_m, balance::split(&mut pool.balance_m, swap_amount.admin_fee_out)); 
        };

        balance::join(&mut pool.balance_s, coin::into_balance(coin::split(coin_s, swap_amount.amount_in, ctx)));

        events::swap<S, Meme, SwapAmount>(pool_address, coin_in_amount,swap_amount);

        let staked_lp = staked_lp::new(
            balance::split(&mut pool.balance_m, swap_amount.amount_out),
            pool.params.sell_delay_ms,
            clock,
            ctx
        );

        if (balance::value(&pool.balance_m) == 0) {
            pool.locked = true;
        };

        // We keep track of how much each address ownes of coin_m
        add_from_token_acc(pool, swap_amount.amount_out, sender(ctx));
        staked_lp
    }

    public fun sell_meme<S, Meme>(
        pool: &mut SeedPool<S, Meme>,
        coin_m: Token<Meme>,
        coin_s_min_value: u64,
        policy: &TokenPolicy<Meme>,
        ctx: &mut TxContext
    ): Coin<S> {
        assert!(token::value(&coin_m) != 0, ENoZeroCoin);

        let pool_address = object::uid_to_address(&pool.id);
        assert!(!pool.locked, EPoolIsLocked);

        let coin_in_amount = token::value(&coin_m);
        
        let swap_amount = swap_amounts(
            pool, 
            coin_in_amount, 
            coin_s_min_value, 
            false,
        );

        if (swap_amount.admin_fee_in != 0) {
            balance::join(&mut pool.admin_balance_m, token_ir::into_balance(policy, token::split(&mut coin_m, swap_amount.admin_fee_in, ctx), ctx));
        };

        if (swap_amount.admin_fee_out != 0) {
            balance::join(&mut pool.admin_balance_s, balance::split(&mut pool.balance_s, swap_amount.admin_fee_out));
        };

        balance::join(&mut pool.balance_m, token_ir::into_balance(policy, coin_m, ctx));

        events::swap<S, Meme, SwapAmount>(pool_address, coin_in_amount, swap_amount);

        let coin_s = coin::take(&mut pool.balance_s, swap_amount.amount_out, ctx);

        // We keep track of how much each address ownes of coin_m
        subtract_from_token_acc(pool, coin_in_amount, sender(ctx));
        coin_s
    }

    public fun quote_buy_meme<S, Meme>(
        pool: &mut SeedPool<S, Meme>,
        coin_s: u64,
    ): u64 {
        assert!(coin_s != 0, ENoZeroCoin);
        assert!(!pool.locked, EPoolIsLocked);

        let swap_amount = swap_amounts(
            pool, 
            coin_s, 
            0,
            true,
        );

        swap_amount.amount_out
    }

    public fun quote_sell_meme<S, Meme>(
        pool: &mut SeedPool<S, Meme>,
        coin_m: u64,
    ): u64 {
        assert!(coin_m != 0, ENoZeroCoin);
        assert!(!pool.locked, EPoolIsLocked);
        
        let swap_amount = swap_amounts(
            pool, 
            coin_m, 
            0, 
            false,
        );

        swap_amount.amount_out
    }
    
    // ===== Logic Functions =====

    public fun compute_delta_m<S, Meme>(
        self: &SeedPool<S, Meme>,
        s_a: u64,
        s_b: u64,
    ): u64 {
        let s_a = (s_a as u256);
        let s_b = (s_b as u256);

        let alpha_abs = &self.params.alpha_abs;
        let beta = &self.params.beta;

        let left = *beta * DECIMALS_S * 2 * DECIMALS_ALPHA * (s_b - s_a);
        let right = *alpha_abs * DECIMALS_BETA * (pow_2(s_b) - pow_2(s_a));
        let denom =  2 * DECIMALS_ALPHA * DECIMALS_BETA * pow_2(DECIMALS_S);

        (((left - right) / denom) as u64)
    }
    
    public fun compute_delta_s<S, Meme>(
        self: &SeedPool<S, Meme>,
        s_b: u64,
        delta_m: u64,
    ): u64 {
        let s_b = (s_b as u256);
        let delta_m = (delta_m as u256);

        let alpha_abs = self.params.alpha_abs;
        let beta = self.params.beta;

        let a1 = 2 * beta * DECIMALS_ALPHA * DECIMALS_S - 2 * alpha_abs * s_b * DECIMALS_BETA;
        let b1 = DECIMALS_ALPHA * DECIMALS_BETA * DECIMALS_S;
        let c1 = 8 * delta_m * alpha_abs;

        let a = sqrt_down(
            pow_2(a1) * DECIMALS_ALPHA + c1 * pow_2(b1)
        );

        let b = sqrt_down(
            DECIMALS_ALPHA * pow_2(b1, )
        );

        let c = 2 * beta * DECIMALS_ALPHA * DECIMALS_S - 2 * alpha_abs * s_b * DECIMALS_BETA;
        let d = DECIMALS_ALPHA * DECIMALS_BETA * DECIMALS_S;

        let num = (a * d - c* b) * DECIMALS_S * DECIMALS_ALPHA;
        let denom = (2 * alpha_abs) * (b*d);

        ((num / denom) as u64)
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

    // ===== Getters =====

    public fun alpha_abs(params: &Params): u256 { params.alpha_abs }
    public fun beta(params: &Params): u256 { params.beta }
    public fun price_factor(params: &Params): u64 { params.price_factor }
    public fun gamma_s(params: &Params): u64 { params.gamma_s }
    public fun gamma_m(params: &Params): u64 { params.gamma_m }
    public fun omega_m(params: &Params): u64 { params.omega_m }
    public fun sell_delay_ms(params: &Params): u64 { params.sell_delay_ms }
    public fun gamma_s_mist<S, Meme>(self: &SeedPool<S, Meme>): u64 { mist(self.params.gamma_s) }

    public fun ticket_coin_supply<S, Meme>(pool: &SeedPool<S, Meme>): u64 {
        balance::value(&pool.balance_m)
    }

    public fun meme_coin_supply<S, Meme>(pool: &SeedPool<S, Meme>): u64 {
        balance::value(&pool.launch_balance)
    }

    public fun balance_m<S, Meme>(pool: &SeedPool<S, Meme>): u64 {
        balance::value(&pool.balance_m)
    }

    public fun balance_s<S, Meme>(pool: &SeedPool<S, Meme>): u64 {
        balance::value(&pool.balance_s)
    }

    public fun fees<S, Meme>(pool: &SeedPool<S, Meme>): Fees {
        pool.fees
    }

    public fun is_ready_to_launch<S, Meme>(pool: &SeedPool<S, Meme>): bool {
        pool.locked
    }

    public fun admin_balance_m<S, Meme>(pool: &SeedPool<S, Meme>): u64 {
        balance::value(&pool.admin_balance_m)
    }

    public fun admin_balance_s<S, Meme>(pool: &SeedPool<S, Meme>): u64 {
        balance::value(&pool.admin_balance_s)
    }

    // ===== Admin Functions =====

    public fun take_fees<S, Meme>(
        _: &Admin,
        pool: &mut SeedPool<S, Meme>,
        policy: &TokenPolicy<Meme>,
        ctx: &mut TxContext,
    ): (Token<Meme>, Coin<S>) {
        let amount_x = balance::value(&pool.admin_balance_m);
        let amount_y = balance::value(&pool.admin_balance_s);

        add_from_token_acc(pool, amount_x, sender(ctx));

        (
            token_ir::take(policy, &mut pool.admin_balance_m, amount_x, ctx),
            coin::take(&mut pool.admin_balance_s, amount_y, ctx)
        )
    }

    // === Private Functions ===

    #[lint_allow(share_owned)]
    fun new_<S, Meme>(
        registry: &mut Registry,
        meme_coin_cap: TreasuryCap<Meme>,
        fee_in_percent: u256,
        fee_out_percent: u256,
        price_factor: u64,
        gamma_s: u64,
        gamma_m: u64,
        omega_m: u64,
        sell_delay_ms: u64,
        ctx: &mut TxContext
    ): SeedPool<S, Meme> {
        assert!(balance::supply_value(coin::supply(&mut meme_coin_cap)) == 0, EMemeCoinsShouldHaveZeroTotalSupply);

        let launch_coin = coin::mint<Meme>(
            &mut meme_coin_cap,
            ((gamma_m + omega_m) as u64),
            ctx);

        let balance_m: Balance<Meme> = balance::increase_supply(coin::supply_mut(&mut meme_coin_cap), (gamma_m as u64));
        let coin_m_value = balance::value(&balance_m);

        let (policy, policy_cap) = token_ir::init_token<Meme>(&meme_coin_cap, ctx);

        let pool = new_pool_internal<S, Meme>(
            registry,
            balance_m,
            coin::zero(ctx),
            launch_coin,
            meme_coin_cap,
            policy_cap,
            fee_in_percent,
            fee_out_percent,
            price_factor,
            gamma_s,
            gamma_m,
            omega_m,
            sell_delay_ms,
            ctx,
        );

        let pool_address = object::uid_to_address(&pool.id);
        let policy_address = id_to_address(&id(&policy));

        index::add_seed_pool<S, Meme>(registry, pool_address);
        table::add(policies_mut(registry), type_name::get<Meme>(), policy_address);

        events::new_pool<S, Meme>(pool_address, coin_m_value, 0, policy_address);

        token::share_policy(policy);
        pool
    }

    fun new_pool_internal<S, Meme>(
        registry: &Registry,
        coin_m: Balance<Meme>,
        coin_s: Coin<S>,
        launch_coin: Coin<Meme>,
        meme_cap: TreasuryCap<Meme>,
        policy_cap: TokenPolicyCap<Meme>,
        fee_in_percent: u256,
        fee_out_percent: u256,
        price_factor: u64,
        gamma_s: u64,
        gamma_m: u64,
        omega_m: u64,
        sell_delay_ms: u64,
        ctx: &mut TxContext
    ): SeedPool<S, Meme> {
        let coin_m_value = balance::value(&coin_m);
        let coin_s_value = coin::value(&coin_s);
        let launch_coin_value = coin::value(&launch_coin);

        assert!(coin_m_value == (gamma_m as u64), EMemeSupplyNotGamma);
        assert!(coin_s_value == 0, EQuoteSupplyNotZero);
        assert!(launch_coin_value == ((gamma_m + omega_m) as u64), EMemeTotalSupplyNotGammaOmega);
        
        index::assert_new_pool<S, Meme>(registry);

        let pool = SeedPool<S, Meme> {
            id: object::new(ctx),
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
            params: Params {
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
                sell_delay_ms,
            },
            accounting: table::new<address, VestingData>(ctx),
            meme_cap,
            policy_cap,
        };

        pool
    }

    fun new_fees(
        fee_in_percent: u256,
        fee_out_percent: u256,
    ): Fees {
        fees::new(fee_in_percent, fee_out_percent)
    }

    fun balances<S, Meme>(pool: &SeedPool<S, Meme>): (u64, u64) {
        ( 
            balance::value(&pool.balance_m), 
            balance::value(&pool.balance_s)
        )
    }

    fun buy_meme_swap_amounts<S, Meme>(
        self: &SeedPool<S, Meme>,
        delta_s: u64,
        min_delta_m: u64,
    ): SwapAmount {
        let (m_t0, s_t0) = balances(self);

        let slack_s = (gamma_s_mist(self)) - s_t0;
        let max_delta_s = fees::get_gross_amount(&self.fees, slack_s);

        let admin_fee_in = fees::get_fee_in_amount(&self.fees, delta_s);
        let is_max = delta_s - admin_fee_in >= max_delta_s;
        
        let net_delta_s = if (is_max) {
            admin_fee_in = fees::get_fee_in_amount(&self.fees, max_delta_s);
            slack_s
        } else {
            delta_s - admin_fee_in
        };

        let delta_m = if (is_max) {
            m_t0
        } else {
            compute_delta_m(self, s_t0, s_t0 + net_delta_s)
        };

        let admin_fee_out = fees::get_fee_out_amount(&self.fees, delta_m);

        let net_delta_m = delta_m - admin_fee_out;

        assert!(net_delta_m >= min_delta_m, ESlippage);
        
        SwapAmount {
            amount_in: net_delta_s,
            amount_out: net_delta_m,
            admin_fee_in,
            admin_fee_out,
        }
    }

    fun sell_meme_swap_amounts<S, Meme>(
        self: &SeedPool<S, Meme>,
        delta_m: u64,
        min_delta_s: u64,
    ): SwapAmount {
        let (m_b, s_b) = balances(self);

        let p = &self.params;

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

        assert!(net_delta_s >= min_delta_s, ESlippage);
        
        SwapAmount {
            amount_in: net_delta_m,
            amount_out: net_delta_s,
            admin_fee_in,
            admin_fee_out,
        }
    }

    fun swap_amounts<S, Meme>(
        self: &SeedPool<S, Meme>,
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

    fun subtract_from_token_acc<S, Meme>(
        pool: &mut SeedPool<S, Meme>,
        amount: u64,
        beneficiary: address,
    ) {
        let position = table::borrow_mut(&mut pool.accounting, beneficiary);
        let notional = notional_mut(position);
        *notional = *notional - amount;
    }
    
    fun add_from_token_acc<S, Meme>(
        pool: &mut SeedPool<S, Meme>,
        amount: u64,
        beneficiary: address,
    ) {

        if (!table::contains(&pool.accounting, beneficiary)) {
            table::add(&mut pool.accounting, beneficiary, new_vesting_data(amount));
        };

        let position = table::borrow_mut(&mut pool.accounting, beneficiary);
        let notional = notional_mut(position);
        *notional = *notional + amount;
    }

    // ===== Friend Functions =====

    // Not safe to expose!
    public(friend) fun destroy_pool<S, Meme>(pool: SeedPool<S, Meme>): (
        Balance<Meme>,
        Balance<S>,
        Balance<Meme>,
        Balance<S>,
        Balance<Meme>,
        Table<address, VestingData>,
        TreasuryCap<Meme>,
        TokenPolicyCap<Meme>,
        Fees,
        Params,
        bool,
    ) {
        let SeedPool {
            id,
            balance_m,
            balance_s,
            admin_balance_m,
            admin_balance_s,
            launch_balance,
            accounting,
            meme_cap,
            policy_cap,
            fees,
            params,
            locked,
        } = pool;

        object::delete(id);

        (
            balance_m,
            balance_s,
            admin_balance_m,
            admin_balance_s,
            launch_balance,
            accounting,
            meme_cap,
            policy_cap,
            fees,
            params,
            locked,
        )
    }

    // ===== Test Functions =====

    #[test_only]
    use memechan::vesting;

    #[test_only]
    public fun new_full_for_testing<S, Meme>(
        registry: &mut Registry,
        meme_coin_cap: TreasuryCap<Meme>,
        ctx: &mut TxContext
    ): (SeedPool<S, Meme>, Token<Meme>) {
        let pool = new_<S, Meme>(
            registry,
            meme_coin_cap,
            DEFAULT_ADMIN_FEE,
            DEFAULT_ADMIN_FEE,
            DEFAULT_PRICE_FACTOR,
            (default_gamma_s() as u64),
            (default_gamma_m() as u64),
            (default_omega_m() as u64),
            default_sell_delay_ms(),
            ctx,
        );

        let notional = (pool.params.gamma_m as u64);
        table::add(&mut pool.accounting, sender(ctx), vesting::new_vesting_data(notional));

        let gamma_s = pool.params.gamma_s;
        
        balance::join(
            &mut pool.balance_s,
            balance::create_for_testing(gamma_s * (DECIMALS_S as u64))
        );

        balance::destroy_for_testing(
            balance::withdraw_all(
                &mut pool.balance_m
            )
        );

        pool.locked = true;

        (pool, token::mint_for_testing((default_gamma_m() as u64), ctx))
    }
    
    #[test_only]
    public fun unlock_for_testing<S, Meme>(pool: &mut SeedPool<S, Meme>) {
        pool.locked = false;
    }
    
    #[test_only]
    public fun seed_liquidity<S, Meme>(pool: &SeedPool<S, Meme>): u64 {
        balance::value(&pool.launch_balance)
    }

    #[test_only]
    public fun set_liquidity<S, Meme>(pool: &mut SeedPool<S, Meme>, coin_m: Token<Meme>, coin_s: Coin<S>) {
        let balance_m = balance::withdraw_all(&mut pool.balance_m);
        let balance_s = balance::withdraw_all(&mut pool.balance_s);

        balance::destroy_for_testing(balance_m);
        balance::destroy_for_testing(balance_s);

        let coin_m_amount = token::value(&coin_m);
        token::burn_for_testing(coin_m);
        
        balance::join(&mut pool.balance_m, balance::create_for_testing(coin_m_amount));
        balance::join(&mut pool.balance_s, coin::into_balance(coin_s));
    }

    // ===== Tests =====

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