module memechan::bonding {
    use std::type_name::{Self, TypeName};
    use sui::object::UID;
    use sui::table::{Self, Table};
    use sui::balance::Balance;

    use memechan::vesting::{Self, VestingData, VestingConfig};

    struct StakingPool<T: key> has key {
        id: UID,
        balances: Table<address, Balance<T>>,
        vesting_data: Table<address, VestingData>,
        vesting_config: VestingConfig,
    }

}