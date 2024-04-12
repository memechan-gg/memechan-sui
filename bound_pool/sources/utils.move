module amm::utils {
  use std::ascii;
  use std::type_name;
  use std::string::{Self, String};

  use sui::coin::{Self, CoinMetadata, TreasuryCap};
  use sui::sui::SUI;

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

  public fun get_ticket_coin_name<MemeCoin>(
    meme_coin_metadata: &CoinMetadata<MemeCoin>,
  ): String {
    let meme_coin_name = coin::get_name(meme_coin_metadata);

    let expected_ticket_coin_name = string::utf8(b"");
    string::append_utf8(&mut expected_ticket_coin_name, b"ac ");
    string::append_utf8(&mut expected_ticket_coin_name, b"bound ");
    string::append_utf8(&mut expected_ticket_coin_name, *string::bytes(&meme_coin_name));
    string::append_utf8(&mut expected_ticket_coin_name, b" Ticket Coin");
    expected_ticket_coin_name
  }

  public fun get_ticket_coin_symbol<MemeCoin>(
    meme_coin_metadata: &CoinMetadata<MemeCoin>,
  ): ascii::String {
    let meme_coin_symbol = coin::get_symbol(meme_coin_metadata);

    let expected_ticket_coin_symbol = string::utf8(b"");
    string::append_utf8(&mut expected_ticket_coin_symbol, b"ac-");
    string::append_utf8(&mut expected_ticket_coin_symbol, b"b-" );
    string::append_utf8(&mut expected_ticket_coin_symbol, ascii::into_bytes(meme_coin_symbol));
    string::to_ascii(expected_ticket_coin_symbol)
  }


 public fun assert_coin_integrity<TicketCoin, CoinY, MemeCoin>(ticket_cap: &TreasuryCap<TicketCoin>, ticket_meta: &CoinMetadata<TicketCoin>, meme_cap: &TreasuryCap<MemeCoin>, meme_meta: &CoinMetadata<MemeCoin>) {
    are_coins_suitable<TicketCoin, CoinY>();
    
    let coin_b_type_name = type_name::get<CoinY>();
    
    assert!(coin_b_type_name == type_name::get<SUI>(), errors::invalid_quote_token());

    assert_coin_integrity_tm(ticket_cap, ticket_meta);
    assert_coin_integrity_tm(meme_cap, meme_meta);
  }

  public fun assert_coin_integrity_tm<Coin>(coin_cap: &TreasuryCap<Coin>, coin_metadata: &CoinMetadata<Coin>) {
    assert!(coin::get_decimals(coin_metadata) == 6, errors::meme_and_ticket_coins_must_have_6_decimals());
    assert!(coin::total_supply(coin_cap) == 0, errors::should_have_0_total_supply());
  }

  public fun assert_ticket_coin_integrity<TicketCoin, CoinY, MemeCoin>(coin_metadata: &CoinMetadata<TicketCoin>) {
     assert!(coin::get_decimals(coin_metadata) == 6, errors::meme_and_ticket_coins_must_have_6_decimals());
     assert_ticket_coin_otw<TicketCoin, CoinY, MemeCoin>()
  }

  fun assert_ticket_coin_otw<TicketCoin, CoinY, MemeCoin>() {
    are_coins_suitable<TicketCoin, CoinY>();
    let meme_coin_module_name = type_name::get_module(&type_name::get<MemeCoin>());
    let ticket_coin_module_name = type_name::get_module(&type_name::get<TicketCoin>());

    let expected_ticket_coin_module_name = string::utf8(b"");
    string::append_utf8(&mut expected_ticket_coin_module_name, b"ac_");
    string::append_utf8(&mut expected_ticket_coin_module_name, b"b_");
    string::append_utf8(&mut expected_ticket_coin_module_name, ascii::into_bytes(meme_coin_module_name));

    assert!(
      comparator::eq(&comparator::compare(&ticket_coin_module_name, &string::to_ascii(expected_ticket_coin_module_name))), 
      errors::wrong_module_name()
    );
  }
}