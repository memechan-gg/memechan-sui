module amm::interest_protocol_amm {
  // === Imports ===

  use std::ascii;
  use std::string;
  use std::option::{Self, Option};
  use std::type_name::{Self, TypeName};

  use sui::math::pow;
  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::table::{Self, Table};
  use sui::tx_context::TxContext;
  use sui::transfer::share_object;
  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin, CoinMetadata, TreasuryCap};
  use sui::clock::Clock;
 
  use amm::utils;
  use amm::errors;
  use amm::events;
  use amm::bound; 
  use amm::admin::Admin;
  use amm::fees::{Self, Fees};
  use amm::curves::Bound;
  use amm::staked_lp::StakedLP;

  // === Constants ===

  const ADMIN_FEE: u256 = 5_000_000_000_000_000; // 0.5%

  const BASE_TOKEN_CURVED: u64 = 900_000_000_000_000;
  const BASE_TOKEN_LAUNCHED: u64 = 200_000_000_000_000;

  // === Structs ===

  struct Registry has key {
    id: UID,
    pools: Table<TypeName, address>
  }
  
  struct InterestPool has key {
    id: UID 
  }

  struct RegistryKey<phantom Curve, phantom CoinX, phantom CoinY> has drop {}

  struct PoolStateKey has drop, copy, store {}

  struct PoolState<phantom CoinX, phantom CoinY, phantom LpCoin> has store {
    lp_coin_cap: TreasuryCap<LpCoin>,
    balance_x: Balance<CoinX>,
    balance_y: Balance<CoinY>,
    decimals_x: u64,
    decimals_y: u64,
    admin_balance_x: Balance<CoinX>,
    admin_balance_y: Balance<CoinY>,
    seed_liquidity: Balance<LpCoin>,
    launch_balance: Balance<CoinX>,
    fees: Fees,
    locked: bool     
  } 

  struct SwapAmount has store, drop, copy {
    amount_out: u64,
    admin_fee_in: u64,
    admin_fee_out: u64,
  }

  // === Public-Mutative Functions ===

  #[allow(unused_function)]
  fun init(ctx: &mut TxContext) {
    share_object(
      Registry {
        id: object::new(ctx),
        pools: table::new(ctx)
      }
    );
  }  

  // === DEX ===

  #[lint_allow(share_owned)]
  public fun new<CoinX, CoinY, LpCoin>(
    registry: &mut Registry,
    coin_x_treasury: TreasuryCap<CoinX>,
    lp_coin_cap: TreasuryCap<LpCoin>,
    coin_x_metadata: &CoinMetadata<CoinX>,
    coin_y_metadata: &CoinMetadata<CoinY>,  
    lp_coin_metadata: &mut CoinMetadata<LpCoin>,
    ctx: &mut TxContext    
  ) {
    utils::assert_coin_integrity<CoinX, CoinY>(&coin_x_treasury, coin_x_metadata);
    utils::assert_lp_coin_integrity<CoinX, CoinY, LpCoin>(lp_coin_metadata);
    
    let coin_x = coin::mint<CoinX>(&mut coin_x_treasury, BASE_TOKEN_CURVED, ctx);
    let launch_coin = coin::mint<CoinX>(&mut coin_x_treasury, BASE_TOKEN_LAUNCHED, ctx);

    coin::update_name(&lp_coin_cap, lp_coin_metadata, utils::get_lp_coin_name(coin_x_metadata, coin_y_metadata));
    coin::update_symbol(&lp_coin_cap, lp_coin_metadata, utils::get_lp_coin_symbol(coin_x_metadata, coin_y_metadata));

    let decimals_x = pow(10, coin::get_decimals(coin_x_metadata));
    let decimals_y = pow(10, coin::get_decimals(coin_y_metadata));

    sui::transfer::public_transfer(coin_x_treasury, @0x2);

    new_pool_internal<Bound, CoinX, CoinY, LpCoin>(registry, coin_x, coin::zero(ctx), lp_coin_cap, decimals_x, decimals_y, launch_coin, ctx);
  }

  // === Public-View Functions ===

  public fun pools(registry: &Registry): &Table<TypeName, address> {
    &registry.pools
  }

  public fun pool_address<Curve, CoinX, CoinY>(registry: &Registry): Option<address> {
    let registry_key = type_name::get<RegistryKey<Curve, CoinX, CoinY>>();

    if (table::contains(&registry.pools, registry_key))
      option::some(*table::borrow(&registry.pools, registry_key))
    else
      option::none()
  }

  public fun exists_<Curve, CoinX, CoinY>(registry: &Registry): bool {
    table::contains(&registry.pools, type_name::get<RegistryKey<Curve, CoinX, CoinY>>())   
  }

  public fun lp_coin_supply<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::supply_value(coin::supply_immut(&pool_state.lp_coin_cap))  
  }

  public fun balance_x<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.balance_x)
  }

  public fun balance_y<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.balance_y)
  }

  public fun decimals_x<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.decimals_x
  }

  public fun decimals_y<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.decimals_y
  }

  public fun fees<CoinX, CoinY, LpCoin>(pool: &InterestPool): Fees {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.fees
  }

  public fun locked<CoinX, CoinY, LpCoin>(pool: &InterestPool): bool {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    pool_state.locked
  }

  public fun admin_balance_x<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.admin_balance_x)
  }

  public fun admin_balance_y<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.admin_balance_y)
  }

  // === Admin Functions ===

  public fun take_fees<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &mut InterestPool,
    ctx: &mut TxContext
  ): (Coin<CoinX>, Coin<CoinY>) {
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);

    let amount_x = balance::value(&pool_state.admin_balance_x);
    let amount_y = balance::value(&pool_state.admin_balance_y);

    (
      coin::take(&mut pool_state.admin_balance_x, amount_x, ctx),
      coin::take(&mut pool_state.admin_balance_y, amount_y, ctx)
    )
  }

  public fun update_name<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    name: string::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_name(&pool_state.lp_coin_cap, metadata, name);  
  }

  public fun update_symbol<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    symbol: ascii::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_symbol(&pool_state.lp_coin_cap, metadata, symbol);
  }

  public fun update_description<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    description: string::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_description(&pool_state.lp_coin_cap, metadata, description);
  }

  public fun update_icon_url<CoinX, CoinY, LpCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<LpCoin>, 
    url: ascii::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    coin::update_icon_url(&pool_state.lp_coin_cap, metadata, url);
  }

  // === Private Functions ===    

  fun new_pool_internal<Curve, CoinX, CoinY, LpCoin>(
    registry: &mut Registry,
    coin_x: Coin<CoinX>,
    coin_y: Coin<CoinY>,
    lp_coin_cap: TreasuryCap<LpCoin>,
    decimals_x: u64,
    decimals_y: u64,
    launch_coin: Coin<CoinX>,
    ctx: &mut TxContext
  ) {
    assert!(
      balance::supply_value(coin::supply_immut(&lp_coin_cap)) == 0, 
      errors::supply_must_have_zero_value()
    );

    let coin_x_value = coin::value(&coin_x);
    let coin_y_value = coin::value(&coin_y);

    assert!(coin_x_value == BASE_TOKEN_CURVED, errors::provide_both_coins());

    let registry_key = type_name::get<RegistryKey<Curve, CoinX, CoinY>>();

    assert!(!table::contains(&registry.pools, registry_key), errors::pool_already_deployed());

    let seed_liquidity = balance::increase_supply(
      coin::supply_mut(&mut lp_coin_cap),
      coin::value(&coin_x)
    );

    let pool_state = PoolState {
      lp_coin_cap,
      balance_x: coin::into_balance(coin_x),
      balance_y: coin::into_balance(coin_y),
      decimals_x,
      decimals_y,
      seed_liquidity,
      fees: new_fees(),
      locked: false,
      launch_balance: coin::into_balance(launch_coin),
      admin_balance_x: balance::zero(),
      admin_balance_y: balance::zero()
    };

    let pool = InterestPool {
      id: object::new(ctx)
    };

    let pool_address = object::uid_to_address(&pool.id);

    df::add(&mut pool.id, PoolStateKey {}, pool_state);

    table::add(&mut registry.pools, registry_key, pool_address);

    events::new_pool<Curve, CoinX, CoinY>(pool_address, coin_x_value, coin_y_value);

    share_object(pool);
  }

  public fun swap_coin_x<CoinX, CoinY, LpCoin>(
    pool: &mut InterestPool,
    coin_x: Coin<CoinX>,
    coin_y_min_value: u64,
    ctx: &mut TxContext
  ): Coin<CoinY> {
    assert!(coin::value(&coin_x) != 0, errors::no_zero_coin());

    let pool_address = object::uid_to_address(&pool.id);
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);
    assert!(!pool_state.locked, errors::pool_is_locked());

    let coin_in_amount = coin::value(&coin_x);
    
    let swap_amount = swap_amounts(
      pool_state, 
      coin_in_amount, 
      coin_y_min_value, 
      true
    );

    if (swap_amount.admin_fee_in != 0) {
      balance::join(&mut pool_state.admin_balance_x, coin::into_balance(coin::split(&mut coin_x, swap_amount.admin_fee_in, ctx)));
    };

    if (swap_amount.admin_fee_out != 0) {
      balance::join(&mut pool_state.admin_balance_y, balance::split(&mut pool_state.balance_y, swap_amount.admin_fee_out));  
    };

    balance::join(&mut pool_state.balance_x, coin::into_balance(coin_x));

    events::swap<CoinX, CoinY, SwapAmount>(pool_address, coin_in_amount, swap_amount);

    coin::take(&mut pool_state.balance_y, swap_amount.amount_out, ctx)
    
  }

  public fun swap_coin_y<CoinX, CoinY, LpCoin>(
    pool: &mut InterestPool,
    coin_y: Coin<CoinY>,
    coin_x_min_value: u64,
    clock: &Clock,
    ctx: &mut TxContext
  ): StakedLP<CoinX> {
    assert!(coin::value(&coin_y) != 0, errors::no_zero_coin());

    let pool_address = object::uid_to_address(&pool.id);
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);
    assert!(!pool_state.locked, errors::pool_is_locked());

    let coin_in_amount = coin::value(&coin_y);

    let swap_amount = swap_amounts(
      pool_state, 
      coin_in_amount, 
      coin_x_min_value, 
      false,
    );

    if (swap_amount.admin_fee_in != 0) {
      balance::join(&mut pool_state.admin_balance_y, coin::into_balance(coin::split(&mut coin_y, swap_amount.admin_fee_in, ctx)));
    };

    if (swap_amount.admin_fee_out != 0) {
      balance::join(&mut pool_state.admin_balance_x, balance::split(&mut pool_state.balance_x, swap_amount.admin_fee_out)); 
    };

    balance::join(&mut pool_state.balance_y, coin::into_balance(coin_y));

    events::swap<CoinY, CoinX, SwapAmount>(pool_address, coin_in_amount,swap_amount);

    if (balance::value(&pool_state.balance_x) <= BASE_TOKEN_CURVED / 100) {
      pool_state.locked = true;
    };

    //coin::take(&mut pool_state.balance_x, swap_amount.amount_out, ctx) 
    amm::staked_lp::new(balance::split(&mut pool_state.balance_x, swap_amount.amount_out), clock, ctx)
  }  

  fun new_fees(): Fees {
      fees::new(ADMIN_FEE, ADMIN_FEE)
  }

  fun amounts<CoinX, CoinY, LpCoin>(state: &PoolState<CoinX, CoinY, LpCoin>): (u64, u64, u64) {
    ( 
      balance::value(&state.balance_x), 
      balance::value(&state.balance_y),
      balance::supply_value(coin::supply_immut(&state.lp_coin_cap))
    )
  }

  fun swap_amounts<CoinX, CoinY, LpCoin>(
    pool_state: &PoolState<CoinX, CoinY, LpCoin>,
    coin_in_amount: u64,
    coin_out_min_value: u64,
    is_x: bool
  ): SwapAmount {
    let (balance_x, balance_y, _) = amounts(pool_state);

    let prev_k = bound::invariant_(balance_x, balance_y);

    let admin_fee_in = fees::get_fee_in_amount(&pool_state.fees, coin_in_amount);

    let coin_in_amount = coin_in_amount - admin_fee_in;

    let amount_out = bound::get_amount_out(coin_in_amount, balance_x, balance_y, is_x);

    let admin_fee_out = fees::get_fee_out_amount(&pool_state.fees, amount_out);

    let amount_out = amount_out - admin_fee_out;

    assert!(amount_out >= coin_out_min_value, errors::slippage());

    let new_k = {
      if (is_x)
        bound::invariant_(balance_x + coin_in_amount + admin_fee_in, balance_y - amount_out)
      else
        bound::invariant_(balance_x - amount_out, balance_y + coin_in_amount + admin_fee_in)
    };

    assert!(new_k >= prev_k, errors::invalid_invariant());

    SwapAmount {
      amount_out,
      admin_fee_in,
      admin_fee_out,
    }  
  }

  fun pool_state<CoinX, CoinY, LpCoin>(pool: &InterestPool): &PoolState<CoinX, CoinY, LpCoin> {
    df::borrow(&pool.id, PoolStateKey {})
  }

  fun pool_state_mut<CoinX, CoinY, LpCoin>(pool: &mut InterestPool): &mut PoolState<CoinX, CoinY, LpCoin> {
    df::borrow_mut(&mut pool.id, PoolStateKey {})
  }

  // === Test Functions ===
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }

  #[test_only]
  public fun seed_liquidity<CoinX, CoinY, LpCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, LpCoin>(pool);
    balance::value(&pool_state.seed_liquidity)
  }

  #[test_only]
  public fun set_liquidity<CoinX, CoinY, LpCoin>(pool: &mut InterestPool, coin_x: Coin<CoinX>, coin_y: Coin<CoinY>) {
    let pool_state = pool_state_mut<CoinX, CoinY, LpCoin>(pool);
    let balance_x = balance::withdraw_all(&mut pool_state.balance_x);
    let balance_y = balance::withdraw_all(&mut pool_state.balance_y);

    balance::destroy_for_testing(balance_x);
    balance::destroy_for_testing(balance_y);
    
    balance::join(&mut pool_state.balance_x, coin::into_balance(coin_x));
    balance::join(&mut pool_state.balance_y, coin::into_balance(coin_y));
  }
}