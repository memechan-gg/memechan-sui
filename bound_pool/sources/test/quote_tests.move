#[test_only]
module amm::quote_tests {
  use std::option;

  use sui::object;
  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
  
  use amm::quote;
  use amm::bound;
  use amm::sui::SUI;
  use amm::usdc::USDC;
  use amm::fees::{Self, Fees};
  use amm::curves::Bound;
  use amm::ipx_b_usdc_sui::IPX_B_USDC_SUI;
  use amm::interest_protocol_amm::{Self, Registry, InterestPool};
  use amm::deploy_utils::{people, scenario, deploy_usdc_sui_pool};

  const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
  const SUI_DECIMAL_SCALAR: u64 = 1_000_000_000;

  #[test]
  fun test_bound_quote_amount_out() {
    let scenario = scenario();
    let (alice, _) = people();

    let scenario_mut = &mut scenario;

    set_up_test(scenario_mut);
    deploy_usdc_sui_pool(scenario_mut, 10_000 * SUI_DECIMAL_SCALAR, 400_000_000 * USDC_DECIMAL_SCALAR);

    next_tx(scenario_mut, alice);
    {
      let request = request<Bound, USDC, SUI, IPX_B_USDC_SUI>(scenario_mut);

      let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.pool_fees, amount_in);
      let expected_amount_out = bound::get_amount_out(amount_in - amount_in_fee,  400_000_000 * USDC_DECIMAL_SCALAR, 10_000 * SUI_DECIMAL_SCALAR, false);
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&request.pool_fees, expected_amount_out); 

      assert_eq(quote::amount_out<SUI, USDC, IPX_B_USDC_SUI>(&request.pool, amount_in), expected_amount_out);

      destroy_request(request);
    };

    next_tx(scenario_mut, alice);
    {
      let request = request<Bound, USDC, SUI, IPX_B_USDC_SUI>(scenario_mut);

      let amount_in = 175_000_000 * USDC_DECIMAL_SCALAR;
      let amount_in_fee = fees::get_fee_in_amount(&request.pool_fees, amount_in);
      let expected_amount_out = bound::get_amount_out(amount_in - amount_in_fee, 400_000_000 * USDC_DECIMAL_SCALAR, 10_000 * SUI_DECIMAL_SCALAR, true);
      let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&request.pool_fees, expected_amount_out); 

      assert_eq(quote::amount_out<USDC, SUI, IPX_B_USDC_SUI>(&request.pool, amount_in), expected_amount_out);

      destroy_request(request);
    };
    test::end(scenario);    
  }

  #[test]
  fun test_bound_quote_amount_in() {
    let scenario = scenario();
    let (alice, _) = people();

    let scenario_mut = &mut scenario;

    set_up_test(scenario_mut);
    deploy_usdc_sui_pool(scenario_mut, 10_000 * SUI_DECIMAL_SCALAR, 400_000_000 * USDC_DECIMAL_SCALAR);

    next_tx(scenario_mut, alice);
    {
      let request = request<Bound, USDC, SUI, IPX_B_USDC_SUI>(scenario_mut);

      let amount_out = 5_000 * SUI_DECIMAL_SCALAR;
      let amount_out_before_fee = fees::get_fee_out_initial_amount(&request.pool_fees, amount_out);

      let expected_amount_in = fees::get_fee_in_initial_amount(
        &request.pool_fees, 
        bound::get_amount_in(amount_out_before_fee, 400_000_000 * USDC_DECIMAL_SCALAR, 10_000 * SUI_DECIMAL_SCALAR, false)
      );

      assert_eq(quote::amount_in<SUI, USDC, IPX_B_USDC_SUI>(&request.pool, amount_out), expected_amount_in);

      destroy_request(request);
    };

    next_tx(scenario_mut, alice);
    {
      let request = request<Bound, USDC, SUI, IPX_B_USDC_SUI>(scenario_mut);     

      let amount_out = 175_000_000 * USDC_DECIMAL_SCALAR;
      let amount_out_before_fee = fees::get_fee_out_initial_amount(&request.pool_fees, amount_out);

      let expected_amount_in = fees::get_fee_in_initial_amount(
        &request.pool_fees, 
        bound::get_amount_in(amount_out_before_fee, 400_000_000 * USDC_DECIMAL_SCALAR, 10_000 * SUI_DECIMAL_SCALAR, true)
      );

      assert_eq(quote::amount_in<USDC, SUI, IPX_B_USDC_SUI>(&request.pool, amount_out), expected_amount_in);

      destroy_request(request);
    };

    test::end(scenario);
  }

  // Set up

  struct Request {
    registry: Registry,
    pool: InterestPool,
    pool_fees: Fees
  }

  fun set_up_test(scenario_mut: &mut Scenario) {
    let (alice, _) = people();

    next_tx(scenario_mut, alice);
    {
      interest_protocol_amm::init_for_testing(ctx(scenario_mut));
    };
  }

  fun request<Curve, CoinX, CoinY, LPCoinType>(scenario_mut: &Scenario): Request {
    let registry = test::take_shared<Registry>(scenario_mut);
    let pool_address = interest_protocol_amm::pool_address<Curve, CoinX, CoinY>(&registry);
    let pool = test::take_shared_by_id<InterestPool>(
      scenario_mut, object::id_from_address(option::destroy_some(pool_address))
    );
    let pool_fees = interest_protocol_amm::fees<CoinX, CoinY, LPCoinType>(&pool);

    Request {
      registry,
      pool,
      pool_fees
    }
  }

  fun destroy_request(request: Request) {
    let Request { registry, pool, pool_fees: _ } = request;

    test::return_shared(registry);
    test::return_shared(pool); 
  }
}