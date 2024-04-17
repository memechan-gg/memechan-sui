#[test_only]
module amm::bound_curve_tests {
    use std::option;

    use sui::object;
    use sui::test_utils::assert_eq;
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::clock;
    use sui::coin::{Self, mint_for_testing};
    use sui::sui::SUI;

    use amm::usdc::USDC;
    use amm::fees::{Fees};
    use amm::curves::Bound;
    use amm::ac_b_usdc::AC_B_USDC;
    use amm::bound_curve_amm::{Self, Registry, InterestPool};
    use amm::deploy_utils::{people5, people, scenario, deploy_usdc_sui_pool_default_liquidity};
    use amm::staked_lp;

    const MAX_X: u256 = 900_000_000;
    const MAX_Y: u256 = 30_000;

    const PRECISION: u256 = 1_000_000_000_000_000_000;

    const ADMIN_FEE: u256 = 5_000_000_000_000_000; // 0.5%

    const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
    const SUI_DECIMAL_SCALAR: u64 = 1_000_000_000;

    #[test]
    fun test_bound_full_amt_out() {
        let scenario = scenario();
        let (alice, bob, chad, dan, erin) = people5();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_usdc_sui_pool_default_liquidity(scenario_mut);

        let clock = clock::create_for_testing(ctx(scenario_mut));

        let acc: u256 = 0;
        
        next_tx(scenario_mut, alice);
        {
            let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));

            let res = bound_curve_amm::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            acc = acc + (staked_lp::balance(&res) as u256);

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, bob);
        {
            let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            let res = bound_curve_amm::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            acc = acc + (staked_lp::balance(&res) as u256);

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, chad);
        {
            let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            let res = bound_curve_amm::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            acc = acc + (staked_lp::balance(&res) as u256);

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, dan);
        {
            let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 7_000 * SUI_DECIMAL_SCALAR;
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            let res = bound_curve_amm::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            acc = acc + (staked_lp::balance(&res) as u256);

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, erin);
        {
            let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 15_000 * SUI_DECIMAL_SCALAR;
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            let res = bound_curve_amm::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            acc = acc + (staked_lp::balance(&res) as u256);

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

            let adm_fee_x = (bound_curve_amm::admin_balance_x<AC_B_USDC, SUI, USDC>(&request.pool) as u256);
            let adm_fee_y = (bound_curve_amm::admin_balance_y<AC_B_USDC, SUI, USDC>(&request.pool) as u256);

            let balance_x = (bound_curve_amm::balance_x<AC_B_USDC, SUI, USDC>(&request.pool) as u256);
            let balance_y = (bound_curve_amm::balance_y<AC_B_USDC, SUI, USDC>(&request.pool) as u256);

            assert_eq(acc + adm_fee_x, MAX_X * (USDC_DECIMAL_SCALAR as u256));
            assert_eq(balance_x, 0);
            assert_eq(balance_y, MAX_Y * (SUI_DECIMAL_SCALAR as u256));
            assert_eq(acc + adm_fee_x, MAX_X * (USDC_DECIMAL_SCALAR as u256));
            
            assert_eq((adm_fee_x * PRECISION) / (MAX_X * (USDC_DECIMAL_SCALAR as u256)), ADMIN_FEE);
            assert_eq((adm_fee_y * PRECISION) / (MAX_Y * (SUI_DECIMAL_SCALAR as u256)), ADMIN_FEE);

            destroy_request(request);
        };

        clock::destroy_for_testing(clock);
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
            bound_curve_amm::init_for_testing(ctx(scenario_mut));
        };
    }

    fun request<Curve, CoinX, CoinY, LPCoinType>(scenario_mut: &Scenario): Request {
        let registry = test::take_shared<Registry>(scenario_mut);
        let pool_address = bound_curve_amm::pool_address<Curve, CoinX, CoinY>(&registry);
        let pool = test::take_shared_by_id<InterestPool>(
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
