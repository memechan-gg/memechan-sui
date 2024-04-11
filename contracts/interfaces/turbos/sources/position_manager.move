module turbos_clmm::position_manager {
    use std::string::String;
    use sui::object::{UID, ID};
    use sui::tx_context::TxContext;
	use sui::coin::{Coin};
    use sui::table::Table;
    use turbos_clmm::i32::I32;
    use turbos_clmm::pool::{Pool, PoolRewardVault, Versioned};
    use turbos_clmm::position_nft::TurbosPositionNFT;
    use sui::clock::Clock;
    
    struct PositionRewardInfo has store {
        reward_growth_inside: u128,
        amount_owed: u64,
    }

	struct Position has key, store {
        id: UID,
        tick_lower_index: I32,
        tick_upper_index: I32,
        liquidity: u128,
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
        tokens_owed_a: u64,
        tokens_owed_b: u64,
        reward_infos: vector<PositionRewardInfo>,
    }

	struct Positions has key, store {
        id: UID,
		nft_minted: u64,
        user_position: Table<address, ID>,
        nft_name: String,
        nft_description: String,
        nft_img_url: String,
    }

    struct IncreaseLiquidityEvent has copy, drop {
	    pool: ID,
	    amount_a: u64,
	    amount_b: u64,
	    liquidity: u128
    }

    struct DecreaseLiquidityEvent has copy, drop {
    	pool: ID,
    	amount_a: u64,
    	amount_b: u64,
    	liquidity: u128
    }

    struct CollectEvent has copy, drop {
    	pool: ID,
    	amount_a: u64,
    	amount_b: u64,
    	recipient: address
    }
    
    struct CollectRewardEvent has copy, drop {
    	pool: ID,
    	amount: u64,
    	vault: ID,
    	reward_index: u64,
    	recipient: address
    }

    public entry fun mint<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		coins_a: vector<Coin<CoinTypeA>>, 
		coins_b: vector<Coin<CoinTypeB>>, 
		tick_lower_index: u32,
		tick_lower_index_is_neg: bool,
        tick_upper_index: u32,
		tick_upper_index_is_neg: bool,
		amount_a_desired: u64,
        amount_b_desired: u64,
        amount_a_min: u64,
        amount_b_min: u64,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
		ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun burn<CoinTypeA, CoinTypeB, FeeType>(
        positions: &mut Positions,
        nft: TurbosPositionNFT,
        versioned: &Versioned,
        _ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun increase_liquidity<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		coins_a: vector<Coin<CoinTypeA>>, 
		coins_b: vector<Coin<CoinTypeB>>, 
		nft: &mut TurbosPositionNFT,
		amount_a_desired: u64,
        amount_b_desired: u64,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
		ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun decrease_liquidity<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		nft: &mut TurbosPositionNFT,
		liquidity: u128,
        amount_a_min: u64,
        amount_b_min: u64,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
		ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun collect<CoinTypeA, CoinTypeB, FeeType>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		nft: &mut TurbosPositionNFT,
        amount_a_max: u64,
        amount_b_max: u64,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
		ctx: &mut TxContext
    ) {
        abort(0)
    }

    public entry fun collect_reward<CoinTypeA, CoinTypeB, FeeType, RewardCoin>(
		pool: &mut Pool<CoinTypeA, CoinTypeB, FeeType>,
		positions: &mut Positions,
		nft: &mut TurbosPositionNFT,
        vault: &mut PoolRewardVault<RewardCoin>,
        reward_index: u64,
        amount_max: u64,
        recipient: address,
        deadline: u64,
        clock: &Clock,
        versioned: &Versioned,
		ctx: &mut TxContext
    ) {
        abort(0)
    }
}