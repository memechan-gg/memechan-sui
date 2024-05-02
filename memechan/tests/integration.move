#[test_only]
module memechan::integration {
    use std::vector;
    use sui::table;
    use sui::transfer;
    use sui::clock;
    use sui::test_utils::assert_eq;
    use sui::coin::{Self, TreasuryCap, CoinMetadata};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::token::{Self, TokenPolicy};
    use clamm::interest_clamm_volatile as volatile;
    use clamm::interest_pool::InterestPool;
    use clamm::curves::Volatile;
    use memechan::go_live;
    use memechan::boden;
    use memechan::utils::mist;
    use memechan::lp_coin::{Self, LP_COIN};
    use memechan::boden::{BODEN};
    use memechan::sui::{Self, SUI};
    use memechan::admin::{Self, Admin};
    use memechan::staked_lp::{Self, default_sell_delay_ms};
    use memechan::seed_pool::{
        Self, SeedPool, default_price_factor, default_gamma_s, default_gamma_m, default_omega_m,
        is_ready_to_launch
    };
    use memechan::staking_pool::{Self, StakingPool};
    use memechan::index::{Self, Registry};
    use memechan::deploy_utils::{people, scenario, deploy_coins, sui};

    #[test]
    fun seed_pool_2e2() {
        let (scenario, alice, bob) = start_test();

        let scenario_mut = &mut scenario;
                
        // Initiate S joe boden token
        next_tx(scenario_mut, alice);
        {
            boden::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);

        let registry = test::take_shared<Registry>(scenario_mut);
        let boden_coin_cap = test::take_from_sender<TreasuryCap<BODEN>>(scenario_mut);
            
        assert_eq(table::is_empty(index::seed_pools(&registry)), true);
            
        seed_pool::new<SUI, BODEN>(
            &mut registry,
            boden_coin_cap, // BODEN
            0,
            0,
            default_price_factor(),
            (default_gamma_s() as u64),
            (default_gamma_m() as u64),
            (default_omega_m() as u64),
            default_sell_delay_ms(),
            ctx(scenario_mut)
        );

        next_tx(scenario_mut, bob);

        let token_policy = test::take_shared<TokenPolicy<BODEN>>(scenario_mut);
        let seed_pool = test::take_shared<SeedPool<SUI, BODEN>>(scenario_mut);
        let clock = clock::create_for_testing(ctx(scenario_mut));

        let meme_monies = vector[];
        let amt_raised = 0;
        let meme_tokens_in_pool = (default_gamma_m() as u64);

        let sui_amt = 10;

        loop {
            next_tx(scenario_mut, bob);

            let amt = sui(sui_amt);
            let sui_mony = coin::mint_for_testing<SUI>(amt, ctx(scenario_mut));

            let staked_sboden = seed_pool::buy_meme<SUI, BODEN>(
                &mut seed_pool,
                &mut sui_mony,
                0,
                &clock,
                ctx(scenario_mut),
            );
            amt_raised = amt_raised + amt;
            meme_tokens_in_pool = meme_tokens_in_pool - staked_lp::balance(&staked_sboden);
            
            assert!(seed_pool::balance_s<SUI, BODEN>(&seed_pool) == amt_raised, 0);
            assert!(seed_pool::balance_m<SUI, BODEN>(&seed_pool) == meme_tokens_in_pool, 0);

            vector::push_back(&mut meme_monies, staked_lp::balance(&staked_sboden));

            coin::burn_for_testing(sui_mony);
            staked_lp::destroy_for_testing(staked_sboden);


            if (is_ready_to_launch<SUI, BODEN>(&seed_pool)) {
                break
            }
        };

        seed_pool::unlock_for_testing<SUI, BODEN>(&mut seed_pool);

        let i = 0;

        loop {
            next_tx(scenario_mut, bob);

            if (vector::is_empty(&meme_monies)) {
                let pool_balance = seed_pool::balance_s<SUI, BODEN>(&seed_pool);
                
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

            let meme_mony = token::mint_for_testing<BODEN>(meme_amt, ctx(scenario_mut));

            let sui_mony = seed_pool::sell_meme<SUI, BODEN>(
                &mut seed_pool,
                meme_mony,
                0,
                &token_policy,
                ctx(scenario_mut),
            );
            
            assert!(coin::value(&sui_mony) <= sui(sui_amt), 0);
            assert!(coin::value(&sui_mony) >= sui(sui_amt) - 1, 0);

            coin::burn_for_testing(sui_mony);

            if (seed_pool::balance_s<SUI, BODEN>(&seed_pool) == 0) {
                break
            }
        };

        clock::destroy_for_testing(clock);
        test::return_shared(seed_pool);
        test::return_shared(token_policy);
        test::return_shared(registry);
        test::end(scenario);
    }

    use std::debug::print;

    #[test]
    fun test_1_sui_raise() {
        let (scenario, alice, bob) = start_test();

        let scenario_mut = &mut scenario;
                
        // Initiate S joe boden token
        next_tx(scenario_mut, alice);
        {
            boden::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);

        let registry = test::take_shared<Registry>(scenario_mut);
        let boden_coin_cap = test::take_from_sender<TreasuryCap<BODEN>>(scenario_mut);
            
        assert_eq(table::is_empty(index::seed_pools(&registry)), true);

        // bondingCurveCustomParams:  {
        //   feeInPercent: 5000000000000000n,
        //   feeOutPercent: 5000000000000000n,
        //   gammaS: 1n,
        //   gammaM: 900000000000000n,
        //   omegaM: 200000000000000n,
        //   priceFactor: 2n,
        //   sellDelayMs: 300000n
        // }
            
        seed_pool::new<SUI, BODEN>(
            &mut registry,
            boden_coin_cap, // BODEN
            5000000000000000, // 0
            5000000000000000, // 0
            2,
            1,
            900000000000000,
            200000000000000,
            300000,
            ctx(scenario_mut)
        );

        next_tx(scenario_mut, bob);

        let token_policy = test::take_shared<TokenPolicy<BODEN>>(scenario_mut);
        let seed_pool = test::take_shared<SeedPool<SUI, BODEN>>(scenario_mut);
        let clock = clock::create_for_testing(ctx(scenario_mut));

        let meme_monies = vector[];

        let amt_raised = 995000000;
        let amt_bought = 893497562500000;
        let admin_fee_in = 5000000;
        let admin_fee_out = 4489937500000;

        // assert!(amt_bought + admin_fee_out == 900000000000000, 0);
        assert_eq(amt_raised + admin_fee_in, mist(1));

        let meme_tokens_in_pool = (default_gamma_m() as u64);

        next_tx(scenario_mut, bob);

        let amt = sui(1);
        let sui_mony = coin::mint_for_testing<SUI>(amt, ctx(scenario_mut));

        assert_eq(seed_pool::balance_s<SUI, BODEN>(&seed_pool), 0);

        let staked_sboden = seed_pool::buy_meme<SUI, BODEN>(
            &mut seed_pool,
            &mut sui_mony,
            0,
            &clock,
            ctx(scenario_mut),
        );
        meme_tokens_in_pool = meme_tokens_in_pool - staked_lp::balance(&staked_sboden);
            
        assert_eq(seed_pool::balance_s<SUI, BODEN>(&seed_pool), amt_raised);
        assert_eq(seed_pool::balance_m<SUI, BODEN>(&seed_pool) + seed_pool::admin_balance_m<SUI, BODEN>(&seed_pool), meme_tokens_in_pool);

        vector::push_back(&mut meme_monies, staked_lp::balance(&staked_sboden));

        coin::burn_for_testing(sui_mony);
        staked_lp::destroy_for_testing(staked_sboden);

        seed_pool::unlock_for_testing<SUI, BODEN>(&mut seed_pool);

        clock::destroy_for_testing(clock);
        test::return_shared(seed_pool);
        test::return_shared(token_policy);
        test::return_shared(registry);
        test::end(scenario);
    }
    
    #[test]
    fun go_live() {
        let (scenario, alice, _, admin) = start_test_();
        let scenario_mut = &mut scenario;

        next_tx(scenario_mut, alice);
        {
            boden::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);

        let registry = test::take_shared<Registry>(scenario_mut);
        let boden_coin_cap = test::take_from_sender<TreasuryCap<BODEN>>(scenario_mut);
        let boden_metadata = test::take_shared<CoinMetadata<BODEN>>(scenario_mut);
        let clock = clock::create_for_testing(ctx(scenario_mut));


        let (pool, token_m) = seed_pool::new_full_for_testing<SUI, BODEN>(
            &mut registry,
            boden_coin_cap, // BODEN
            ctx(scenario_mut)
        );

        let (lp_treasury, lp_meta) = lp_coin::new(ctx(scenario_mut));
        let sui_meta = sui::new(ctx(scenario_mut));

        
        go_live::go_live_default_test<BODEN, LP_COIN>(
            &admin,
            pool,
            &sui_meta,
            &boden_metadata,
            &lp_meta,
            lp_treasury,
            &clock,
            ctx(scenario_mut),
        );

        admin::burn_for_testing(admin);
        token::burn_for_testing(token_m);
        clock::destroy_for_testing(clock);
        transfer::public_transfer(sui_meta, @0x0);
        transfer::public_transfer(lp_meta, @0x0);
        test::return_shared(boden_metadata);
        test::return_shared(registry);
        test::end(scenario);
    }

    #[test]
    fun go_live_and_trade() {
        let (scenario, alice, _, admin) = start_test_();
        let scenario_mut = &mut scenario;
        
        // Initiate S joe boden token
        next_tx(scenario_mut, alice);
        {
            boden::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);

        let registry = test::take_shared<Registry>(scenario_mut);
        let boden_coin_cap = test::take_from_sender<TreasuryCap<BODEN>>(scenario_mut);
        let boden_metadata = test::take_shared<CoinMetadata<BODEN>>(scenario_mut);
        let clock = clock::create_for_testing(ctx(scenario_mut));

        let (pool, token_m) = seed_pool::new_full_for_testing<SUI, BODEN>(
            &mut registry,
            boden_coin_cap, // BODEN
            ctx(scenario_mut)
        );

        let (lp_treasury, lp_meta) = lp_coin::new(ctx(scenario_mut));
        let sui_meta = sui::new(ctx(scenario_mut));

        go_live::go_live_default_test<BODEN, LP_COIN>(
            &admin,
            pool,
            &sui_meta,
            &boden_metadata,
            &lp_meta,
            lp_treasury,
            &clock,
            ctx(scenario_mut),
        );

        // Trade
        next_tx(scenario_mut, alice);
        let clamm_pool = test::take_shared<InterestPool<Volatile>>(scenario_mut);

        let output = volatile::swap<SUI, BODEN, LP_COIN>(
            &mut clamm_pool,
            &clock,
            coin::mint_for_testing<SUI>(mist(10), ctx(scenario_mut)),
            1,
            ctx(scenario_mut),
        );

        admin::burn_for_testing(admin);
        coin::burn_for_testing(output);
        clock::destroy_for_testing(clock);
        token::burn_for_testing(token_m);
        transfer::public_transfer(sui_meta, @0x0);
        transfer::public_transfer(lp_meta, @0x0);
        test::return_shared(clamm_pool);
        test::return_shared(boden_metadata);
        test::return_shared(registry);
        test::end(scenario);
    }

    #[test]
    fun go_live_trade_and_collect_fees() {
        let (scenario, alice, _, admin) = start_test_();
        let scenario_mut = &mut scenario;
        
        // Initiate S joe boden token
        next_tx(scenario_mut, alice);
        {
            boden::init_for_testing(ctx(scenario_mut));
        };

        next_tx(scenario_mut, alice);

        let registry = test::take_shared<Registry>(scenario_mut);
        let boden_coin_cap = test::take_from_sender<TreasuryCap<BODEN>>(scenario_mut);
        let boden_metadata = test::take_shared<CoinMetadata<BODEN>>(scenario_mut);
        let clock = clock::create_for_testing(ctx(scenario_mut));

        let (pool, m_token) = seed_pool::new_full_for_testing<SUI, BODEN>(
            &mut registry,
            boden_coin_cap, // BODEN
            ctx(scenario_mut)
        );

        let (lp_treasury, lp_meta) = lp_coin::new(ctx(scenario_mut));
        let sui_meta = sui::new(ctx(scenario_mut));

        go_live::go_live_default_test<BODEN, LP_COIN>(
            &admin,
            pool,
            &sui_meta,
            &boden_metadata,
            &lp_meta,
            lp_treasury,
            &clock,
            ctx(scenario_mut),
        );

        // Trade
        next_tx(scenario_mut, alice);
        let clamm_pool = test::take_shared<InterestPool<Volatile>>(scenario_mut);

        let output = volatile::swap<SUI, BODEN, LP_COIN>(
            &mut clamm_pool,
            &clock,
            coin::mint_for_testing<SUI>(mist(10_000), ctx(scenario_mut)),
            1,
            ctx(scenario_mut),
        );

        next_tx(scenario_mut, alice);
        let staking_pool = test::take_shared<StakingPool<SUI, BODEN, LP_COIN>>(scenario_mut);

        staking_pool::collect_fees<SUI, BODEN, LP_COIN>(
            &mut staking_pool,
            &mut clamm_pool,
            &clock,
            ctx(scenario_mut),
        );

        let (coin_s, coin_m) = staking_pool::withdraw_fees<SUI, BODEN, LP_COIN>(
            &mut staking_pool,
            ctx(scenario_mut),
        );

        // TODO: More fee tests with unstaking

        token::burn_for_testing(m_token);
        admin::burn_for_testing(admin);
        coin::burn_for_testing(coin_s);
        coin::burn_for_testing(coin_m);
        coin::burn_for_testing(output);
        clock::destroy_for_testing(clock);
        transfer::public_transfer(sui_meta, @0x0);
        transfer::public_transfer(lp_meta, @0x0);
        test::return_shared(staking_pool);
        test::return_shared(clamm_pool);
        test::return_shared(boden_metadata);
        test::return_shared(registry);
        test::end(scenario);
    }
    
    fun start_test(): (Scenario, address, address) {
        let scenario = scenario();
        let (alice, bob) = people();

        let scenario_mut = &mut scenario;

        deploy_coins(scenario_mut);

        next_tx(scenario_mut, alice);
        admin::init_for_testing(ctx(scenario_mut));
        index::init_for_testing(ctx(scenario_mut));

        (scenario, alice, bob, )
    }
    
    fun start_test_(): (Scenario, address, address, Admin) {
        let scenario = scenario();
        let (alice, bob) = people();

        let scenario_mut = &mut scenario;

        deploy_coins(scenario_mut);

        next_tx(scenario_mut, alice);
        index::init_for_testing(ctx(scenario_mut));
        let admin = admin::new_for_testing(ctx(scenario_mut));

        (scenario, alice, bob, admin)
    }
}