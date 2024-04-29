#[test_only]
module memechan::bound_curve_tests {
    use std::option;
    use std::debug::print;

    use sui::object;
    use sui::test_utils::assert_eq;
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::clock;
    use sui::coin::{Self, mint_for_testing};
    use sui::sui::SUI;
    use sui::token::TokenPolicy;

    use memechan::admin;
    use memechan::usdc::USDC;
    use memechan::fees::{Fees};
    use memechan::ticket_usdc::TICKET_USDC;
    use memechan::seed_pool::{Self, SeedPool, decimals_s, default_gamma_s, default_gamma_m};
    use memechan::index::{Self, Registry};
    use memechan::deploy_utils::{people5, people, scenario, deploy_usdc_sui_pool_default_liquidity};
    use memechan::staked_lp;

    const MAX_X: u256 = 900_000_000;
    const MAX_Y: u256 = 30_000;

    const PRECISION: u256 = 1_000_000_000_000_000_000;

    const ADMIN_FEE: u256 = 5_000_000_000_000_000; // 0.5%

    const USDC_DECIMAL_SCALAR: u64 = 1_000_000;

    #[test]
    fun test_bound_full_amt_out_y_no_sell() {
        let scenario = scenario();
        let (alice, bob, chad, dan, erin) = people5();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_usdc_sui_pool_default_liquidity(scenario_mut);

        let clock = clock::create_for_testing(ctx(scenario_mut));
       
        let acc: u256 = 0;
        
        next_tx(scenario_mut, alice);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 5_000 * decimals_s();

            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));

            let res = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));
            
            acc = acc + (staked_lp::balance(&res) as u256);

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, bob);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 5_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            let res = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            acc = acc + (staked_lp::balance(&res) as u256);

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, chad);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 5_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            let res = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            acc = acc + (staked_lp::balance(&res) as u256);

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, dan);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 7_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            let res = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            acc = acc + (staked_lp::balance(&res) as u256);

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, erin);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 15_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            let res = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            acc = acc + (staked_lp::balance(&res) as u256);

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let adm_fee_m = (seed_pool::admin_balance_m<TICKET_USDC, SUI, USDC>(&request.pool) as u256);
            let adm_fee_s = (seed_pool::admin_balance_s<TICKET_USDC, SUI, USDC>(&request.pool) as u256);

            let balance_m = (seed_pool::balance_m<TICKET_USDC, SUI, USDC>(&request.pool) as u256);
            let balance_s = (seed_pool::balance_s<TICKET_USDC, SUI, USDC>(&request.pool) as u256);

            assert_eq(acc + adm_fee_m, MAX_X * (USDC_DECIMAL_SCALAR as u256));
            assert_eq(balance_m, 0);
            assert_eq(balance_s, MAX_Y * (decimals_s() as u256));
            assert_eq(((adm_fee_s * PRECISION) / (MAX_Y * (decimals_s() as u256) + adm_fee_s)) / 1_000_000, ADMIN_FEE / 1_000_000);
            assert_eq(((adm_fee_m * PRECISION) / (MAX_X * (USDC_DECIMAL_SCALAR as u256))) / 1_000_000, ADMIN_FEE / 1_000_000);

            destroy_request(request);
        };

        clock::destroy_for_testing(clock);
        test::end(scenario);
    }

    #[test]
    fun test_bound_full_amt_out_y() {
        let scenario = scenario();
        let (alice, bob, chad, dan, erin) = people5();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_usdc_sui_pool_default_liquidity(scenario_mut);

        let clock = clock::create_for_testing(ctx(scenario_mut));
        let cts = clock::timestamp_ms(&clock);

        let chad_staked_lp;

        // Buy Meme
        next_tx(scenario_mut, chad);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 5_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            chad_staked_lp = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            coin::burn_for_testing(coin_in);
            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 6_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));

            let res = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, bob);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 7_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            let res = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        cts = cts + 48 * 3600 * 1000 + 10;

        clock::set_for_testing(&mut clock, cts);

        next_tx(scenario_mut, chad);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);
            let policy = &request.policy;

            let token_in =  staked_lp::into_token(chad_staked_lp, &clock, policy, ctx(scenario_mut));
            
            let res = seed_pool::sell_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, token_in, 1, policy, ctx(scenario_mut));

            coin::burn_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, dan);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 7_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            let res = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, erin);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 15_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            let res = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            coin::burn_for_testing(coin_in);
            staked_lp::destroy_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let balance_m = (seed_pool::balance_m<TICKET_USDC, SUI, USDC>(&request.pool) as u256);
            let balance_s = (seed_pool::balance_s<TICKET_USDC, SUI, USDC>(&request.pool) as u256);

            assert_eq(balance_m, 0);
            assert_eq(balance_s, MAX_Y * (decimals_s() as u256));

            destroy_request(request);
        };

        clock::destroy_for_testing(clock);
        test::end(scenario);
    }

    #[test]
    fun test_bound_full_amt_out_x() {
        let scenario = scenario();
        let (alice, bob, chad, _, erin) = people5();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_usdc_sui_pool_default_liquidity(scenario_mut);

        let clock = clock::create_for_testing(ctx(scenario_mut));
        let cts = clock::timestamp_ms(&clock);

        let alice_staked_lp;
        let bob_staked_lp;
        let chad_staked_lp;

        next_tx(scenario_mut, chad);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 5_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            chad_staked_lp = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            coin::burn_for_testing(coin_in);
            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 5_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            alice_staked_lp = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            coin::burn_for_testing(coin_in);
            destroy_request(request);
        };

        next_tx(scenario_mut, bob);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in = 5_000 * decimals_s();
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
            bob_staked_lp = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

            coin::burn_for_testing(coin_in);
            destroy_request(request);
        };

        cts = cts + 48 * 3600 * 1000 + 10;

        clock::set_for_testing(&mut clock, cts);

        next_tx(scenario_mut, chad);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);
            let policy = &request.policy;

            let token_in =  staked_lp::into_token(chad_staked_lp, &clock, policy, ctx(scenario_mut));
            
            let res = seed_pool::sell_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, token_in, 1, policy, ctx(scenario_mut));

            coin::burn_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);
            let policy = &request.policy;

            let token_in =  staked_lp::into_token(alice_staked_lp, &clock, policy, ctx(scenario_mut));
            
            let res = seed_pool::sell_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, token_in, 1, policy, ctx(scenario_mut));

            coin::burn_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, bob);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);
            let policy = &request.policy;

            let token_in =  staked_lp::into_token(bob_staked_lp, &clock, policy, ctx(scenario_mut));
            
            let res = seed_pool::sell_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, token_in, 1, policy, ctx(scenario_mut));

            coin::burn_for_testing(res);
            destroy_request(request);
        };

        next_tx(scenario_mut, erin); 
        {
            admin::init_for_testing(ctx(scenario_mut));
        };

        let adm_token_x;

        next_tx(scenario_mut, erin); 
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);
            let policy = &request.policy;

            let admin = test::take_from_sender<admin::Admin>(scenario_mut);
            
            let adm_coin_y;
            (adm_token_x, adm_coin_y) = seed_pool::take_fees<TICKET_USDC, SUI, USDC>(&admin, &mut request.pool, policy, ctx(scenario_mut));
            
            //let res = seed_pool::sell_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, adm_token_x, 1, policy, ctx(scenario_mut));

            coin::burn_for_testing(adm_coin_y);
            test::return_to_sender<admin::Admin>(scenario_mut, admin);

            destroy_request(request);
        };

        next_tx(scenario_mut, erin);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);
            let balance_m = (seed_pool::balance_m<TICKET_USDC, SUI, USDC>(&request.pool) as u256);

            assert_eq(MAX_X * (USDC_DECIMAL_SCALAR as u256), (balance_m + (sui::token::value(&adm_token_x) as u256)));

            sui::token::burn_for_testing(adm_token_x);
            destroy_request(request);
        };

        clock::destroy_for_testing(clock);
        test::end(scenario);
    }

    #[test]
    fun test_bound_full_amt_out_y_with_sell() {
        let scenario = scenario();
        let (alice, bob, chad, dan, erin) = people5();

        let scenario_mut = &mut scenario;

        set_up_test(scenario_mut);
        deploy_usdc_sui_pool_default_liquidity(scenario_mut);

        let clock = clock::create_for_testing(ctx(scenario_mut));
       
        let acc: u256 = 0;
        
        next_tx(scenario_mut, alice);
        let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

        let amount_in = 35_000 * decimals_s();

        let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));

        let res = seed_pool::buy_meme<TICKET_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));
            
        acc = acc + (staked_lp::balance(&res) as u256);
        assert_eq(staked_lp::balance(&res), 895_500_000_000_000); // i.e. gamma_m * (1 - fee rate)

        coin::burn_for_testing(coin_in);
        seed_pool::unlock_for_testing<TICKET_USDC, SUI, USDC>(&mut request.pool);
        destroy_request(request);

        next_tx(scenario_mut, alice);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            let amount_in =  298_500_000_000_000;
            let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            // let meme_in = staked_lp::split<TICKET_USDC>(&mut res, amount_in, ctx(scenario_mut));
            let meme_in = staked_lp::into_token_for_testing(
                staked_lp::split<TICKET_USDC>(&mut res, amount_in, ctx(scenario_mut)),
                &request.policy,
                ctx(scenario_mut)
            );

            let Request {
                registry,
                pool,
                pool_fees,
                policy,
            } = request;
            
            let sui_res = seed_pool::sell_meme<TICKET_USDC, SUI, USDC>(&mut pool, meme_in, 1, &policy, ctx(scenario_mut));

            print(&sui_res);

            coin::burn_for_testing(coin_in);
            coin::burn_for_testing(sui_res);

            let request = Request {
                registry,
                pool,
                pool_fees,
                policy,
            };

            destroy_request(request);
        };

        next_tx(scenario_mut, chad);
        {

        };

        next_tx(scenario_mut, dan);
        {

        };

        next_tx(scenario_mut, erin);
        {
            
        };

        next_tx(scenario_mut, alice);
        {
            // let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            // let adm_fee_m = (seed_pool::admin_balance_m<TICKET_USDC, SUI, USDC>(&request.pool) as u256);
            // let adm_fee_s = (seed_pool::admin_balance_s<TICKET_USDC, SUI, USDC>(&request.pool) as u256);

            // let balance_m = (seed_pool::balance_m<TICKET_USDC, SUI, USDC>(&request.pool) as u256);
            // let balance_s = (seed_pool::balance_s<TICKET_USDC, SUI, USDC>(&request.pool) as u256);

            // assert_eq(acc + adm_fee_m, MAX_X * (USDC_DECIMAL_SCALAR as u256));
            // assert_eq(balance_m, 0);
            // assert_eq(balance_s, MAX_Y * (decimals_s() as u256));
            // assert_eq(((adm_fee_s * PRECISION) / (MAX_Y * (decimals_s() as u256) + adm_fee_s)) / 1_000_000, ADMIN_FEE / 1_000_000);
            // assert_eq(((adm_fee_m * PRECISION) / (MAX_X * (USDC_DECIMAL_SCALAR as u256))) / 1_000_000, ADMIN_FEE / 1_000_000);

            // destroy_request(request);
        };

        staked_lp::destroy_for_testing(res);
        clock::destroy_for_testing(clock);
        test::end(scenario);
    }

    // Set up

    struct Request<phantom CoinX> {
        registry: Registry,
        pool: SeedPool,
        pool_fees: Fees,
        policy: TokenPolicy<CoinX>
    }

    fun set_up_test(scenario_mut: &mut Scenario) {
        let (alice, _) = people();

        next_tx(scenario_mut, alice);
        {
            index::init_for_testing(ctx(scenario_mut));
        };
    }

    fun request<CoinX, CoinY, LPCoinType>(scenario_mut: &Scenario): Request<CoinX> {
        let registry = test::take_shared<Registry>(scenario_mut);
        let pool_address = index::seed_pool_address<CoinX, CoinY, LPCoinType>(&registry);
        let pool = test::take_shared_by_id<SeedPool>(
            scenario_mut, object::id_from_address(option::destroy_some(pool_address))
        );
        let pool_fees = seed_pool::fees<CoinX, CoinY, LPCoinType>(&pool);
        let policy = test::take_shared<TokenPolicy<CoinX>>(scenario_mut);

        Request {
            registry,
            pool,
            pool_fees, 
            policy
        }
    }

    fun destroy_request<CoinX>(request: Request<CoinX>) {
        let Request { registry, pool, pool_fees: _, policy } = request;

        test::return_shared(registry);
        test::return_shared(pool); 
        test::return_shared(policy);
    }
}
