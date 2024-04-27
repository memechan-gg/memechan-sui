#[test_only]
module memechan::deploy_utils {
    use std::option;
    use sui::coin::{mint_for_testing, TreasuryCap, CoinMetadata, create_treasury_cap_for_testing};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use sui::object;
    use sui::token;
    use sui::sui::SUI;

    use memechan::btc;
    use memechan::usdt;
    use memechan::usdc::{Self, USDC};
    use memechan::ticket_usdc::{Self, TICKET_USDC};
    use memechan::bound_curve_amm::{Self, SeedPool};
    use memechan::index::{Self, Registry};

    public fun sui(amt: u64): u64 {
        amt * 1_000_000_000
    }

    public fun deploy_coins(test: &mut Scenario) {
        let (alice, _) = people();

        next_tx(test, alice);
        {
            btc::init_for_testing(ctx(test));
            usdc::init_for_testing(ctx(test));
            usdt::init_for_testing(ctx(test));
        };
    }

    public fun deploy_usdc_sui_pool(test: &mut Scenario, sui_amount: u64, usdc_amount: u64) {
        let (alice, _) = people();

        deploy_usdc_sui_pool_default_liquidity(test);

        next_tx(test, alice);
        {
            let registry = test::take_shared<Registry>(test);
            let pool_address = index::seed_pool_address<TICKET_USDC, SUI, USDC>(&registry);
            let pool = test::take_shared_by_id<SeedPool>(test, object::id_from_address(option::destroy_some(pool_address)) );
            bound_curve_amm::set_liquidity<TICKET_USDC, SUI, USDC>(&mut pool, token::mint_for_testing<TICKET_USDC>(usdc_amount, ctx(test)), mint_for_testing<SUI>(sui_amount, ctx(test)));
            test::return_shared(pool);
            test::return_shared(registry);
        }
    }

    public fun deploy_usdc_sui_pool_default_liquidity(test: &mut Scenario) {
        let (alice, _) = people();

        deploy_coins(test);

        next_tx(test, alice);
        {
            ticket_usdc::init_for_testing(ctx(test));
        };

        next_tx(test, alice);
        {
            let registry = test::take_shared<Registry>(test);
            let lp_coin_cap = test::take_from_sender<TreasuryCap<TICKET_USDC>>(test);
            let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
            let lp_coin_metadata = test::take_shared<CoinMetadata<TICKET_USDC>>(test);
            
            bound_curve_amm::new_default<TICKET_USDC, SUI, USDC>(
                &mut registry,
                lp_coin_cap,
                create_treasury_cap_for_testing(ctx(test)),
                &mut lp_coin_metadata,
                &usdc_metadata,
                ctx(test)
            );

            test::return_shared(usdc_metadata);
            test::return_shared(lp_coin_metadata);
            test::return_shared(registry);
        };
    }

    public fun scenario(): Scenario { test::begin(@0x1) }

    public fun people():(address, address) { (@0xA11ce, @0xB0B)}

    public fun people5():(address, address, address, address, address) { (@0xA11ce, @0xB0B, @0x1337, @0xDEAD, @0xBEEF)}
}