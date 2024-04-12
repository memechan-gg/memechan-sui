module amm::errors {

  const ENotEnoughFundsToLend: u64 = 0;
  const EFeeIsTooHigh: u64 = 1;
  const ESelectDifferentCoins: u64 = 2;
  const EProvideBothCoins: u64 = 3;
  const EPoolAlreadyDeployed: u64 = 5;
  const ESupplyMustHaveZeroValue: u64 = 6;
  const ELpCoinsMustHave9Decimals: u64 = 7;
  const ESlippage: u64 = 8;
  const ENoZeroCoin: u64 = 9;
  const EInvalidInvariant: u64 = 10;
  const EPoolIsLocked: u64 = 11;
  const EWrongModuleName: u64 = 13;
  const EInsufficientLiquidity: u64 = 14;
  const EWrongPool: u64 = 15;
  const EDepositAmountIsTooLow: u64 = 16;
  const EInvalidRentPerSecond: u64 = 17;
  const EInvalidQuoteToken: u64 = 18;
  const EBaseCoinMustHave6Decimals: u64 = 19;
  const EInvalidActiveAccount: u64 = 20;
  const EBaseCoinShouldHaveZeroTotalSupply: u64 = 21;
  const ELPStakeTimeNotPassed: u64 = 22;
  
  public fun not_enough_funds_to_lend(): u64 {
    ENotEnoughFundsToLend
  }

  public fun fee_is_too_high(): u64 {
    EFeeIsTooHigh
  }

  public fun select_different_coins(): u64 {
    ESelectDifferentCoins
  }

  public fun provide_both_coins(): u64 {
    EProvideBothCoins
  }

  public fun pool_already_deployed(): u64 {
    EPoolAlreadyDeployed
  }

  public fun supply_must_have_zero_value(): u64 {
    ESupplyMustHaveZeroValue
  }

  public fun lp_coins_must_have_9_decimals(): u64 {
    ELpCoinsMustHave9Decimals
  }

  public fun base_coin_must_have_6_decimals(): u64 {
    EBaseCoinMustHave6Decimals
  }

  public fun should_have_0_total_supply(): u64 {
    EBaseCoinShouldHaveZeroTotalSupply
  }
  public fun lp_stake_time_not_passed(): u64 {
    ELPStakeTimeNotPassed
  }

  public fun slippage(): u64 {
    ESlippage
  }

  public fun no_zero_coin(): u64 {
    ENoZeroCoin
  }

  public fun invalid_invariant(): u64 {
    EInvalidInvariant
  }

  public fun pool_is_locked(): u64 {
    EPoolIsLocked
  }

  public fun wrong_module_name(): u64 {
    EWrongModuleName
  }

  public fun insufficient_liquidity(): u64 {
    EInsufficientLiquidity
  }

  public fun wrong_pool(): u64 {
    EWrongPool
  }

  public fun deposit_amount_is_too_low(): u64 {
    EDepositAmountIsTooLow
  }

  public fun invalid_rent_per_second(): u64 {
    EInvalidRentPerSecond
  }

  public fun invalid_quote_token(): u64 {
    EInvalidQuoteToken
  }

  public fun invalid_active_account(): u64 {
    EInvalidActiveAccount
  }

}
