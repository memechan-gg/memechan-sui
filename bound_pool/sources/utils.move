module amm::utils {
  use std::ascii;
  use std::type_name;
  use std::string::{Self, String};

  use sui::coin::{Self, CoinMetadata, TreasuryCap};
  use amm::sui::SUI;

  use suitears::comparator;
  use suitears::math64::mul_div_up;
  

  use amm::errors;
  
  public fun are_coins_suitable<CoinA, CoinB>(): bool {
    let coin_a_type_name = type_name::get<CoinA>();
    let coin_b_type_name = type_name::get<CoinB>();
    
    assert!(coin_a_type_name != coin_b_type_name, errors::select_different_coins());
    true
  }

  #[allow(unused_type_parameter)]
  public fun is_coin_x<CoinA, CoinB>(): bool {
    //comparator::lt(&comparator::compare(&type_name::get<CoinA>(), &type_name::get<CoinB>()))
    &type_name::get<CoinB>() == &type_name::get<SUI>()
  }

  public fun get_optimal_add_liquidity(
    desired_amount_x: u64,
    desired_amount_y: u64,
    reserve_x: u64,
    reserve_y: u64
  ): (u64, u64) {

    if (reserve_x == 0 && reserve_y == 0) return (desired_amount_x, desired_amount_y);

    let optimal_y_amount = quote_liquidity(desired_amount_x, reserve_x, reserve_y);
    if (desired_amount_y >= optimal_y_amount) return (desired_amount_x, optimal_y_amount);

    let optimal_x_amount = quote_liquidity(desired_amount_y, reserve_y, reserve_x);
    (optimal_x_amount, desired_amount_y)
  } 

  public fun quote_liquidity(amount_a: u64, reserves_a: u64, reserves_b: u64): u64 {
    mul_div_up(amount_a, reserves_b, reserves_a)
  }

  public fun get_lp_coin_name<CoinX, CoinY>(
    coin_x_metadata: &CoinMetadata<CoinX>,
    coin_y_metadata: &CoinMetadata<CoinY>,  
  ): String {
    let coin_x_name = coin::get_name(coin_x_metadata);
    let coin_y_name = coin::get_name(coin_y_metadata);

    let expected_lp_coin_name = string::utf8(b"");
    string::append_utf8(&mut expected_lp_coin_name, b"ipx ");
    string::append_utf8(&mut expected_lp_coin_name, b"bound ");
    string::append_utf8(&mut expected_lp_coin_name, *string::bytes(&coin_x_name));
    string::append_utf8(&mut expected_lp_coin_name, b" ");
    string::append_utf8(&mut expected_lp_coin_name, *string::bytes(&coin_y_name));
    string::append_utf8(&mut expected_lp_coin_name, b" Lp Coin");
    expected_lp_coin_name
  }

  public fun get_lp_coin_symbol<CoinX, CoinY>(
    coin_x_metadata: &CoinMetadata<CoinX>,
    coin_y_metadata: &CoinMetadata<CoinY>, 
  ): ascii::String {
    let coin_x_symbol = coin::get_symbol(coin_x_metadata);
    let coin_y_symbol = coin::get_symbol(coin_y_metadata);

    let expected_lp_coin_symbol = string::utf8(b"");
    string::append_utf8(&mut expected_lp_coin_symbol, b"ipx-");
    string::append_utf8(&mut expected_lp_coin_symbol, b"b-" );
    string::append_utf8(&mut expected_lp_coin_symbol, ascii::into_bytes(coin_x_symbol));
    string::append_utf8(&mut expected_lp_coin_symbol, b"-");
    string::append_utf8(&mut expected_lp_coin_symbol, ascii::into_bytes(coin_y_symbol));
    string::to_ascii(expected_lp_coin_symbol)
  }


 public fun assert_coin_integrity<CoinX, CoinY>(coin_x_treasury: &TreasuryCap<CoinX>, coin_x_metadata: &CoinMetadata<CoinX>) {
    are_coins_suitable<CoinX, CoinY>();
    
    let coin_b_type_name = type_name::get<CoinY>();
    
    assert!(coin_b_type_name == type_name::get<SUI>(), errors::invalid_quote_token());

    assert!(coin::get_decimals(coin_x_metadata) == 6, errors::base_coin_must_have_6_decimals());
    
    assert!(coin::total_supply<CoinX>(coin_x_treasury) == 0, errors::should_have_0_total_supply())
  }
  public fun assert_lp_coin_integrity<CoinX, CoinY, LpCoin>(lp_coin_metadata: &CoinMetadata<LpCoin>) {
     assert!(coin::get_decimals(lp_coin_metadata) == 9, errors::lp_coins_must_have_9_decimals());
     assert_lp_coin_otw<CoinX, CoinY, LpCoin>()
  }

  fun assert_lp_coin_otw<CoinX, CoinY, LpCoin>() {
    are_coins_suitable<CoinX, CoinY>();
    let coin_x_module_name = type_name::get_module(&type_name::get<CoinX>());
    let coin_y_module_name = type_name::get_module(&type_name::get<CoinY>());
    let lp_coin_module_name = type_name::get_module(&type_name::get<LpCoin>());

    let expected_lp_coin_module_name = string::utf8(b"");
    string::append_utf8(&mut expected_lp_coin_module_name, b"ipx_");
    string::append_utf8(&mut expected_lp_coin_module_name, b"b_");
    string::append_utf8(&mut expected_lp_coin_module_name, ascii::into_bytes(coin_x_module_name));
    string::append_utf8(&mut expected_lp_coin_module_name, b"_");
    string::append_utf8(&mut expected_lp_coin_module_name, ascii::into_bytes(coin_y_module_name));

    assert!(
      comparator::eq(&comparator::compare(&lp_coin_module_name, &string::to_ascii(expected_lp_coin_module_name))), 
      errors::wrong_module_name()
    );
  }
}