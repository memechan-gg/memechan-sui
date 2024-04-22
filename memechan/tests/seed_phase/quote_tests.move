#[test_only]
module memechan::quote_tests {
    use std::option;

    use sui::object;
    use sui::test_utils::assert_eq;
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::sui::SUI;

    use memechan::quote;
    use memechan::bound;
    use memechan::usdc::USDC;
    use memechan::fees::{Self, Fees};
    use memechan::curves::Bound;
    use memechan::ac_b_usdc::AC_B_USDC;
    use memechan::bound_curve_amm::{Self, SeedPool};
    use memechan::index::{Self, Registry};
    use memechan::deploy_utils::{people, scenario, deploy_usdc_sui_pool};

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
            let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
            let amount_in_fee = fees::get_fee_in_amount(&request.pool_fees, amount_in);
            let expected_amount_out = bound::get_amount_out(amount_in - amount_in_fee, 400_000_000 * USDC_DECIMAL_SCALAR, 10_000 * SUI_DECIMAL_SCALAR, false);
            let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&request.pool_fees, expected_amount_out);

            let res = quote::amount_out<SUI, AC_B_USDC, USDC>(&request.pool, amount_in);
            assert_eq(res, expected_amount_out);

            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 175_000_000 * USDC_DECIMAL_SCALAR;
            let amount_in_fee = fees::get_fee_in_amount(&request.pool_fees, amount_in);
            let expected_amount_out = bound::get_amount_out(amount_in - amount_in_fee, 400_000_000 * USDC_DECIMAL_SCALAR, 10_000 * SUI_DECIMAL_SCALAR, true);
            let expected_amount_out = expected_amount_out - fees::get_fee_out_amount(&request.pool_fees, expected_amount_out);

            let res = quote::amount_out<AC_B_USDC, SUI, USDC>(&request.pool, amount_in);
            assert_eq(res, expected_amount_out);

            destroy_request(request);
        };
        test::end(scenario);
    }

    // Set up

    struct Request {
        registry: Registry,
        pool: SeedPool,
        pool_fees: Fees
    }

    fun set_up_test(scenario_mut: &mut Scenario) {
        let (alice, _) = people();

        next_tx(scenario_mut, alice);
        {
            index::init_for_testing(ctx(scenario_mut));
        };
    }

    fun request<Curve, CoinX, CoinY, LPCoinType>(scenario_mut: &Scenario): Request {
        let registry = test::take_shared<Registry>(scenario_mut);
        let pool_address = index::seed_pool_address<Curve, CoinX, CoinY>(&registry);
        let pool = test::take_shared_by_id<SeedPool>(
            scenario_mut, object::id_from_address(option::destroy_some(pool_address))
        );
        let pool_fees = bound_curve_amm::fees<CoinX, CoinY, LPCoinType>(&pool);

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