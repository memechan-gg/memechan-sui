#[test_only]
module amm::deploy_utils {

  use std::option;
  use sui::coin::{mint_for_testing, TreasuryCap, CoinMetadata, create_treasury_cap_for_testing};
  use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
  use sui::object;

  use amm::btc;
  use amm::usdt;
  use amm::sui::{Self, SUI};
  use amm::usdc::{Self, USDC};
  use amm::curves::Bound;
  use amm::ipx_b_usdc_sui::{Self, IPX_B_USDC_SUI};
  use amm::interest_protocol_amm::{Self, InterestPool, Registry};

  public fun deploy_coins(test: &mut Scenario) {
    let (alice, _) = people();

    next_tx(test, alice);
    {
      btc::init_for_testing(ctx(test));
      sui::init_for_testing(ctx(test));
      usdc::init_for_testing(ctx(test));
      usdt::init_for_testing(ctx(test));
    };
  }

  public fun deploy_usdc_sui_pool(test: &mut Scenario, sui_amount: u64, usdc_amount: u64) {
    let (alice, _) = people();

    deploy_coins(test);

    next_tx(test, alice);
    {
      ipx_b_usdc_sui::init_for_testing(ctx(test));
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let lp_coin_cap = test::take_from_sender<TreasuryCap<IPX_B_USDC_SUI>>(test);
      let sui_metadata = test::take_shared<CoinMetadata<SUI>>(test);
      let usdc_metadata = test::take_shared<CoinMetadata<USDC>>(test);
      let lp_coin_metadata = test::take_shared<CoinMetadata<IPX_B_USDC_SUI>>(test);
      
      interest_protocol_amm::new(
        &mut registry,
        create_treasury_cap_for_testing(ctx(test)),
        //mint_for_testing<USDC>(usdc_amount, ctx(test)),
        lp_coin_cap,
        &usdc_metadata,
        &sui_metadata,
        &mut lp_coin_metadata,
        ctx(test)
      );

      //   let pool_address = interest_protocol_amm::pool_address<Bound, USDC, SUI>(&registry);
      //   let pool = test::take_shared_by_id<InterestPool>(
      //   test, object::id_from_address(option::destroy_some(pool_address))
      // );


      
      //let pool_state = interest_protocol_amm::pool_state_mut<CoinX, CoinY, LpCoin>(&mut pool);

      

      //interest_protocol_amm::swap_coin_y(pool, mint_for_testing<SUI>(sui_amount, ctx(test)), 0, clock, ctx(test));

      test::return_shared(sui_metadata);
      test::return_shared(usdc_metadata);
      test::return_shared(lp_coin_metadata);
      test::return_shared(registry);
    };

    next_tx(test, alice);
    {
      let registry = test::take_shared<Registry>(test);
      let pool_address = interest_protocol_amm::pool_address<Bound, USDC, SUI>(&registry);
      let pool = test::take_shared_by_id<InterestPool>(test, object::id_from_address(option::destroy_some(pool_address)) );
      interest_protocol_amm::set_liquidity<USDC, SUI, IPX_B_USDC_SUI>(&mut pool, mint_for_testing<USDC>(usdc_amount, ctx(test)),mint_for_testing<SUI>(sui_amount, ctx(test)));
      test::return_shared(pool);
      test::return_shared(registry);
    }
  }

  public fun scenario(): Scenario { test::begin(@0x1) }

  public fun people():(address, address) { (@0xBEEF, @0x1337)}
}