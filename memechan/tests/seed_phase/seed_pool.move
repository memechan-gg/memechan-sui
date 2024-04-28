// #[test_only]
// module memechan::bound_curve_tests {
//     use std::option;

//     use sui::object;
//     use sui::test_utils::assert_eq;
//     use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
//     use sui::clock;
//     use sui::coin::{Self, mint_for_testing};
//     use sui::sui::SUI;
//     use sui::token::TokenPolicy;

//     use memechan::admin;
//     use memechan::bound;
//     use memechan::usdc::USDC;
//     use memechan::fees::{Fees};
//     use memechan::curves::Bound;
//     use memechan::ac_b_usdc::AC_B_USDC;
//     use memechan::seed_pool::{Self, SeedPool};
//     use memechan::index::{Self, Registry};
//     use memechan::deploy_utils::{people5, people, scenario, deploy_usdc_sui_pool_default_liquidity};
//     use memechan::staked_lp;

//     const MAX_X: u256 = 900_000_000;
//     const MAX_Y: u256 = 30_000;

//     const PRECISION: u256 = 1_000_000_000_000_000_000;

//     const ADMIN_FEE: u256 = 5_000_000_000_000_000; // 0.5%

//     const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
//     const SUI_DECIMAL_SCALAR: u64 = 1_000_000_000;

//     #[test]
//     fun test_bound_full_amt_out_y_no_sell() {
//         let scenario = scenario();
//         let (alice, bob, chad, dan, erin) = people5();

//         let scenario_mut = &mut scenario;

//         set_up_test(scenario_mut);
//         deploy_usdc_sui_pool_default_liquidity(scenario_mut);

//         let clock = clock::create_for_testing(ctx(scenario_mut));
       
//         let acc: u256 = 0;
        
//         next_tx(scenario_mut, alice);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));

//             let res = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             acc = acc + (staked_lp::balance(&res) as u256);

//             coin::burn_for_testing(coin_in);
//             staked_lp::destroy_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, bob);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
//             let res = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             acc = acc + (staked_lp::balance(&res) as u256);

//             coin::burn_for_testing(coin_in);
//             staked_lp::destroy_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, chad);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
//             let res = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             acc = acc + (staked_lp::balance(&res) as u256);

//             coin::burn_for_testing(coin_in);
//             staked_lp::destroy_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, dan);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 7_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
//             let res = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             acc = acc + (staked_lp::balance(&res) as u256);

//             coin::burn_for_testing(coin_in);
//             staked_lp::destroy_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, erin);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 15_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
//             let res = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             acc = acc + (staked_lp::balance(&res) as u256);

//             coin::burn_for_testing(coin_in);
//             staked_lp::destroy_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, alice);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let adm_fee_x = (seed_pool::admin_balance_x<AC_B_USDC, SUI, USDC>(&request.pool) as u256);
//             let adm_fee_y = (seed_pool::admin_balance_y<AC_B_USDC, SUI, USDC>(&request.pool) as u256);

//             let balance_x = (seed_pool::balance_x<AC_B_USDC, SUI, USDC>(&request.pool) as u256);
//             let balance_y = (seed_pool::balance_y<AC_B_USDC, SUI, USDC>(&request.pool) as u256);

//             assert_eq(acc + adm_fee_x, MAX_X * (USDC_DECIMAL_SCALAR as u256));
//             assert_eq(balance_x, 0);
//             assert_eq(balance_y, MAX_Y * (SUI_DECIMAL_SCALAR as u256));
            
//             assert_eq((adm_fee_x * PRECISION) / (MAX_X * (USDC_DECIMAL_SCALAR as u256)), ADMIN_FEE);
//             assert_eq((adm_fee_y * PRECISION) / (MAX_Y * (SUI_DECIMAL_SCALAR as u256)), ADMIN_FEE);

//             destroy_request(request);
//         };

//         clock::destroy_for_testing(clock);
//         test::end(scenario);
//     }

//     #[test]
//     fun test_bound_full_amt_out_y() {
//         let scenario = scenario();
//         let (alice, bob, chad, dan, erin) = people5();

//         let scenario_mut = &mut scenario;

//         set_up_test(scenario_mut);
//         deploy_usdc_sui_pool_default_liquidity(scenario_mut);

//         let clock = clock::create_for_testing(ctx(scenario_mut));
//         let cts = clock::timestamp_ms(&clock);

//         let chad_staked_lp;

//         next_tx(scenario_mut, chad);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
//             chad_staked_lp = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             coin::burn_for_testing(coin_in);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, alice);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 6_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));

//             let res = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             coin::burn_for_testing(coin_in);
//             staked_lp::destroy_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, bob);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 7_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
//             let res = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             coin::burn_for_testing(coin_in);
//             staked_lp::destroy_for_testing(res);
//             destroy_request(request);
//         };

//         cts = cts + 48 * 3600 * 1000 + 10;

//         clock::set_for_testing(&mut clock, cts);

//         next_tx(scenario_mut, chad);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);
//             let policy = &request.policy;

//             let token_in =  staked_lp::into_token(chad_staked_lp, &clock, policy, ctx(scenario_mut));
            
//             let res = seed_pool::swap_coin_x<AC_B_USDC, SUI, USDC>(&mut request.pool, token_in, 1, policy, ctx(scenario_mut));

//             coin::burn_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, dan);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 7_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
//             let res = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             coin::burn_for_testing(coin_in);
//             staked_lp::destroy_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, erin);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 15_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
//             let res = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             coin::burn_for_testing(coin_in);
//             staked_lp::destroy_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, alice);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let balance_x = (seed_pool::balance_x<AC_B_USDC, SUI, USDC>(&request.pool) as u256);
//             let balance_y = (seed_pool::balance_y<AC_B_USDC, SUI, USDC>(&request.pool) as u256);

//             assert_eq(balance_x, 0);
//             assert_eq(balance_y, MAX_Y * (SUI_DECIMAL_SCALAR as u256));

//             destroy_request(request);
//         };

//         clock::destroy_for_testing(clock);
//         test::end(scenario);
//     }

//     #[test]
//     fun test_bound_full_amt_out_x() {
//         let scenario = scenario();
//         let (alice, bob, chad, _, erin) = people5();

//         let scenario_mut = &mut scenario;

//         set_up_test(scenario_mut);
//         deploy_usdc_sui_pool_default_liquidity(scenario_mut);

//         let clock = clock::create_for_testing(ctx(scenario_mut));
//         let cts = clock::timestamp_ms(&clock);

//         let alice_staked_lp;
//         let bob_staked_lp;
//         let chad_staked_lp;

//         next_tx(scenario_mut, chad);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
//             chad_staked_lp = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             coin::burn_for_testing(coin_in);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, alice);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
//             alice_staked_lp = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             coin::burn_for_testing(coin_in);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, bob);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let amount_in = 5_000 * SUI_DECIMAL_SCALAR;
//             let coin_in = mint_for_testing<SUI>(amount_in, ctx(scenario_mut));
            
//             bob_staked_lp = seed_pool::swap_coin_y<AC_B_USDC, SUI, USDC>(&mut request.pool, &mut coin_in, 1, &clock, ctx(scenario_mut));

//             coin::burn_for_testing(coin_in);
//             destroy_request(request);
//         };

//         cts = cts + 48 * 3600 * 1000 + 10;

//         clock::set_for_testing(&mut clock, cts);

//         next_tx(scenario_mut, chad);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);
//             let policy = &request.policy;

//             let token_in =  staked_lp::into_token(chad_staked_lp, &clock, policy, ctx(scenario_mut));
            
//             let res = seed_pool::swap_coin_x<AC_B_USDC, SUI, USDC>(&mut request.pool, token_in, 1, policy, ctx(scenario_mut));

//             coin::burn_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, alice);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);
//             let policy = &request.policy;

//             let token_in =  staked_lp::into_token(alice_staked_lp, &clock, policy, ctx(scenario_mut));
            
//             let res = seed_pool::swap_coin_x<AC_B_USDC, SUI, USDC>(&mut request.pool, token_in, 1, policy, ctx(scenario_mut));

//             coin::burn_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, bob);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);
//             let policy = &request.policy;

//             let token_in =  staked_lp::into_token(bob_staked_lp, &clock, policy, ctx(scenario_mut));
            
//             let res = seed_pool::swap_coin_x<AC_B_USDC, SUI, USDC>(&mut request.pool, token_in, 1, policy, ctx(scenario_mut));

//             coin::burn_for_testing(res);
//             destroy_request(request);
//         };

//         next_tx(scenario_mut, erin); 
//         {
//             admin::init_for_testing(ctx(scenario_mut));
//         };

//         let adm_token_x;

//         next_tx(scenario_mut, erin); 
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);
//             let policy = &request.policy;

//             let admin = test::take_from_sender<admin::Admin>(scenario_mut);
            
//             let adm_coin_y;
//             (adm_token_x, adm_coin_y) = seed_pool::take_fees<AC_B_USDC, SUI, USDC>(&admin, &mut request.pool, policy, ctx(scenario_mut));
            
//             //let res = seed_pool::swap_coin_x<AC_B_USDC, SUI, USDC>(&mut request.pool, adm_token_x, 1, policy, ctx(scenario_mut));

//             coin::burn_for_testing(adm_coin_y);
//             test::return_to_sender<admin::Admin>(scenario_mut, admin);

//             destroy_request(request);
//         };

//         next_tx(scenario_mut, erin);
//         {
//             let request = request<Bound, AC_B_USDC, SUI, USDC>(scenario_mut);

//             let balance_x = (seed_pool::balance_x<AC_B_USDC, SUI, USDC>(&request.pool) as u256);
//             let balance_y = (seed_pool::balance_y<AC_B_USDC, SUI, USDC>(&request.pool) as u256);

//             assert_eq(MAX_X * (USDC_DECIMAL_SCALAR as u256), (balance_x + (sui::token::value(&adm_token_x) as u256)));

//             let adm_swap_res = bound::get_amount_out(sui::token::value(&adm_token_x), (balance_x as u64), (balance_y as u64), true);
//             assert_eq(balance_y, (adm_swap_res as u256));

//             sui::token::burn_for_testing(adm_token_x);
//             destroy_request(request);
//         };

//         clock::destroy_for_testing(clock);
//         test::end(scenario);
//     }

//     // Set up

//     struct Request<phantom CoinX> {
//         registry: Registry,
//         pool: SeedPool,
//         pool_fees: Fees,
//         policy: TokenPolicy<CoinX>
//     }

//     fun set_up_test(scenario_mut: &mut Scenario) {
//         let (alice, _) = people();

//         next_tx(scenario_mut, alice);
//         {
//             index::init_for_testing(ctx(scenario_mut));
//         };
//     }

//     fun request<Curve, CoinX, CoinY, LPCoinType>(scenario_mut: &Scenario): Request<CoinX> {
//         let registry = test::take_shared<Registry>(scenario_mut);
//         let pool_address = index::seed_pool_address<Curve, CoinX, CoinY>(&registry);
//         let pool = test::take_shared_by_id<SeedPool>(
//             scenario_mut, object::id_from_address(option::destroy_some(pool_address))
//         );
//         let pool_fees = seed_pool::fees<CoinX, CoinY, LPCoinType>(&pool);
//         let policy = test::take_shared<TokenPolicy<CoinX>>(scenario_mut);

//         Request {
//             registry,
//             pool,
//             pool_fees, 
//             policy
//         }
//     }

//     fun destroy_request<CoinX>(request: Request<CoinX>) {
//         let Request { registry, pool, pool_fees: _, policy } = request;

//         test::return_shared(registry);
//         test::return_shared(pool); 
//         test::return_shared(policy);
//     }


// }
