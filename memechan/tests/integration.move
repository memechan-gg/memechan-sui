#[test_only]
module memechan::integration {
    use std::vector;
    use sui::table;
    use sui::clock;
    use sui::test_utils::assert_eq;
    use sui::coin::{Self, TreasuryCap, CoinMetadata};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::sui::SUI;
    use sui::token::{Self, TokenPolicy};
    use memechan::boden::{Self, BODEN};
    use memechan::ticket_boden::{Self, TICKET_BODEN};
    use memechan::admin;
    use memechan::staked_lp;
    use memechan::bound_curve_amm::{
        Self, SeedPool, default_price_factor, default_gamma_s, default_gamma_m, default_omega_m,
        is_ready_to_launch
    };
    use memechan::index::{Self, Registry};
    use memechan::deploy_utils::{people, scenario, deploy_coins, sui};

    #[test]
    fun integration() {
        let (scenario, alice, bob) = start_test();

        let scenario_mut = &mut scenario;
        
        // Initiate S joe boden token
        next_tx(scenario_mut, alice);
        {
            ticket_boden::init_for_testing(ctx(scenario_mut));
            boden::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);

        let registry = test::take_shared<Registry>(scenario_mut);
        let ticket_coin_cap = test::take_from_sender<TreasuryCap<TICKET_BODEN>>(scenario_mut);
        let ticket_coin_metadata = test::take_shared<CoinMetadata<TICKET_BODEN>>(scenario_mut);
        let boden_coin_cap = test::take_from_sender<TreasuryCap<BODEN>>(scenario_mut);
        let boden_metadata = test::take_shared<CoinMetadata<BODEN>>(scenario_mut);
            
        assert_eq(table::is_empty(index::seed_pools(&registry)), true);
            
        bound_curve_amm::new<TICKET_BODEN, SUI, BODEN>(
            &mut registry,
            ticket_coin_cap, // TICKET_BODEN
            boden_coin_cap, // BODEN
            &mut ticket_coin_metadata,
            &boden_metadata,
            0,
            0,
            default_price_factor(),
            (default_gamma_s() as u64),
            (default_gamma_m() as u64),
            (default_omega_m() as u64),
            ctx(scenario_mut)
        );

        next_tx(scenario_mut, bob);

        let token_policy = test::take_shared<TokenPolicy<TICKET_BODEN>>(scenario_mut);
        let seed_pool = test::take_shared<SeedPool>(scenario_mut);
        let clock = clock::create_for_testing(ctx(scenario_mut));

        let meme_monies = vector[];
        let amt_raised = 0;
        let meme_tokens_in_pool = (default_gamma_m() as u64);

        let sui_amt = 10;

        loop {
            next_tx(scenario_mut, bob);

            let amt = sui(sui_amt);
            let sui_mony = coin::mint_for_testing<SUI>(amt, ctx(scenario_mut));

            let staked_sboden = bound_curve_amm::buy_meme<TICKET_BODEN, SUI, BODEN>(
                &mut seed_pool,
                &mut sui_mony,
                0,
                &clock,
                ctx(scenario_mut),
            );
            amt_raised = amt_raised + amt;
            meme_tokens_in_pool = meme_tokens_in_pool - staked_lp::balance(&staked_sboden);
            
            // print(&staked_lp::balance(&staked_sboden));
            assert!(bound_curve_amm::balance_s<TICKET_BODEN, SUI, BODEN>(&seed_pool) == amt_raised, 0);
            assert!(bound_curve_amm::balance_m<TICKET_BODEN, SUI, BODEN>(&seed_pool) == meme_tokens_in_pool, 0);

            vector::push_back(&mut meme_monies, staked_lp::balance(&staked_sboden));

            coin::burn_for_testing(sui_mony);
            staked_lp::destroy_for_testing(staked_sboden);


            if (is_ready_to_launch<TICKET_BODEN, SUI, BODEN>(&seed_pool)) {
                break
            }
        };

        bound_curve_amm::unlock_for_testing<TICKET_BODEN, SUI, BODEN>(&mut seed_pool);

        let i = 0;

        loop {
            next_tx(scenario_mut, bob);

            if (vector::is_empty(&meme_monies)) {
                let pool_balance = bound_curve_amm::balance_s<TICKET_BODEN, SUI, BODEN>(&seed_pool);
                
                // Check that the cumulative rounding error of all trades does not exceed 1_000 MIST
                // The rounding error is in favor of the Pool nonetheless
                assert!(pool_balance < 1_000, 0);
                break
            };
            
            let meme_amt = vector::pop_back(&mut meme_monies);

            if (i == 0) {
                // meme_amt = 13_333_888_889; // for 1 sui
                meme_amt = 133_388_888_889; // for 10 sui
            };
            i = i + 1;

            let meme_mony = token::mint_for_testing<TICKET_BODEN>(meme_amt, ctx(scenario_mut));

            let sui_mony = bound_curve_amm::sell_meme<TICKET_BODEN, SUI, BODEN>(
                &mut seed_pool,
                meme_mony,
                0,
                &token_policy,
                ctx(scenario_mut),
            );
            
            assert!(coin::value(&sui_mony) <= sui(sui_amt), 0);
            assert!(coin::value(&sui_mony) >= sui(sui_amt) - 1, 0);

            coin::burn_for_testing(sui_mony);

            if (bound_curve_amm::balance_s<TICKET_BODEN, SUI, BODEN>(&seed_pool) == 0) {
                break
            }
        };

        clock::destroy_for_testing(clock);
        test::return_shared(boden_metadata);
        test::return_shared(seed_pool);
        test::return_shared(ticket_coin_metadata);
        test::return_shared(token_policy);
        test::return_shared(registry);
        test::end(scenario);
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