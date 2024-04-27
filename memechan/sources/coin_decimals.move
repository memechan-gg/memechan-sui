module memechan::coin_decimals {
  use sui::dynamic_field as df;
  use sui::object;
  use sui::tx_context::TxContext;

  use suitears::coin_decimals::CoinDecimals;

  public fun destroy_coin_decimals(decimals: CoinDecimals, ctx: &mut TxContext) {
    let obj = object::new(ctx);
    df::add(&mut obj, 1, decimals);
    object::delete(obj);
  }
}
