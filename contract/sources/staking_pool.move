module memechan::staking_pool {
    use std::type_name::{Self, TypeName};
    use sui::object::{Self, ID, UID};
    use sui::table::{Self, Table};
    use sui::balance::Balance;
    use sui::tx_context::{Self, TxContext};


    use memechan::vesting::{Self, VestingData, VestingConfig};

    struct StakingPool<T: key, LP: key> has key {
        id: UID,
        amm_pool: ID,
        balances: Table<address, Balance<T>>,
        vesting_data: Table<address, VestingData>,
        vesting_config: VestingConfig,
    }

    public(friend) fun new<T: key>(
        balances: Table<address, Balance<T>>,
        vesting_config: VestingConfig,
        ctx: &mut TxContext,
    ): StakingPool<T> {
        StakingPool {
            id: object::new(ctx),
            amm_pool,
            balances,
            vesting_data: table::new(ctx),
            vesting_config
        }
    }

}