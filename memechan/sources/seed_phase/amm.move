module memechan::bound_curve_amm {
    use std::type_name;

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

    use memechan::index::{Self, Registry, policies_mut};
    use memechan::utils;
    use memechan::errors;
    use memechan::staked_lp;
    use memechan::events;
    use memechan::bound; 
    use memechan::admin::Admin;
    use memechan::fees::{Self, Fees};
    use memechan::curves::Bound;
    use memechan::staked_lp::StakedLP;
    use memechan::token_ir;

    friend memechan::initialize;

    // === Constants ===

    const DEFAULT_ADMIN_FEE: u256 = 5_000_000_000_000_000; // 0.5%

    const DEFAUL_MEME_SUPPLY_FOR_STAKING_POOL: u64 = 900_000_000_000_000;
    const DEFAULT_MEME_SUPPLY_FOR_LP_LIQUIDITY: u64 = 200_000_000_000_000;

    const MAX_X: u256 = 900_000_000;
    const MAX_Y: u256 =      30_000;

    const DECIMALS_X: u256 = 1_000_000;
    const DECIMALS_Y: u256 = 1_000_000_000;

    public fun default_admin(): u256 { DEFAULT_ADMIN_FEE }
    public fun default_meme_supply_staking_pool(): u64 { DEFAUL_MEME_SUPPLY_FOR_STAKING_POOL }
    public fun default_meme_supply_lp_liquidity(): u64 { DEFAULT_MEME_SUPPLY_FOR_LP_LIQUIDITY }
    public fun max_x(): u256 { MAX_X }
    public fun max_y(): u256 { MAX_Y }
    public fun decimals_x(): u256 { DECIMALS_X }
    public fun decimals_y(): u256 { DECIMALS_Y }

    // === Structs ===
    
    struct SeedPool has key {
        id: UID,
        fields: UID,
    }

    struct PoolStateKey has drop, copy, store {}
    struct AccountingDfKey has drop, copy, store {}

    struct PoolState<phantom X, phantom Y, phantom Meme> has store {
        /// X --> sMeme token, representing ownership of Meme coin
        balance_x: Balance<X>,
        /// Y --> quote coin, usually SUI
        balance_y: Balance<Y>,
        admin_balance_x: Balance<X>,
        admin_balance_y: Balance<Y>,
        launch_balance: Balance<Meme>,
        fees: Fees,
        config: Config,
        locked: bool,
    }

    struct Config has store, drop {
        meme_supply_for_staking_pool: u64,
        meme_supply_for_lp_liquidity: u64,
    }

    struct SwapAmount has store, drop, copy {
        amount_in: u64,
        amount_out: u64,
        admin_fee_in: u64,
        admin_fee_out: u64,
    }

    // === DEX ===

    #[lint_allow(share_owned)]
    public fun new_default<X, Y, Meme>(
        registry: &mut Registry,
        ticket_coin_cap: TreasuryCap<X>,
        meme_coin_cap: TreasuryCap<Meme>,
        ticket_coin_metadata: &mut CoinMetadata<X>,
        meme_coin_metadata: &CoinMetadata<Meme>,
        ctx: &mut TxContext
    ) {
        new<X, Y, Meme>(
            registry,
            ticket_coin_cap,
            meme_coin_cap,
            ticket_coin_metadata,
            meme_coin_metadata,
            DEFAULT_ADMIN_FEE,
            DEFAULT_ADMIN_FEE,
            DEFAUL_MEME_SUPPLY_FOR_STAKING_POOL,
            DEFAULT_MEME_SUPPLY_FOR_LP_LIQUIDITY,
            ctx,
        );
    }
    
    #[lint_allow(share_owned)]
    public fun new<X, Y, Meme>(
        registry: &mut Registry,
        ticket_coin_cap: TreasuryCap<X>,
        meme_coin_cap: TreasuryCap<Meme>,
        ticket_coin_metadata: &mut CoinMetadata<X>,
        meme_coin_metadata: &CoinMetadata<Meme>,
        fee_in_percent: u256,
        fee_out_percent: u256,
        meme_supply_for_staking_pool: u64,
        meme_supply_for_lp_liquidity: u64,
        ctx: &mut TxContext
    ) {
        utils::assert_ticket_coin_integrity<X, Y, Meme>(ticket_coin_metadata);
        utils::assert_coin_integrity<X, Y, Meme>(&ticket_coin_cap, ticket_coin_metadata, &meme_coin_cap, meme_coin_metadata);

        coin::update_name(&ticket_coin_cap, ticket_coin_metadata, utils::get_ticket_coin_name(meme_coin_metadata));
        coin::update_symbol(&ticket_coin_cap, ticket_coin_metadata, utils::get_ticket_coin_symbol(meme_coin_metadata));

        let launch_coin = coin::mint<Meme>(
            &mut meme_coin_cap,
            meme_supply_for_staking_pool + meme_supply_for_lp_liquidity,
            ctx);

        let balance_x: Balance<X> = balance::increase_supply(coin::supply_mut(&mut ticket_coin_cap), meme_supply_for_staking_pool);
        let coin_x_value = balance::value(&balance_x);

        let pool = new_pool_internal<Bound, X, Y, Meme>(
            registry,
            balance_x,
            coin::zero(ctx),
            launch_coin,
            fee_in_percent,
            fee_out_percent,
            meme_supply_for_staking_pool,
            meme_supply_for_lp_liquidity,
            ctx,
        );
        let pool_address = object::uid_to_address(&pool.id);

        let (policy, policy_address) = token_ir::init_token<X>(&mut pool.id, &ticket_coin_cap, ctx);
        table::add(policies_mut(registry), type_name::get<X>(), policy_address);

        events::new_pool<Bound, X, Y>(pool_address, coin_x_value, 0, policy_address);

        token::share_policy(policy);
        sui::transfer::public_transfer(ticket_coin_cap, @0x2);
        sui::transfer::public_transfer(meme_coin_cap, @0x2);
        share_object(pool);
    }

    // === Public-View Functions ===

    public fun ticket_coin_supply<X, Y, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<X, Y, Meme>(pool);
        balance::value(&pool_state.balance_x)
    }

    public fun meme_coin_supply<X, Y, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<X, Y, Meme>(pool);
        balance::value(&pool_state.launch_balance)
    }

    public fun balance_x<X, Y, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<X, Y, Meme>(pool);
        balance::value(&pool_state.balance_x)
    }

    public fun balance_y<X, Y, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<X, Y, Meme>(pool);
        balance::value(&pool_state.balance_y)
    }

    public fun fees<X, Y, Meme>(pool: &SeedPool): Fees {
        let pool_state = pool_state<X, Y, Meme>(pool);
        pool_state.fees
    }

    public fun is_ready_to_launch<X, Y, Meme>(pool: &SeedPool): bool {
        let pool_state = pool_state<X, Y, Meme>(pool);
        pool_state.locked
    }

    public fun admin_balance_x<X, Y, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<X, Y, Meme>(pool);
        balance::value(&pool_state.admin_balance_x)
    }

    public fun admin_balance_y<X, Y, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<X, Y, Meme>(pool);
        balance::value(&pool_state.admin_balance_y)
    }

    // === Admin Functions ===

    public fun take_fees<X, Y, Meme>(
        _: &Admin,
        pool: &mut SeedPool,
        policy: &TokenPolicy<X>,
        ctx: &mut TxContext
    ): (Token<X>, Coin<Y>) {
        let pool_state = pool_state_mut<X, Y, Meme>(pool);

        let amount_x = balance::value(&pool_state.admin_balance_x);
        let amount_y = balance::value(&pool_state.admin_balance_y);

        add_from_token_acc(pool, amount_x, sender(ctx));

        let pool_state = pool_state_mut<X, Y, Meme>(pool);

        (
            token_ir::take(policy, &mut pool_state.admin_balance_x, amount_x, ctx),
            coin::take(&mut pool_state.admin_balance_y, amount_y, ctx)
        )
    }

    // === Private Functions ===

    fun new_pool_internal<Curve, X, Y, Meme>(
        registry: &mut Registry,
        coin_x: Balance<X>,
        coin_y: Coin<Y>,
        launch_coin: Coin<Meme>,
        fee_in_percent: u256,
        fee_out_percent: u256,
        meme_supply_for_staking_pool: u64,
        meme_supply_for_lp_liquidity: u64,
        ctx: &mut TxContext
    ): SeedPool {
        let coin_x_value = balance::value(&coin_x);
        let coin_y_value = coin::value(&coin_y);
        let launch_coin_value = coin::value(&launch_coin);

        assert!(coin_x_value == meme_supply_for_staking_pool, errors::provide_both_coins());
        assert!(coin_y_value == 0, errors::provide_both_coins());
        assert!(launch_coin_value == meme_supply_for_staking_pool + meme_supply_for_lp_liquidity, errors::provide_both_coins());
        
        index::assert_new_pool<Curve, X, Y>(registry);

        let pool_state = PoolState {
            balance_x: coin_x,
            balance_y: coin::into_balance(coin_y),
            fees: new_fees(
                fee_in_percent,
                fee_out_percent,
            ),
            locked: false,
            launch_balance: coin::into_balance(launch_coin),
            admin_balance_x: balance::zero(),
            admin_balance_y: balance::zero(),
            config: Config {
                meme_supply_for_staking_pool,
                meme_supply_for_lp_liquidity,
            }
        };

        let pool = SeedPool {
            id: object::new(ctx),
            fields: object::new(ctx),
        };

        let pool_address = object::uid_to_address(&pool.id);

        df::add(fields_mut(&mut pool), PoolStateKey {}, pool_state);
        df::add(fields_mut(&mut pool), AccountingDfKey {}, table::new<address, u64>(ctx));
        
        index::add_seed_pool<Curve, X, Y>(registry, pool_address);
        //table::add(&mut registry.lp_coins, type_name::get<LpCoin>(), pool_address);

        pool
    }

    public fun swap_coin_x<X, Y, Meme>( // todo: rename swap_x_for_y
        pool: &mut SeedPool,
        coin_x: Token<X>,
        coin_y_min_value: u64,
        policy: &TokenPolicy<X>,
        ctx: &mut TxContext
    ): Coin<Y> {
        assert!(token::value(&coin_x) != 0, errors::no_zero_coin());

        let pool_address = object::uid_to_address(&pool.id);
        let pool_state = pool_state_mut<X, Y, Meme>(pool);
        assert!(!pool_state.locked, errors::pool_is_locked());

        let coin_in_amount = token::value(&coin_x);
        
        let swap_amount = swap_amounts(
            pool_state, 
            coin_in_amount, 
            coin_y_min_value, 
            true
        );

        if (swap_amount.admin_fee_in != 0) {
            balance::join(&mut pool_state.admin_balance_x, token_ir::into_balance(policy, token::split(&mut coin_x, swap_amount.admin_fee_in, ctx), ctx));
        };

        if (swap_amount.admin_fee_out != 0) {
            balance::join(&mut pool_state.admin_balance_y, balance::split(&mut pool_state.balance_y, swap_amount.admin_fee_out));
        };

        balance::join(&mut pool_state.balance_x, token_ir::into_balance(policy, coin_x, ctx));

        events::swap<X, Y, SwapAmount>(pool_address, coin_in_amount, swap_amount);

        let coin_y = coin::take(&mut pool_state.balance_y, swap_amount.amount_out, ctx);

        // We keep track of how much each address ownes of coin_x
        subtract_from_token_acc(pool, coin_in_amount, sender(ctx));
        coin_y
    }

    public fun swap_coin_y<X, Y, Meme>(
        pool: &mut SeedPool,
        coin_y: &mut Coin<Y>,
        coin_x_min_value: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): StakedLP<X> {
        assert!(coin::value(coin_y) != 0, errors::no_zero_coin());

        let pool_address = object::uid_to_address(&pool.id);
        let pool_state = pool_state_mut<X, Y, Meme>(pool);
        assert!(!pool_state.locked, errors::pool_is_locked());

        let coin_in_amount = coin::value(coin_y);

        let swap_amount = swap_amounts(
            pool_state, 
            coin_in_amount, 
            coin_x_min_value,
            false,
        );

        if (swap_amount.admin_fee_in != 0) {
            balance::join(&mut pool_state.admin_balance_y, coin::into_balance(coin::split(coin_y, swap_amount.admin_fee_in, ctx)));
        };

        if (swap_amount.admin_fee_out != 0) {
            balance::join(&mut pool_state.admin_balance_x, balance::split(&mut pool_state.balance_x, swap_amount.admin_fee_out)); 
        };

        balance::join(&mut pool_state.balance_y, coin::into_balance(coin::split(coin_y, swap_amount.amount_in, ctx)));

        events::swap<Y, X, SwapAmount>(pool_address, coin_in_amount,swap_amount);

        if (balance::value(&pool_state.balance_x) == 0) {
            pool_state.locked = true;
        };

        //coin::take(&mut pool_state.balance_x, swap_amount.amount_out, ctx)
        let swap_amount = swap_amount.amount_out;
        let staked_lp = staked_lp::new(balance::split(&mut pool_state.balance_x, swap_amount), clock, ctx);

        // We keep track of how much each address ownes of coin_x
        add_from_token_acc(pool, swap_amount, sender(ctx));
        staked_lp
    }

    fun new_fees(
        fee_in_percent: u256,
        fee_out_percent: u256,
    ): Fees {
        fees::new(fee_in_percent, fee_out_percent)
    }

    fun amounts<X, Y, Meme>(state: &PoolState<X, Y, Meme>): (u64, u64) {
        ( 
            balance::value(&state.balance_x), 
            balance::value(&state.balance_y)
        )
    }

    fun swap_amounts<X, Y, Meme>(
        pool_state: &PoolState<X, Y, Meme>,
        coin_in_amount: u64,
        coin_out_min_value: u64,
        sell_x: bool
    ): SwapAmount {
        let (x_t0, y_t0) = amounts(pool_state);

        let prev_k = bound::invariant_(x_t0, y_t0);

        let max_coins_in = {
            if (sell_x)
                (MAX_X * DECIMALS_X as u64) - x_t0
            else 
                (MAX_Y * DECIMALS_Y as u64) - y_t0
        };

        let max_admin_fee_in = {
            if (sell_x)
                fees::get_fee_in_amount(&pool_state.fees, (MAX_X * DECIMALS_X as u64)) - balance::value(&pool_state.admin_balance_x)
            else
                fees::get_fee_in_amount(&pool_state.fees, (MAX_Y * DECIMALS_Y as u64)) - balance::value(&pool_state.admin_balance_y)
        };
        
        let admin_fee_in = math::min(fees::get_fee_in_amount(&pool_state.fees, coin_in_amount), max_admin_fee_in);

        let is_max = coin_in_amount - admin_fee_in > max_coins_in;

        let coin_in_amount = math::min(coin_in_amount - admin_fee_in, max_coins_in);

        let delta_out = if (is_max) {
            if (sell_x) {
                (MAX_Y * DECIMALS_Y as u64) - y_t0 - bound::get_amount_out(coin_in_amount, x_t0, y_t0, sell_x)
            } else {
                x_t0
            }
        } else {
            bound::get_amount_out(coin_in_amount, x_t0, y_t0, sell_x)
        };

        let admin_fee_out = fees::get_fee_out_amount(&pool_state.fees, delta_out);
        let amount_out_net = delta_out - admin_fee_out;

        assert!(amount_out_net >= coin_out_min_value, errors::slippage());

        let new_k = {
            if (sell_x)
                bound::invariant_(x_t0 + coin_in_amount, y_t0 - amount_out_net)
            else
                bound::invariant_(x_t0 - amount_out_net, y_t0 + coin_in_amount)
        };

        assert!(new_k >= prev_k, errors::invalid_invariant());

        SwapAmount {
            amount_in: coin_in_amount,
            amount_out: amount_out_net,
            admin_fee_in,
            admin_fee_out,
        }
    }

    fun pool_state<X, Y, Meme>(pool: &SeedPool): &PoolState<X, Y, Meme> {
        df::borrow(fields(pool), PoolStateKey {})
    }

    fun pool_state_mut<X, Y, Meme>(pool: &mut SeedPool): &mut PoolState<X, Y, Meme> {
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
    public(friend) fun destroy_pool<X, Y, Meme>(pool: SeedPool): (
        Balance<X>,
        Balance<Y>,
        Balance<X>,
        Balance<Y>,
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
            balance_x,
            balance_y,
            admin_balance_x,
            admin_balance_y,
            launch_balance,
            fees,
            config,
            locked,
        } = state;

        (
            balance_x,
            balance_y,
            admin_balance_x,
            admin_balance_y,
            launch_balance,
            fees,
            config,
            locked,
            fields,
        )
    }

    // === Test Functions ===

    #[test_only]
    public fun seed_liquidity<X, Y, Meme>(pool: &SeedPool): u64 {
        let pool_state = pool_state<X, Y, Meme>(pool);
        balance::value(&pool_state.launch_balance)
    }

    #[test_only]
    public fun set_liquidity<X, Y, Meme>(pool: &mut SeedPool, coin_x: Token<X>, coin_y: Coin<Y>) {
        let pool_state = pool_state_mut<X, Y, Meme>(pool);
        let balance_x = balance::withdraw_all(&mut pool_state.balance_x);
        let balance_y = balance::withdraw_all(&mut pool_state.balance_y);

        balance::destroy_for_testing(balance_x);
        balance::destroy_for_testing(balance_y);

        let coin_x_amount = token::value(&coin_x);
        token::burn_for_testing(coin_x);
        
        balance::join(&mut pool_state.balance_x, balance::create_for_testing(coin_x_amount));
        balance::join(&mut pool_state.balance_y, coin::into_balance(coin_y));
    }
}