module amm::interest_protocol_amm {
  // === Imports ===

  use std::option::{Self, Option};
  use std::type_name::{Self, TypeName};

  use sui::object::{Self, UID};
  use sui::dynamic_field as df;
  use sui::table::{Self, Table};
  use sui::tx_context::{TxContext, sender};
  use sui::transfer::share_object;
  use sui::balance::{Self, Balance};
  use sui::coin::{Self, Coin, CoinMetadata, TreasuryCap};
  use sui::clock::Clock;
  use sui::token::{Self, Token, TokenPolicy};
 
  use amm::utils;
  use amm::errors;
  use amm::events;
  use amm::bound; 
  use amm::admin::Admin;
  use amm::fees::{Self, Fees};
  use amm::curves::Bound;
  use amm::staked_lp::StakedLP;
  use amm::token_ir;

  // === Constants ===

  const ADMIN_FEE: u256 = 5_000_000_000_000_000; // 0.5%

  const BASE_TOKEN_CURVED: u64 = 900_000_000_000_000;
  const BASE_TOKEN_LAUNCHED: u64 = 200_000_000_000_000;

  // === Structs ===

  struct Registry has key {
    id: UID,
    pools: Table<TypeName, address>,
    policies: Table<TypeName, address>
  }
  
  struct InterestPool has key {
    id: UID 
  }

  struct RegistryKey<phantom Curve, phantom CoinX, phantom CoinY> has drop {}

  struct PoolStateKey has drop, copy, store {}
  struct AccountingDfKey has drop, copy, store {}

  struct PoolState<phantom CoinX, phantom CoinY, phantom MemeCoin> has store {
    balance_x: Balance<CoinX>,
    balance_y: Balance<CoinY>,
    admin_balance_x: Balance<CoinX>,
    admin_balance_y: Balance<CoinY>,
    launch_balance: Balance<MemeCoin>,
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
        pools: table::new(ctx),
        policies: table::new(ctx),
      }
    );
  }  

  // === DEX ===

  #[lint_allow(share_owned)]
  public fun new<CoinX, CoinY, MemeCoin>(
    registry: &mut Registry,
    ticket_coin_cap: TreasuryCap<CoinX>,
    meme_coin_cap: TreasuryCap<MemeCoin>,
    ticket_coin_metadata: &mut CoinMetadata<CoinX>,
    coin_y_metadata: &CoinMetadata<CoinY>,
    meme_coin_metadata: &CoinMetadata<MemeCoin>,
    ctx: &mut TxContext
  ) {
    utils::assert_ticket_coin_integrity<CoinX, CoinY, MemeCoin>(ticket_coin_metadata);
    utils::assert_coin_integrity<CoinX, CoinY, MemeCoin>(&ticket_coin_cap, ticket_coin_metadata, &meme_coin_cap, meme_coin_metadata);

    coin::update_name(&ticket_coin_cap, ticket_coin_metadata, utils::get_ticket_coin_name(meme_coin_metadata));
    coin::update_symbol(&ticket_coin_cap, ticket_coin_metadata, utils::get_ticket_coin_symbol(meme_coin_metadata));

    let launch_coin = coin::mint<MemeCoin>(&mut meme_coin_cap, BASE_TOKEN_CURVED + BASE_TOKEN_LAUNCHED, ctx);

    let balance_x: Balance<CoinX> = balance::increase_supply(coin::supply_mut(&mut ticket_coin_cap), BASE_TOKEN_CURVED);
    let coin_x_value = balance::value(&balance_x);

    let pool = new_pool_internal<Bound, CoinX, CoinY, MemeCoin>(registry, balance_x, coin::zero(ctx), launch_coin, ctx);
    let pool_address = object::uid_to_address(&pool.id);

    let (policy, policy_address) = token_ir::init_token<CoinX>(&mut pool.id, &ticket_coin_cap, ctx);
    table::add(&mut registry.policies, type_name::get<CoinX>(), policy_address);

    events::new_pool<Bound, CoinX, CoinY>(pool_address, coin_x_value, 0, policy_address);

    token::share_policy(policy);
    sui::transfer::public_transfer(ticket_coin_cap, @0x2);
    sui::transfer::public_transfer(meme_coin_cap, @0x2);
    share_object(pool);
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

  public fun get_policy_id<T>(registry: &Registry): address {
      let type_name = type_name::get<T>();
      *table::borrow(&registry.policies, type_name)
  }

  public fun exists_<Curve, CoinX, CoinY>(registry: &Registry): bool {
    table::contains(&registry.pools, type_name::get<RegistryKey<Curve, CoinX, CoinY>>())   
  }

  public fun ticket_coin_supply<CoinX, CoinY, MemeCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    balance::value(&pool_state.balance_x)
  }

  public fun meme_coin_supply<CoinX, CoinY, MemeCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    balance::value(&pool_state.launch_balance)
  }

  public fun balance_x<CoinX, CoinY, MemeCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    balance::value(&pool_state.balance_x)
  }

  public fun balance_y<CoinX, CoinY, MemeCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    balance::value(&pool_state.balance_y)
  }

  public fun decimals_x<CoinX, CoinY, MemeCoin>(pool: &InterestPool): u64 {
    let _ = pool_state<CoinX, CoinY, MemeCoin>(pool);
    1_000_000
  }

  public fun decimals_y<CoinX, CoinY, MemeCoin>(pool: &InterestPool): u64 {
    let _ = pool_state<CoinX, CoinY, MemeCoin>(pool);
    1_000_000_000
  }

  public fun fees<CoinX, CoinY, MemeCoin>(pool: &InterestPool): Fees {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    pool_state.fees
  }

  public fun locked<CoinX, CoinY, MemeCoin>(pool: &InterestPool): bool {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    pool_state.locked
  }

  public fun admin_balance_x<CoinX, CoinY, MemeCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    balance::value(&pool_state.admin_balance_x)
  }

  public fun admin_balance_y<CoinX, CoinY, MemeCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    balance::value(&pool_state.admin_balance_y)
  }

  // === Admin Functions ===

  public fun take_fees<CoinX, CoinY, MemeCoin>(
    _: &Admin,
    pool: &mut InterestPool,
    policy: &TokenPolicy<CoinX>,
    ctx: &mut TxContext
  ): (Token<CoinX>, Coin<CoinY>) {
    let pool_state = pool_state_mut<CoinX, CoinY, MemeCoin>(pool);

    let amount_x = balance::value(&pool_state.admin_balance_x);
    let amount_y = balance::value(&pool_state.admin_balance_y);

    (
      token_ir::take(policy, &mut pool_state.admin_balance_x, amount_x, ctx),
      coin::take(&mut pool_state.admin_balance_y, amount_y, ctx)
    )
  }
/*
  public fun update_name<CoinX, CoinY, MemeCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<MemeCoin>, 
    name: string::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    coin::update_name(&pool_state.lp_coin_cap, metadata, name);  
  }

  public fun update_symbol<CoinX, CoinY, MemeCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<MemeCoin>, 
    symbol: ascii::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    coin::update_symbol(&pool_state.lp_coin_cap, metadata, symbol);
  }

  public fun update_description<CoinX, CoinY, MemeCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<MemeCoin>, 
    description: string::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    coin::update_description(&pool_state.lp_coin_cap, metadata, description);
  }

  public fun update_icon_url<CoinX, CoinY, MemeCoin>(
    _: &Admin,
    pool: &InterestPool, 
    metadata: &mut CoinMetadata<MemeCoin>, 
    url: ascii::String
  ) {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    coin::update_icon_url(&pool_state.lp_coin_cap, metadata, url);
  }
*/
  // === Private Functions ===    

  fun new_pool_internal<Curve, CoinX, CoinY, MemeCoin>(
    registry: &Registry,
    coin_x: Balance<CoinX>,
    coin_y: Coin<CoinY>,
    launch_coin: Coin<MemeCoin>,
    ctx: &mut TxContext
  ): InterestPool {
    let coin_x_value = balance::value(&coin_x);
    let coin_y_value = coin::value(&coin_y);
    let launch_coin_value = coin::value(&launch_coin);

    assert!(coin_x_value == BASE_TOKEN_CURVED, errors::provide_both_coins());
    assert!(coin_y_value == 0, errors::provide_both_coins());
    assert!(launch_coin_value == BASE_TOKEN_CURVED + BASE_TOKEN_LAUNCHED, errors::provide_both_coins());
    
    let registry_key = type_name::get<RegistryKey<Curve, CoinX, CoinY>>();

    assert!(!table::contains(&registry.pools, registry_key), errors::pool_already_deployed());

    let pool_state = PoolState {
      balance_x: coin_x,
      balance_y: coin::into_balance(coin_y),
      fees: new_fees(),
      locked: false,
      launch_balance: coin::into_balance(launch_coin),
      admin_balance_x: balance::zero(),
      admin_balance_y: balance::zero()
    };

    let pool = InterestPool {
      id: object::new(ctx)
    };

    df::add(&mut pool.id, PoolStateKey {}, pool_state);

    pool
  }

  public fun swap_coin_x<CoinX, CoinY, MemeCoin>(
    pool: &mut InterestPool,
    coin_x: Token<CoinX>,
    coin_y_min_value: u64,
    policy: &TokenPolicy<CoinX>,
    ctx: &mut TxContext
  ): Coin<CoinY> {
    assert!(token::value(&coin_x) != 0, errors::no_zero_coin());

    let pool_address = object::uid_to_address(&pool.id);
    let pool_state = pool_state_mut<CoinX, CoinY, MemeCoin>(pool);
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

    events::swap<CoinX, CoinY, SwapAmount>(pool_address, coin_in_amount, swap_amount);

    let coin_y = coin::take(&mut pool_state.balance_y, swap_amount.amount_out, ctx);

    // We keep track of how much each address ownes of coin_x
    subtract_from_token_acc(pool, coin_in_amount, sender(ctx));
    coin_y
  }

  public fun swap_coin_y<CoinX, CoinY, MemeCoin>(
    pool: &mut InterestPool,
    coin_y: Coin<CoinY>,
    coin_x_min_value: u64,
    clock: &Clock,
    ctx: &mut TxContext
  ): StakedLP<CoinX> {
    assert!(coin::value(&coin_y) != 0, errors::no_zero_coin());

    let pool_address = object::uid_to_address(&pool.id);
    let pool_state = pool_state_mut<CoinX, CoinY, MemeCoin>(pool);
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
    let swap_amount = swap_amount.amount_out;
    let staked_lp = amm::staked_lp::new(balance::split(&mut pool_state.balance_x, swap_amount), clock, ctx);

    // We keep track of how much each address ownes of coin_x
    add_from_token_acc(pool, swap_amount, sender(ctx));
    staked_lp
  }  

  fun new_fees(): Fees {
      fees::new(ADMIN_FEE, ADMIN_FEE)
  }

  fun amounts<CoinX, CoinY, MemeCoin>(state: &PoolState<CoinX, CoinY, MemeCoin>): (u64, u64) {
    ( 
      balance::value(&state.balance_x), 
      balance::value(&state.balance_y)
    )
  }

  fun swap_amounts<CoinX, CoinY, MemeCoin>(
    pool_state: &PoolState<CoinX, CoinY, MemeCoin>,
    coin_in_amount: u64,
    coin_out_min_value: u64,
    is_x: bool
  ): SwapAmount {
    let (balance_x, balance_y) = amounts(pool_state);

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

  fun pool_state<CoinX, CoinY, MemeCoin>(pool: &InterestPool): &PoolState<CoinX, CoinY, MemeCoin> {
    df::borrow(&pool.id, PoolStateKey {})
  }

  fun pool_state_mut<CoinX, CoinY, MemeCoin>(pool: &mut InterestPool): &mut PoolState<CoinX, CoinY, MemeCoin> {
    df::borrow_mut(&mut pool.id, PoolStateKey {})
  }

  fun subtract_from_token_acc(
    pool: &mut InterestPool,
    amount: u64,
    beneficiary: address,
  ) {
    let accounting: &mut Table<address, u64> = df::borrow_mut(&mut pool.id, AccountingDfKey {});

    let position = table::borrow_mut(accounting, beneficiary);
    *position = *position - amount;
  }
  
  fun add_from_token_acc(
    pool: &mut InterestPool,
    amount: u64,
    beneficiary: address,
  ) {
    let accounting: &mut Table<address, u64> = df::borrow_mut(&mut pool.id, AccountingDfKey {});

    let position = table::borrow_mut(accounting, beneficiary);
    *position = *position + amount;
  }

  // === Test Functions ===
  
  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }

  #[test_only]
  public fun seed_liquidity<CoinX, CoinY, MemeCoin>(pool: &InterestPool): u64 {
    let pool_state = pool_state<CoinX, CoinY, MemeCoin>(pool);
    balance::value(&pool_state.launch_balance)
  }

  #[test_only]
  public fun set_liquidity<CoinX, CoinY, MemeCoin>(pool: &mut InterestPool, coin_x: Token<CoinX>, coin_y: Coin<CoinY>) {
    let pool_state = pool_state_mut<CoinX, CoinY, MemeCoin>(pool);
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