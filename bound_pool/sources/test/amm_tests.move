#[test_only]
module amm::interest_protocol_amm_tests {
  use std::option;
  use std::string::{utf8, to_ascii};

  use sui::table;
  use sui::object;
  use sui::test_utils::assert_eq;
  use sui::coin::{Self, burn_for_testing, TreasuryCap, CoinMetadata, create_treasury_cap_for_testing};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};

  use amm::btc::BTC;
  use amm::sui::SUI;
  use amm::usdc::USDC;
  use amm::fees::{Self, Fees};
  use amm::admin;
  use amm::curves::Bound;
  use amm::ipx_btce_eth::{Self, IPX_BTCE_ETH};
  use amm::ipx_b_usdc_sui::{Self, IPX_B_USDC_SUI};
  use amm::interest_protocol_amm::{Self, Registry, InterestPool};
  use amm::deploy_utils::{people, scenario, deploy_coins};

  const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
  const SUI_DECIMAL_SCALAR: u64 = 1_000_000_000;
  const ADMIN_FEE: u256 = 5_000_000_000_000_000; // 0.5%
  const BASE_TOKENS_CURVED: u64 = 900_000_000_000_000;

  #[test]
  fun test_new_pool() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;
    
    next_tx(scenario_mut, alice);
    {
      ipx_b_usdc_sui::init_for_testing(ctx(scenario_mut));
    };

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_B_USDC_SUI>>(scenario_mut);
      let eth_metadata = test::take_shared<CoinMetadata<SUI>>(scenario_mut);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_B_USDC_SUI>>(scenario_mut);
      
      assert_eq(table::is_empty(interest_protocol_amm::pools(&registry)), true);
      
      interest_protocol_amm::new<USDC, SUI, IPX_B_USDC_SUI>(
        &mut registry,
        //mint_for_testing(usdc_amount, ctx(scenario_mut)),
        create_treasury_cap_for_testing(ctx(scenario_mut)),
        lp_coin_cap,
        &usdc_metadata,
        &eth_metadata,
        &mut lp_coin_metadata,
        ctx(scenario_mut)
      );

      assert_eq(coin::get_symbol(&lp_coin_metadata), to_ascii(utf8(b"ipx-b-USDC-SUI")));
      assert_eq(coin::get_name(&lp_coin_metadata), utf8(b"ipx bound USD Coin Sui Lp Coin"));
      assert_eq(interest_protocol_amm::exists_<Bound, USDC, SUI>(&registry), true);

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };

    next_tx(scenario_mut, alice);
    {
      let request = request<Bound, USDC, SUI, IPX_B_USDC_SUI>(scenario_mut);

      assert_eq(interest_protocol_amm::lp_coin_supply< USDC,SUI, IPX_B_USDC_SUI>(&request.pool), BASE_TOKENS_CURVED);
      assert_eq(interest_protocol_amm::balance_x<USDC, SUI, IPX_B_USDC_SUI>(&request.pool), BASE_TOKENS_CURVED);
      assert_eq(interest_protocol_amm::balance_y<USDC, SUI, IPX_B_USDC_SUI>(&request.pool), 0);
      assert_eq(interest_protocol_amm::decimals_x<USDC, SUI, IPX_B_USDC_SUI>(&request.pool), USDC_DECIMAL_SCALAR);
      assert_eq(interest_protocol_amm::decimals_y<USDC, SUI, IPX_B_USDC_SUI>(&request.pool), SUI_DECIMAL_SCALAR);
      assert_eq(interest_protocol_amm::seed_liquidity<USDC, SUI, IPX_B_USDC_SUI>(&request.pool), BASE_TOKENS_CURVED);
      assert_eq(interest_protocol_amm::locked<USDC, SUI, IPX_B_USDC_SUI>(&request.pool), false);
      assert_eq(interest_protocol_amm::admin_balance_x<USDC, SUI, IPX_B_USDC_SUI>(&request.pool), 0);
      assert_eq(interest_protocol_amm::admin_balance_y<USDC, SUI, IPX_B_USDC_SUI>(&request.pool), 0);

      let fees = interest_protocol_amm::fees<USDC, SUI, IPX_B_USDC_SUI>(&request.pool);

      assert_eq(fees::fee_in_percent(&fees),  ADMIN_FEE);
      assert_eq(fees::fee_out_percent(&fees), ADMIN_FEE);

      destroy_request(request);
    };
    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::EBaseCoinMustHave6Decimals, location = amm::utils)]  
  fun test_new_pool_wrong_lp_coin_decimals() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    next_tx(scenario_mut, alice);
    {
      ipx_btce_eth::init_for_testing(ctx(scenario_mut));
    };

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_BTCE_ETH>>(scenario_mut);
      let btc_metadata = test::take_shared<CoinMetadata<BTC>>(scenario_mut);
      let eth_metadata = test::take_shared<CoinMetadata<SUI>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_BTCE_ETH>>(scenario_mut);
      
      interest_protocol_amm::new<BTC, SUI, IPX_BTCE_ETH>(
        &mut registry,
        create_treasury_cap_for_testing(ctx(scenario_mut)),
        //mint_for_testing(100, ctx(scenario_mut)),
        lp_coin_cap,
        &btc_metadata,
        &eth_metadata,
        &mut lp_coin_metadata,
        ctx(scenario_mut)
      );

      test::return_shared(eth_metadata);
      test::return_shared(btc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::EWrongModuleName, location = amm::utils)]  
  fun test_new_pool_wrong_lp_coin_metadata() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    next_tx(scenario_mut, alice);
    {
      ipx_btce_eth::init_for_testing(ctx(scenario_mut));
    };

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_BTCE_ETH>>(scenario_mut);
      let btc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
      let eth_metadata = test::take_shared<CoinMetadata<SUI>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_BTCE_ETH>>(scenario_mut);
      
      interest_protocol_amm::new<USDC, SUI, IPX_BTCE_ETH>(
        &mut registry,
        create_treasury_cap_for_testing(ctx(scenario_mut)),
        //mint_for_testing(100, ctx(scenario_mut)),
        lp_coin_cap,
        &btc_metadata,
        &eth_metadata,
        &mut lp_coin_metadata,
        ctx(scenario_mut)
      );

      test::return_shared(eth_metadata);
      test::return_shared(btc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };    
    test::end(scenario);
  }

  #[test]
  #[expected_failure(abort_code = amm::errors::ESupplyMustHaveZeroValue, location = amm::interest_protocol_amm)]  
  fun test_new_pool_wrong_lp_coin_supply() {
    let (scenario, alice, _) = start_test();  

    let scenario_mut = &mut scenario;

    next_tx(scenario_mut, alice);
    {
      ipx_b_usdc_sui::init_for_testing(ctx(scenario_mut));
    };

    next_tx(scenario_mut, alice);
    {
      let registry = test::take_shared<Registry>(scenario_mut);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_B_USDC_SUI>>(scenario_mut);
      let eth_metadata = test::take_shared<CoinMetadata<SUI>>(scenario_mut);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_B_USDC_SUI>>(scenario_mut);

      burn_for_testing(coin::mint(&mut lp_coin_cap, 100, ctx(scenario_mut)));
      
      interest_protocol_amm::new<USDC, SUI, IPX_B_USDC_SUI>(
        &mut registry,
        create_treasury_cap_for_testing(ctx(scenario_mut)),
        //mint_for_testing(100, ctx(scenario_mut)),
        lp_coin_cap,
        &usdc_metadata,
        &eth_metadata,
        &mut lp_coin_metadata,
        ctx(scenario_mut)
      );

      test::return_shared(eth_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };    
    test::end(scenario);
  }

  struct Request {
    registry: Registry,
    pool: InterestPool,
    fees: Fees
  } 

  fun request<Curve, CoinX, CoinY, LpCoin>(scenario_mut: &Scenario): Request {
      let registry = test::take_shared<Registry>(scenario_mut);
      let pool_address = interest_protocol_amm::pool_address<Curve, CoinX, CoinY>(&registry);
      let pool = test::take_shared_by_id<InterestPool>(scenario_mut, object::id_from_address(option::destroy_some(pool_address)));
      let fees = interest_protocol_amm::fees<CoinX, CoinY, LpCoin>(&pool);

    Request {
      registry,
      pool,
      fees
    }
  }

  fun destroy_request(request: Request) {
    let Request { registry, pool, fees: _ } = request;
  
    test::return_shared(registry);
    test::return_shared(pool);
  }        
  
  fun start_test(): (Scenario, address, address) {
    let scenario = scenario();
    let (alice, bob) = people();

    let scenario_mut = &mut scenario;

    deploy_coins(scenario_mut);

    next_tx(scenario_mut, alice);
    {
      admin::init_for_testing(ctx(scenario_mut));
      interest_protocol_amm::init_for_testing(ctx(scenario_mut));
    };

    (scenario, alice, bob)
  }
}