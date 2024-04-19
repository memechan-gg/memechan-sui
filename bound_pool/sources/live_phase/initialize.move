#[allow(lint(share_owned))]
module amm::initialize {
    use sui::transfer;
    use sui::balance;
    use sui::sui::SUI;
    use sui::tx_context::TxContext;
    use sui::clock::Clock;
    use sui::coin::{Self, TreasuryCap, CoinMetadata};

    use amm::vesting;
    use amm::math::div_mul;
    use clamm::interest_clamm_volatile as volatile;
    use amm::bound_curve_amm::{Self as seed_pool, InterestPool as SeedPool};
    use amm::staking_pool;
    use suitears::coin_decimals;
    use suitears::math256::mul_div_up;

    const ADMIN_ADDR: address = @0xfff; // TODO

    const SUI_THRESHOLD: u64 = 30_000;
    const BPS: u64 = 10_000;
    const LOCKED: u64 = 8_000;
    
    const A: u256 = 400_000;
    const GAMMA: u256 = 145_000_000_000_000;

    const ALLOWED_EXTRA_PROFIT: u256 = 2000000000000; // 18 decimals
    const ADJUSTMENT_STEP: u256 = 146000000000000; // 18 decimals
    const MA_TIME: u256 = 600_000; // 10 minutes

    const MID_FEE: u256 = 260_000_000_000_000_000; // (0.26%) swap fee when the pool is balanced
    const OUT_FEE: u256 = 450_000_000_000_000_000; // (0.45%) swap fee when the pool is out balance
    const GAMMA_FEE: u256 = 200_000_000_000_000; //  (0.0002%) speed rate that fee increases mid_fee => out_fee

    /// The amount of Mist per Sui token based on the fact that mist is
    /// 10^-9 of a Sui token
    const MIST_PER_SUI: u64 = 1_000_000_000;

    const LAUNCH_FEE: u256 =   50_000_000_000_000_000; // 5%
    const PRECISION: u256 = 1_000_000_000_000_000_000;

    public fun sui(mist: u64): u64 { MIST_PER_SUI * mist }

    public fun init_secondary_market<CoinX: key, Meme: key, LP: key>(
        seed_pool: SeedPool,
        sui_meta: &CoinMetadata<SUI>,
        meme_meta: &CoinMetadata<Meme>,
        treasury_cap: TreasuryCap<LP>,
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
            locked,
            fields,
        ) = seed_pool::destroy_pool<CoinX, SUI, Meme>(seed_pool);

        assert!(locked, 0);
        assert!(balance::value(&xmeme_balance) == 0, 0);
        balance::destroy_zero(xmeme_balance);
        
        // 0. Transfer admin funds to admin
        transfer::public_transfer(coin::from_balance(admin_xmeme_balance, ctx), ADMIN_ADDR);
        transfer::public_transfer(coin::from_balance(admin_sui_balance, ctx), ADMIN_ADDR);

        // 1. Verify if we reached the threshold of SUI amount raised
        let sui_supply = balance::value(&sui_balance);
        assert!(sui_supply == sui(SUI_THRESHOLD), 0);

        // 2. Collect live fees
        let live_fee_amt = (mul_div_up((sui_supply as u256), LAUNCH_FEE, PRECISION) as u64);
        transfer::public_transfer(coin::from_balance(balance::split(&mut sui_balance, live_fee_amt), ctx), ADMIN_ADDR);

        // 3. Split MEME balance amounts into 80/20
        let meme_supply = balance::value(&meme_balance);
        let meme_supply_80 = div_mul(meme_supply, BPS, LOCKED);

        let amm_meme_balance = balance::split(&mut meme_balance, meme_supply_80);
        let decimals = coin_decimals::new(ctx);

        coin_decimals::add(&mut decimals, sui_meta);
        coin_decimals::add(&mut decimals, meme_meta);

        // 4. Create AMM Pool
        let (lp_tokens, pool_id) = volatile::new_2_pool(
            clock,
            coin::from_balance(sui_balance, ctx), // coin_a
            coin::from_balance(amm_meme_balance, ctx), // coin_b
            &decimals,
            coin::treasury_into_supply(treasury_cap),
            vector[A, GAMMA],
            vector[ALLOWED_EXTRA_PROFIT, ADJUSTMENT_STEP, MA_TIME],
            100, // price todo
            vector[MID_FEE, OUT_FEE, GAMMA_FEE],
            ctx
        );

        // 5. Create staking pool
        let staking_pool = staking_pool::new<CoinX, Meme, LP>(
            pool_id,
            meme_balance,
            coin::into_balance(lp_tokens),
            vesting::default_config(clock),
            fields,
            ctx,
        );

        transfer::public_share_object(staking_pool);

        // Cleanup
        coin_decimals::destroy_decimals(coin_decimals::remove<SUI>(&mut decimals));
        coin_decimals::destroy_decimals(coin_decimals::remove<Meme>(&mut decimals));

        coin_decimals::destroy_coin_decimals(decimals);
    }
}