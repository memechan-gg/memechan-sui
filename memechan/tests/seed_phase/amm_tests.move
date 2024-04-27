#[test_only]
module memechan::bound_curve_amm_tests {
    use std::option;
    use std::string::{utf8, to_ascii};

    use sui::table;
    use sui::object;
    use sui::test_utils::assert_eq;
    use sui::coin::{Self, burn_for_testing, TreasuryCap, CoinMetadata, create_treasury_cap_for_testing};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::sui::SUI;
    
    use memechan::errors;
    use memechan::utils;
    use memechan::btc::BTC;
    use memechan::usdc::USDC;
    use memechan::fees::{Self, Fees};
    use memechan::admin;
    use memechan::ticket_btc::{Self, TICKET_BTC};
    use memechan::tickettce::{Self, TICKETTCE};
    use memechan::ticket_usdc::{Self, TICKET_USDC};
    use memechan::bound_curve_amm::{Self, SeedPool};
    use memechan::index::{Self, Registry};
    use memechan::deploy_utils::{people, scenario, deploy_coins};

    const ADMIN_FEE: u256 = 5_000_000_000_000_000; // 0.5%
    const BASE_TOKENS_CURVED: u64 = 900_000_000_000_000;
    const BASE_TOKEN_LAUNCHED: u64 = 200_000_000_000_000;

    #[test]
    fun test_new_pool() {
        let (scenario, alice, _) = start_test();

        let scenario_mut = &mut scenario;
        
        next_tx(scenario_mut, alice);
        {
            ticket_usdc::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);
        {
            let registry = test::take_shared<Registry>(scenario_mut);
            let ticket_coin_cap = test::take_from_sender<TreasuryCap<TICKET_USDC>>(scenario_mut);
            let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
            let ticket_coin_metadata = test::take_shared<CoinMetadata<TICKET_USDC>>(scenario_mut);
            
            assert_eq(table::is_empty(index::seed_pools(&registry)), true);
            
            bound_curve_amm::new_default<TICKET_USDC, SUI, USDC>(
                &mut registry,
                //mint_for_testing(usdc_amount, ctx(scenario_mut)),
                ticket_coin_cap,
                create_treasury_cap_for_testing(ctx(scenario_mut)),
                &mut ticket_coin_metadata,
                &usdc_metadata,
                ctx(scenario_mut)
            );

            assert_eq(coin::get_symbol(&ticket_coin_metadata), to_ascii(utf8(b"ticket-USDC")));
            assert_eq(coin::get_name(&ticket_coin_metadata), utf8(b"USD Coin Ticket Coin"));
            assert_eq(index::exists_seed_pool<TICKET_USDC, SUI, USDC>(&registry), true);

            test::return_shared(usdc_metadata);
            test::return_shared(ticket_coin_metadata);
            test::return_shared(registry);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<TICKET_USDC, SUI, USDC>(scenario_mut);

            assert_eq(bound_curve_amm::meme_coin_supply<TICKET_USDC, SUI, USDC>(&request.pool), BASE_TOKENS_CURVED + BASE_TOKEN_LAUNCHED);
            assert_eq(bound_curve_amm::ticket_coin_supply<TICKET_USDC, SUI, USDC>(&request.pool), BASE_TOKENS_CURVED);
            assert_eq(bound_curve_amm::balance_m<TICKET_USDC, SUI, USDC>(&request.pool), BASE_TOKENS_CURVED);
            assert_eq(bound_curve_amm::balance_s<TICKET_USDC, SUI, USDC>(&request.pool), 0);
            // assert_eq(bound_curve_amm::decimals_x<TICKET_USDC, SUI, USDC>(&request.pool), USDC_DECIMAL_SCALAR);
            // assert_eq(bound_curve_amm::decimals_y<TICKET_USDC, SUI, USDC>(&request.pool), SUI_DECIMAL_SCALAR);
            assert_eq(bound_curve_amm::seed_liquidity<TICKET_USDC, SUI, USDC>(&request.pool), BASE_TOKENS_CURVED + BASE_TOKEN_LAUNCHED);
            assert_eq(bound_curve_amm::is_ready_to_launch<TICKET_USDC, SUI, USDC>(&request.pool), false);
            assert_eq(bound_curve_amm::admin_balance_m<TICKET_USDC, SUI, USDC>(&request.pool), 0);
            assert_eq(bound_curve_amm::admin_balance_s<TICKET_USDC, SUI, USDC>(&request.pool), 0);

            let fees = bound_curve_amm::fees<TICKET_USDC, SUI, USDC>(&request.pool);

            assert_eq(fees::fee_in_percent(&fees), ADMIN_FEE);
            assert_eq(fees::fee_out_percent(&fees), ADMIN_FEE);

            destroy_request(request);
        };
        
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = errors::EMemeAndTicketCoinsMustHave6Decimals, location = utils)]
    fun test_new_pool_wrong_lp_coin_decimals() {
        let (scenario, alice, _) = start_test();

        let scenario_mut = &mut scenario;

        next_tx(scenario_mut, alice);
        {
            tickettce::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);
        {
            let registry = test::take_shared<Registry>(scenario_mut);
            let lp_coin_cap = test::take_from_sender<TreasuryCap<TICKETTCE>>(scenario_mut);
            let btc_metadata = test::take_shared<CoinMetadata<BTC>>(scenario_mut);
            let lp_coin_metadata = test::take_shared<CoinMetadata<TICKETTCE>>(scenario_mut);
            
            bound_curve_amm::new_default<TICKETTCE, SUI, BTC>(
                &mut registry,
                lp_coin_cap,
                create_treasury_cap_for_testing(ctx(scenario_mut)),
                //mint_for_testing(100, ctx(scenario_mut)),
                &mut lp_coin_metadata,
                &btc_metadata,
                ctx(scenario_mut)
            );

            test::return_shared(btc_metadata);
            test::return_shared(lp_coin_metadata);
            test::return_shared(registry);
        };
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = errors::EWrongModuleName, location = utils)]
    fun test_new_pool_wrong_lp_coin_metadata() {
        let (scenario, alice, _) = start_test();

        let scenario_mut = &mut scenario;

        next_tx(scenario_mut, alice);
        {
            ticket_btc::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);
        {
            let registry = test::take_shared<Registry>(scenario_mut);
            let lp_coin_cap = test::take_from_sender<TreasuryCap<TICKET_BTC>>(scenario_mut);
            let btc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
            let lp_coin_metadata = test::take_shared<CoinMetadata<TICKET_BTC>>(scenario_mut);
            
            bound_curve_amm::new_default<TICKET_BTC, SUI, USDC>(
                &mut registry,
                lp_coin_cap,
                create_treasury_cap_for_testing(ctx(scenario_mut)),
                //mint_for_testing(100, ctx(scenario_mut)),
                &mut lp_coin_metadata,
                &btc_metadata,
                ctx(scenario_mut)
            );

            test::return_shared(btc_metadata);
            test::return_shared(lp_coin_metadata);
            test::return_shared(registry);
        };
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = errors::EMemeAndTicketCoinsShouldHaveZeroTotalSupply, location = utils)]
    fun test_new_pool_wrong_lp_coin_supply() {
        let (scenario, alice, _) = start_test();

        let scenario_mut = &mut scenario;

        next_tx(scenario_mut, alice);
        {
            ticket_usdc::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);
        {
            let registry = test::take_shared<Registry>(scenario_mut);
            let lp_coin_cap = test::take_from_sender<TreasuryCap<TICKET_USDC>>(scenario_mut);
            let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
            let lp_coin_metadata = test::take_shared<CoinMetadata<TICKET_USDC>>(scenario_mut);

            burn_for_testing(coin::mint(&mut lp_coin_cap, 100, ctx(scenario_mut)));
            
            bound_curve_amm::new_default<TICKET_USDC, SUI, USDC>(
                &mut registry,
                lp_coin_cap,
                create_treasury_cap_for_testing(ctx(scenario_mut)),
                //mint_for_testing(100, ctx(scenario_mut)),
                &mut lp_coin_metadata,
                &usdc_metadata,
                ctx(scenario_mut)
            );
            
            test::return_shared(usdc_metadata);
            test::return_shared(lp_coin_metadata);
            test::return_shared(registry);
        };
        test::end(scenario);
    }

    struct Request {
        registry: Registry,
        pool: SeedPool,
        fees: Fees
    } 

    fun request<M, S, Meme>(scenario_mut: &Scenario): Request {
            let registry = test::take_shared<Registry>(scenario_mut);
            let pool_address = index::seed_pool_address<M, S, Meme>(&registry);
            let pool = test::take_shared_by_id<SeedPool>(scenario_mut, object::id_from_address(option::destroy_some(pool_address)));
            let fees = bound_curve_amm::fees<M, S, Meme>(&pool);

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
            index::init_for_testing(ctx(scenario_mut));
        };

        (scenario, alice, bob)
    }
}