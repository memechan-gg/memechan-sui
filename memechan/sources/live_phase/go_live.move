#[allow(lint(share_owned, self_transfer))]
module memechan::go_live {
    use std::string;
    use sui::transfer;
    use sui::balance;
    use sui::clock;
    use sui::object;
    use sui::sui::SUI;
    use sui::tx_context::{TxContext, sender};
    use sui::clock::Clock;
    use sui::coin::{Self, TreasuryCap, CoinMetadata};

    use memechan::vesting::{Self, VestingConfig};
    use memechan::events;
    use memechan::admin::Admin;
    use memechan::math::div_mul;
    use memechan::seed_pool::{Self as seed_pool, SeedPool, gamma_s};
    use memechan::staking_pool;
    use clamm::interest_pool;
    use clamm::interest_clamm_volatile as volatile_hooks;
    use suitears::coin_decimals;
    use suitears::owner;
    use memechan::utils::mist;
    use suitears::math256::mul_div_up;

    struct AddLiquidityHook has drop {}

    const SCALE: u256 = 1_000_000_000_000_000_000; // 1e18

    const BPS: u64 = 10_000;
    const LOCKED: u64 = 8_000;
    
    const A: u256 = 400_000;
    const GAMMA: u256 = 145_000_000_000_000;

    const ALLOWED_EXTRA_PROFIT: u256 = 2000000000000; // 18 decimals
    const ADJUSTMENT_STEP: u256 = 146000000000000; // 18 decimals
    const MA_TIME: u256 = 600_000; // 10 minutes

    const MID_FEE: u256 = 26000000; // (0.26%) swap fee when the pool is balanced
    const OUT_FEE: u256 = 45000000; // (0.45%) swap fee when the pool is out balance
    const GAMMA_FEE: u256 = 200_000_000_000_000; //  (0.0002%) speed rate that fee increases mid_fee => out_fee

    // const MID_FEE: u256 = 260_000_000_000_000_000; // (0.26%) swap fee when the pool is balanced
    // const OUT_FEE: u256 = 450_000_000_000_000_000; // (0.45%) swap fee when the pool is out balance

    const LAUNCH_FEE: u256 =   50_000_000_000_000_000; // 5%
    const PRECISION: u256 = 1_000_000_000_000_000_000;

    // Admin endpoint
    public fun go_live_default<M, Meme, LP>(
        admin_cap: &Admin,
        seed_pool: SeedPool,
        sui_meta: &CoinMetadata<SUI>,
        meme_meta: &CoinMetadata<Meme>,
        lp_meta: &CoinMetadata<LP>,
        treasury_cap: TreasuryCap<LP>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let vesting_config = vesting::default_config(clock);

        go_live_<M, Meme, LP, SUI>(
            admin_cap,
            seed_pool,
            sui_meta,
            meme_meta,
            lp_meta,
            treasury_cap,
            vesting_config,
            clock,
            ctx,
        );
    }

    // Admin endpoint
    public fun go_live<M, Meme, LP>(
        admin_cap: &Admin,
        seed_pool: SeedPool,
        sui_meta: &CoinMetadata<SUI>,
        meme_meta: &CoinMetadata<Meme>,
        lp_meta: &CoinMetadata<LP>,
        treasury_cap: TreasuryCap<LP>,
        cliff_delta: u64,
        end_vesting_delta: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let current_ts = clock::timestamp_ms(clock);

        let vesting_config = vesting::new_config(
            current_ts,
            current_ts + cliff_delta,
            current_ts + end_vesting_delta,
        );

        go_live_<M, Meme, LP, SUI>(
            admin_cap,
            seed_pool,
            sui_meta,
            meme_meta,
            lp_meta,
            treasury_cap,
            vesting_config,
            clock,
            ctx,
        );
    }
    
    // Admin endpoint
    public fun go_live_<M, Meme, LP, SUI>(
        _admin_cap: &Admin,
        seed_pool: SeedPool,
        sui_meta: &CoinMetadata<SUI>,
        meme_meta: &CoinMetadata<Meme>,
        lp_meta: &CoinMetadata<LP>,
        treasury_cap: TreasuryCap<LP>,
        vesting_config: VestingConfig,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let (
            xmeme_balance,
            sui_balance,
            admin_xmeme_balance,
            admin_sui_balance,
            meme_balance,
            _,
            params,
            locked,
            fields,
        ) = seed_pool::destroy_pool<M, SUI, Meme>(seed_pool);

        assert!(locked, 0);
        assert!(balance::value(&xmeme_balance) == 0, 0);
        balance::destroy_zero(xmeme_balance);
        
        // 0. Transfer admin funds to admin
        transfer::public_transfer(coin::from_balance(admin_xmeme_balance, ctx), sender(ctx));
        transfer::public_transfer(coin::from_balance(admin_sui_balance, ctx), sender(ctx));

        // 1. Verify if we reached the threshold of SUI amount raised
        let sui_supply = balance::value(&sui_balance);
        
        assert!(sui_supply == mist(gamma_s(&params)), 0);

        // 2. Collect live fees
        let live_fee_amt = (mul_div_up((sui_supply as u256), LAUNCH_FEE, PRECISION) as u64);
        transfer::public_transfer(coin::from_balance(balance::split(&mut sui_balance, live_fee_amt), ctx), sender(ctx));

        // 3. Split MEME balance amounts into 80/20
        let meme_supply = balance::value(&meme_balance);
        let meme_supply_80 = div_mul(meme_supply, BPS, LOCKED);

        let amm_meme_balance = balance::split(&mut meme_balance, meme_supply_80);
        
        let decimals_cap = coin_decimals::new_cap(ctx);
        let decimals = coin_decimals::new(&mut decimals_cap, ctx);

        coin_decimals::add(&mut decimals, sui_meta);
        coin_decimals::add(&mut decimals, meme_meta);
        coin_decimals::add(&mut decimals, lp_meta);

        // 3. Create AMM Pool
        let hooks_builder = interest_pool::new_hooks_builder(ctx);

        interest_pool::add_rule<AddLiquidityHook>(
            &mut hooks_builder,
            string::utf8(interest_pool::start_add_liquidity_name()),
            AddLiquidityHook {},
        );

        let amount_sui = (balance::value(&sui_balance) as u256);
        let amount_meme = (balance::value(&amm_meme_balance) as u256);

        let price = (amount_sui * SCALE) / amount_meme;

        let (amm_pool, admin, lp_tokens) = volatile_hooks::new_2_pool_with_hooks(
            clock,
            &decimals,
            hooks_builder,
            coin::from_balance(sui_balance, ctx), // coin_a
            coin::from_balance(amm_meme_balance, ctx), // coin_b
            coin::treasury_into_supply(treasury_cap),
            vector[A, GAMMA],
            vector[ALLOWED_EXTRA_PROFIT, ADJUSTMENT_STEP, MA_TIME],
            price,
            vector[MID_FEE, OUT_FEE, GAMMA_FEE],
            ctx
        );

        let pool_id = object::id(&amm_pool);

        // 4. Create staking pool
        let staking_pool = staking_pool::new<M, SUI, Meme, LP>(
            pool_id,
            meme_balance,
            coin::into_balance(lp_tokens),
            vesting_config,
            admin,
            fields,
            ctx,
        );

        events::go_live<Meme, SUI, LP>(
            object::id_to_address(&object::id(&amm_pool)),
            object::id_to_address(&object::id(&staking_pool))
        );

        interest_pool::share(amm_pool);
        transfer::public_share_object(staking_pool);

        // Cleanup
        coin_decimals::remove_and_destroy<SUI>(&mut decimals, &decimals_cap);
        coin_decimals::remove_and_destroy<Meme>(&mut decimals, &decimals_cap);

        coin_decimals::destroy(decimals, &decimals_cap);
        owner::destroy(decimals_cap);
    }

    // === Test Functions ===

    #[test_only]
    use memechan::sui::{SUI as MockSUI};

    #[test_only]
    public fun go_live_default_test<M, Meme, LP>(
        admin_cap: &Admin,
        seed_pool: SeedPool,
        sui_meta: &CoinMetadata<MockSUI>,
        meme_meta: &CoinMetadata<Meme>,
        lp_meta: &CoinMetadata<LP>,
        treasury_cap: TreasuryCap<LP>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let vesting_config = vesting::default_config(clock);

        go_live_<M, Meme, LP, MockSUI>(
            admin_cap,
            seed_pool,
            sui_meta,
            meme_meta,
            lp_meta,
            treasury_cap,
            vesting_config,
            clock,
            ctx,
        );
    }
}