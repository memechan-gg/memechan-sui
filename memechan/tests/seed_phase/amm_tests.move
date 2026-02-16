#[test_only]
module memechan::seed_pool_tests {
    use std::option;

    use sui::table;
    use sui::transfer;
    use sui::coin;
    use sui::object;
    use sui::test_utils::assert_eq;
    use sui::coin::{TreasuryCap, CoinMetadata};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::sui::SUI;
    
    use memechan::usdc::USDC;
    use memechan::fees::{Self, Fees};
    use memechan::admin;
    use memechan::seed_pool::{Self, SeedPool};
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
            let registry = test::take_shared<Registry>(scenario_mut);
            let meme_coin_cap = test::take_from_sender<TreasuryCap<USDC>>(scenario_mut);
            let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);
            
            assert_eq(table::is_empty(index::seed_pools(&registry)), true);
            
            seed_pool::new_default<SUI, USDC>(
                &mut registry,
                meme_coin_cap,
                ctx(scenario_mut)
            );

            assert_eq(index::exists_seed_pool<SUI, USDC>(&registry), true);

            test::return_shared(usdc_metadata);
            test::return_shared(registry);
        };

        next_tx(scenario_mut, alice);
        {
            let request = request<SUI, USDC>(scenario_mut);

            assert_eq(seed_pool::meme_coin_supply<SUI, USDC>(&request.pool), BASE_TOKEN_LAUNCHED);
            assert_eq(seed_pool::ticket_coin_supply<SUI, USDC>(&request.pool), BASE_TOKENS_CURVED);
            assert_eq(seed_pool::balance_m<SUI, USDC>(&request.pool), BASE_TOKENS_CURVED);
            assert_eq(seed_pool::balance_s<SUI, USDC>(&request.pool), 0);
            assert_eq(seed_pool::seed_liquidity<SUI, USDC>(&request.pool), BASE_TOKEN_LAUNCHED);
            assert_eq(seed_pool::is_ready_to_launch<SUI, USDC>(&request.pool), false);
            assert_eq(seed_pool::admin_balance_m<SUI, USDC>(&request.pool), 0);
            assert_eq(seed_pool::admin_balance_s<SUI, USDC>(&request.pool), 0);

            let fees = seed_pool::fees<SUI, USDC>(&request.pool);

            assert_eq(fees::fee_in_percent(&fees), ADMIN_FEE);
            assert_eq(fees::fee_out_percent(&fees), ADMIN_FEE);

            destroy_request(request);
        };
        
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = seed_pool::EMemeCoinsShouldHaveZeroTotalSupply, location = seed_pool)]
    fun test_new_pool_wrong_lp_coin_supply() {
        let (scenario, alice, _) = start_test();

        let scenario_mut = &mut scenario;

        next_tx(scenario_mut, alice);
        {
            let registry = test::take_shared<Registry>(scenario_mut);
            let meme_coin_cap = test::take_from_sender<TreasuryCap<USDC>>(scenario_mut);
            let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(scenario_mut);

            let coins = coin::mint(&mut meme_coin_cap, 1_000_000, ctx(scenario_mut));
            
            seed_pool::new_default<SUI, USDC>(
                &mut registry,
                meme_coin_cap,
                ctx(scenario_mut),
            );
            
            transfer::public_transfer(coins, @0x0);
            test::return_shared(usdc_metadata);
            test::return_shared(registry);
        };
        test::end(scenario);
    }

    struct Request<phantom S, phantom Meme> {
        registry: Registry,
        pool: SeedPool<S, Meme>,
        fees: Fees
    } 

    fun request<S, Meme>(scenario_mut: &Scenario): Request<S, Meme> {
            let registry = test::take_shared<Registry>(scenario_mut);
            let pool_address = index::seed_pool_address<S, Meme>(&registry);
            let pool = test::take_shared_by_id<SeedPool<S, Meme>>(scenario_mut, object::id_from_address(option::destroy_some(pool_address)));
            let fees = seed_pool::fees<S, Meme>(&pool);

        Request {
            registry,
            pool,
            fees
        }
    }

    fun destroy_request<S, Meme>(request: Request<S, Meme>) {
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