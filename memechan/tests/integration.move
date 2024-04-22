#[test_only]
module memechan::integration {
    use std::debug::print;
    use std::option;
    use std::string::{utf8, to_ascii};

    use sui::table;
    use sui::clock;
    use sui::object;
    use sui::test_utils::assert_eq;
    use sui::coin::{Self, burn_for_testing, TreasuryCap, CoinMetadata, create_treasury_cap_for_testing};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::sui::SUI;
    use sui::types;
    
    use memechan::errors;
    use memechan::utils;
    use memechan::boden::{Self, BODEN};
    use memechan::ac_b_boden::{Self, AC_B_BODEN};
    use memechan::usdc::{Self, USDC};
    use memechan::fees::{Self, Fees};
    use memechan::admin;
    use memechan::staked_lp;
    use memechan::curves::Bound;
    use memechan::ac_b_btc::{Self, AC_B_BTC};
    use memechan::ac_btce::{Self, AC_BTCE};
    use memechan::ac_b_usdc::{Self, AC_B_USDC};
    use memechan::bound_curve_amm::{
        Self, SeedPool, default_meme_supply_staking_pool, default_meme_supply_lp_liquidity
    };
    use memechan::index::{Self, Registry};
    use memechan::deploy_utils::{people, scenario, deploy_coins, sui};

    const USDC_DECIMAL_SCALAR: u64 = 1_000_000;
    const SUI_DECIMAL_SCALAR: u64 = 1_000_000_000;
    const ADMIN_FEE: u256 = 5_000_000_000_000_000; // 0.5%
    const BASE_TOKENS_CURVED: u64 = 900_000_000_000_000;
    const BASE_TOKEN_LAUNCHED: u64 = 200_000_000_000_000;


    #[test]
    fun integration() {
        // print()types::is_one_time_witness<S_BODEN>();

        let (scenario, alice, bob) = start_test();

        let scenario_mut = &mut scenario;
        
        // Initiate S joe boden token
        next_tx(scenario_mut, alice);
        {
            ac_b_boden::init_for_testing(ctx(scenario_mut));
            boden::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);

        let registry = test::take_shared<Registry>(scenario_mut);
        let ticket_coin_cap = test::take_from_sender<TreasuryCap<AC_B_BODEN>>(scenario_mut);
        let ticket_coin_metadata = test::take_shared<CoinMetadata<AC_B_BODEN>>(scenario_mut);
        let boden_coin_cap = test::take_from_sender<TreasuryCap<BODEN>>(scenario_mut);
        let boden_metadata = test::take_shared<CoinMetadata<BODEN>>(scenario_mut);
            
        assert_eq(table::is_empty(index::seed_pools(&registry)), true);
            
        bound_curve_amm::new_default<AC_B_BODEN, SUI, BODEN>(
            &mut registry,
            ticket_coin_cap, // AC_B_BODEN
            boden_coin_cap, // BODEN
            &mut ticket_coin_metadata,
            &boden_metadata,
            ctx(scenario_mut)
        );

        next_tx(scenario_mut, bob);

        let seed_pool = test::take_shared<SeedPool>(scenario_mut);
        let clock = clock::create_for_testing(ctx(scenario_mut));

        let t = 100_000;
        while (t > 0) {
            next_tx(scenario_mut, bob);
            let sui_mony = coin::mint_for_testing<SUI>(sui(1_000), ctx(scenario_mut));

            let staked_sboden = bound_curve_amm::swap_coin_y<AC_B_BODEN, SUI, BODEN>(
                &mut seed_pool,
                &mut sui_mony,
                0,
                &clock,
                ctx(scenario_mut),
            );
            print(&staked_lp::balance(&staked_sboden));
            // print(&coin::value(&sui_mony));
            coin::burn_for_testing(sui_mony);
            staked_lp::destroy_for_testing(staked_sboden);
        };

        clock::destroy_for_testing(clock);
        test::return_shared(boden_metadata);
        test::return_shared(seed_pool);
        test::return_shared(ticket_coin_metadata);
        test::return_shared(registry);
        test::end(scenario);
    }
    
    #[test]
    fun integration_2() {
        // print()types::is_one_time_witness<S_BODEN>();

        let (scenario, alice, bob) = start_test();

        let scenario_mut = &mut scenario;
        
        // Initiate S joe boden token
        next_tx(scenario_mut, alice);
        {
            ac_b_boden::init_for_testing(ctx(scenario_mut));
            boden::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);

        let registry = test::take_shared<Registry>(scenario_mut);
        let ticket_coin_cap = test::take_from_sender<TreasuryCap<AC_B_BODEN>>(scenario_mut);
        let ticket_coin_metadata = test::take_shared<CoinMetadata<AC_B_BODEN>>(scenario_mut);
        let boden_coin_cap = test::take_from_sender<TreasuryCap<BODEN>>(scenario_mut);
        let boden_metadata = test::take_shared<CoinMetadata<BODEN>>(scenario_mut);
            
        assert_eq(table::is_empty(index::seed_pools(&registry)), true);
            
        bound_curve_amm::new<AC_B_BODEN, SUI, BODEN>(
            &mut registry,
            ticket_coin_cap, // AC_B_BODEN
            boden_coin_cap, // BODEN
            &mut ticket_coin_metadata,
            &boden_metadata,
            0,
            0,
            default_meme_supply_staking_pool(),
            default_meme_supply_lp_liquidity(),
            ctx(scenario_mut)
        );

        next_tx(scenario_mut, bob);

        let seed_pool = test::take_shared<SeedPool>(scenario_mut);
        let clock = clock::create_for_testing(ctx(scenario_mut));

        let t = 100_000;
        let i = 0;
        while (t > 0) {
            next_tx(scenario_mut, bob);

            let amt = sui(1);
            let sui_mony = coin::mint_for_testing<SUI>(amt, ctx(scenario_mut));
            i = i + amt;

            let staked_sboden = bound_curve_amm::swap_coin_y<AC_B_BODEN, SUI, BODEN>(
                &mut seed_pool,
                &mut sui_mony,
                0,
                &clock,
                ctx(scenario_mut),
            );
            print(&bound_curve_amm::balance_x<AC_B_BODEN, SUI, BODEN>(&seed_pool));
            print(&(default_meme_supply_staking_pool() - i));
            assert!(bound_curve_amm::balance_x<AC_B_BODEN, SUI, BODEN>(&seed_pool) == default_meme_supply_staking_pool() - i, 0);
            // print(&staked_lp::balance(&staked_sboden));
            // print(&coin::value(&sui_mony));
            coin::burn_for_testing(sui_mony);
            staked_lp::destroy_for_testing(staked_sboden);
        };

        clock::destroy_for_testing(clock);
        test::return_shared(boden_metadata);
        test::return_shared(seed_pool);
        test::return_shared(ticket_coin_metadata);
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