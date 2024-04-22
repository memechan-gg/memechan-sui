module memechan::coin_decimals {
  use std::type_name::{Self, TypeName};

  use sui::math::pow;
  use sui::dynamic_field as df;
  use sui::object::{Self, UID};
  use sui::tx_context::TxContext;
  use sui::coin::{Self, CoinMetadata};

  use suitears::coin_decimals::CoinDecimals;

  public fun destroy_coin_decimals(decimals: CoinDecimals, ctx: &mut TxContext) {
    let obj = object::new(ctx);
    df::add(&mut obj, 1, decimals);
    object::delete(obj);
  }
}
