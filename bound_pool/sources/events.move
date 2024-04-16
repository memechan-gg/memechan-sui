module amm::events {

  use sui::event::emit;

  friend amm::interest_protocol_amm;
  friend amm::token_ir;

  struct NewPool<phantom Curve, phantom CoinX, phantom CoinY> has copy, drop {
    pool_address: address,
    amount_x: u64,
    amount_y: u64,
    policy_address: address,
  }

  struct Swap<phantom CoinIn, phantom CoinOut, T: drop + copy + store> has copy, drop {
    pool_address: address,
    amount_in: u64,
    swap_amount: T
  }

  struct AddLiquidity<phantom CoinX, phantom CoinY> has copy, drop {
    pool_address: address,
    amount_x: u64,
    amount_y: u64,
    shares: u64  
  }

  struct RemoveLiquidity<phantom CoinX, phantom CoinY> has copy, drop {
    pool_address: address,
    amount_x: u64,
    amount_y: u64,
    shares: u64,
    fee_x_value: u64,
    fee_y_value: u64    
  }

  public(friend) fun new_pool<Curve, CoinX, CoinY>(
    pool_address: address,
    amount_x: u64,
    amount_y: u64,
    policy_address: address,
  ) {
    emit(NewPool<Curve, CoinX, CoinY>{ pool_address, amount_x, amount_y, policy_address });
  }

  public(friend) fun swap<CoinIn, CoinOut, T: copy + drop + store>(
    pool_address: address,
    amount_in: u64,
    swap_amount: T   
  ) {
    emit(Swap<CoinIn, CoinOut, T> { pool_address, amount_in, swap_amount });
  }

  public(friend) fun add_liquidity<CoinX, CoinY>(
    pool_address: address,
    amount_x: u64,
    amount_y: u64,
    shares: u64    
  ) {
    emit(AddLiquidity<CoinX, CoinY> { pool_address, amount_x, amount_y, shares });
  }

  public(friend) fun remove_liquidity<CoinX, CoinY>(
    pool_address: address,
    amount_x: u64,
    amount_y: u64,
    shares: u64,
    fee_x_value: u64,
    fee_y_value: u64  
  ) {
    emit(RemoveLiquidity<CoinX, CoinY> { pool_address, amount_x, amount_y, shares, fee_x_value, fee_y_value });
  }
}