#[test_only]
module amm::utils_tests {
  use std::string::{utf8, to_ascii};

  use sui::coin::CoinMetadata;
  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, next_tx, ctx};

  use amm::btc::BTC;
  use amm::eth::ETH;
  use amm::sui::SUI;
  use amm::ipx_b_btc_sui::{Self, IPX_B_BTC_SUI};
  use amm::ipx_btce_eth::{Self, IPX_BTCE_ETH};
  use amm::ipx_btc_eth_wrong_decimals::{Self, IPX_BTC_ETH_WRONG_DECIMALS};
  use amm::deploy_utils::{scenario, people, deploy_coins};
  use amm::utils::{
    is_coin_x, 
    quote_liquidity,
    get_lp_coin_name,
    are_coins_suitable, 
    get_lp_coin_symbol,
    assert_lp_coin_integrity,
    get_optimal_add_liquidity, 
  };

  struct ABC {}

  struct CAB {}

  #[test]
  fun test_are_coins_suitable() {
    assert_eq(are_coins_suitable<ABC, SUI>(), true);
    assert_eq(are_coins_suitable<CAB, SUI>(), true);
  }

  #[test]
  fun test_is_coin_x() {
    assert_eq(is_coin_x<SUI, ABC>(), false);
    assert_eq(is_coin_x<ABC, SUI>(), true);
    assert_eq(is_coin_x<SUI, CAB>(), false);
    assert_eq(is_coin_x<CAB, SUI>(), true);
    // does not throw
    assert_eq(is_coin_x<ETH, ETH>(), false);
  }

  #[test]
  fun test_get_optimal_add_liquidity() {
    let (x, y) = get_optimal_add_liquidity(5, 10, 0, 0);
    assert_eq(x, 5);
    assert_eq(y, 10);

    let (x, y) = get_optimal_add_liquidity(8, 4, 20, 30);
    assert_eq(x, 3);
    assert_eq(y, 4);

    let (x, y) = get_optimal_add_liquidity(15, 25, 50, 100);
    assert_eq(x, 13);
    assert_eq(y, 25);

    let (x, y) = get_optimal_add_liquidity(12, 18, 30, 20);
    assert_eq(x, 12);
    assert_eq(y, 8);

    let (x, y) = get_optimal_add_liquidity(9876543210,1234567890,987654,123456);
    assert_eq(x, 9876543210);
    assert_eq(y, 1234560402);

    let (x, y) = get_optimal_add_liquidity(999999999, 888888888, 777777777, 666666666);
    assert_eq(x, 999999999);
    assert_eq(y, 857142857);

    let (x, y) = get_optimal_add_liquidity(987654321, 9876543210, 123456, 987654);
    assert_eq(x, 987654321);
    assert_eq(y, 7901282569);
  }

  #[test]
  fun test_quote_liquidity() {
    assert_eq(quote_liquidity(10, 2, 5), 25);
    assert_eq(quote_liquidity(1000000, 100, 50000), 500000000);
    assert_eq(quote_liquidity(7, 7, 7), 7);
    assert_eq(quote_liquidity(0, 2, 100), 0);
    assert_eq(quote_liquidity(7, 3, 2), 5); // ~ 4.6
  }

  #[test]
  fun test_get_lp_coin_name() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);

    next_tx(test, alice); 
    {
      let btc_metadata = test::take_shared<CoinMetadata<BTC>>(test);
      let sui_metadata = test::take_shared<CoinMetadata<SUI>>(test);

      assert_eq(get_lp_coin_name<BTC, SUI>(
        &btc_metadata,
        &sui_metadata,
      ),
      utf8(b"ipx bound Bitcoin Sui Lp Coin")
      );

      test::return_shared(btc_metadata);
      test::return_shared(sui_metadata);
    };

    test::end(scenario);
  }

  #[test]
  fun test_get_lp_coin_symbol() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);

    next_tx(test, alice); 
    {
      let btc_metadata = test::take_shared<CoinMetadata<BTC>>(test);
      let sui_metadata = test::take_shared<CoinMetadata<SUI>>(test);

      assert_eq(get_lp_coin_symbol<BTC, SUI>(
        &btc_metadata,
        &sui_metadata
      ),
      to_ascii(utf8(b"ipx-b-BTC-SUI"))
      );

      test::return_shared(btc_metadata);
      test::return_shared(sui_metadata);
    };

    test::end(scenario);
  }

  #[test]
  fun test_assert_lp_coin_integrity() {
   let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);

    next_tx(test, alice);
    {
      ipx_b_btc_sui::init_for_testing(ctx(test));
    };

    next_tx(test, alice); 
    {
      let metadata = test::take_shared<CoinMetadata<IPX_B_BTC_SUI>>(test);

      assert_lp_coin_integrity<BTC, SUI, IPX_B_BTC_SUI>(&metadata);

      test::return_shared(metadata);
    };

    test::end(scenario);    
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::ELpCoinsMustHave9Decimals, location = amm::utils)]
  fun test_assert_lp_coin_integrity_wrong_decimal() {
   let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);

    next_tx(test, alice);
    {
      ipx_btc_eth_wrong_decimals::init_for_testing(ctx(test));
    };

    next_tx(test, alice); 
    {
      let metadata = test::take_shared<CoinMetadata<IPX_BTC_ETH_WRONG_DECIMALS>>(test);

      assert_lp_coin_integrity<BTC, ETH, IPX_BTC_ETH_WRONG_DECIMALS>(&metadata);

      test::return_shared(metadata);
    };

    test::end(scenario);    
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::EWrongModuleName, location = amm::utils)]
  fun test_assert_lp_coin_integrity_wrong_lp_module_name() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    deploy_coins(test);

    next_tx(test, alice);
    {
      ipx_btce_eth::init_for_testing(ctx(test));
    };

    next_tx(test, alice); 
    {
      let metadata = test::take_shared<CoinMetadata<IPX_BTCE_ETH>>(test);

      assert_lp_coin_integrity<BTC, SUI, IPX_BTCE_ETH>(&metadata);

      test::return_shared(metadata);
    };

    test::end(scenario);    
  }

  #[test]
  #[expected_failure]
  fun test_are_coins_suitable_same_coin() {
    are_coins_suitable<SUI, SUI>();
  }
}

#[test_only]
module amm::ipx_btc_eth_wrong_decimals {
  use std::option;

  use sui::transfer;
  use sui::coin;
  use sui::tx_context::{Self, TxContext};

  struct IPX_BTC_ETH_WRONG_DECIMALS has drop {}

  #[lint_allow(share_owned)]
  fun init(witness: IPX_BTC_ETH_WRONG_DECIMALS, ctx: &mut TxContext) {
      let (treasury_cap, metadata) = coin::create_currency(
            witness, 
            8, 
            b"",
            b"", 
            b"", 
            option::none(), 
            ctx
        );

      transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
      transfer::public_share_object(metadata);
  }

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(IPX_BTC_ETH_WRONG_DECIMALS {}, ctx);
  }  
}
