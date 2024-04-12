module memechan::bonding {
    use std::type_name::{Self, TypeName};
    use sui::object::UID;
    use sui::table::{Self, Table};
    use sui::table_vec::{Self, TableVec};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::tx_context::TxContext;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, TreasuryCap, CoinMetadata, Coin};

    use memechan::vesting::{Self, VestingData, VestingConfig};
    use memechan::math::div_mul;
    use clamm::interest_clamm_volatile as volatile;
    use suitears::coin_decimals;

    const SUI_THRESHOLD: u64 = 69_000;
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


    public fun sui(mist: u64): u64 { MIST_PER_SUI * mist }

    struct BondingPool<MEME: key> has key {
        id: UID,
        sui_balance: Balance<SUI>,
        meme_balance: Balance<MEME>,
        shares: Table<address, u64>,
        addresses: TableVec<address>,
    }

    public fun init_secondary_market<MEME: key, LP: key>(
        seed_pool: BondingPool<MEME>,
        sui_meta: &CoinMetadata<SUI>,
        meme_meta: &CoinMetadata<MEME>,
        treasury_cap: TreasuryCap<LP>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let BondingPool {
            id,
            sui_balance,
            meme_balance,
            shares,
            addresses,
        } = seed_pool;

        // 1. Verify if we reached the threshold of SUI amount raised
        let sui_supply = balance::value(&meme_balance);
        assert!(sui_supply == sui(SUI_THRESHOLD), 0);

        // 2. Split MEME balance amounts into 80/20
        let meme_supply = balance::value(&meme_balance);
        let meme_supply_80 = div_mul(meme_supply, BPS, LOCKED);
        let meme_supply_20 = meme_supply - meme_supply_80;

        let amm_meme_balance = balance::split(&mut meme_balance, meme_supply_80);
        let decimals = coin_decimals::new(ctx);

        coin_decimals::add(&mut decimals, sui_meta);
        coin_decimals::add(&mut decimals, meme_meta);

        // 3. Create AMM Pool
        let lp_tokens = volatile::new_2_pool(
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

        // 4. Create staking pool



        // 2. Move 80% of MEME to staking Pool

        // 3. Create AMM pool 20% MEME and 100% SUI


    }

}