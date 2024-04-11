module turbos_clmm::pool_factory {
	use std::type_name::TypeName;
    use sui::vec_map::VecMap;
    use sui::object::{UID, ID};
    use sui::tx_context::TxContext;
	use sui::coin::{Coin};
	use turbos_clmm::position_manager::Positions;
    use turbos_clmm::fee::Fee;
	use sui::clock::{Clock};
	use turbos_clmm::pool::Versioned;
	use std::string::String;
	use sui::table::Table;
    
	struct PoolFactoryAdminCap has key, store { id: UID }

	struct PoolSimpleInfo has copy, store {
        pool_id: ID,
		pool_key: ID,
        coin_type_a: TypeName,
		coin_type_b: TypeName,
		fee_type: TypeName,
		fee: u32,
        tick_spacing: u32,
    }

    struct PoolConfig has key, store {
        id: UID,
        fee_map: VecMap<String, ID>,
		fee_protocol: u32,
		pools: Table<ID, PoolSimpleInfo>,
    }

	public entry fun deploy_pool_and_mint<CoinTypeA, CoinTypeB, FeeType>(
		pool_config: &mut PoolConfig,
		feeType: &Fee<FeeType>,
		sqrt_price: u128,
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

    public entry fun deploy_pool<CoinTypeA, CoinTypeB, FeeType>(
		pool_config: &mut PoolConfig,
		feeType: &Fee<FeeType>,
		sqrt_price: u128,
		clock: &Clock,
		versioned: &Versioned,
		ctx: &mut TxContext
    ) {
		abort(0)
    }
}