module amm::index {
    use std::type_name::{Self, TypeName};
    use sui::object::{Self, UID, ID};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::TxContext;

    // TODO: Unify registry
    struct PoolIndex has key {
        id: UID,
        amm_pools: Table<Pair, ID>,
        // AmmPool ID --> Staking Pool ID
        staking_pools: Table<ID, ID>,
    }

    struct Pair has store, drop, copy {
        coin_a: TypeName,
        coin_b: TypeName,
    }

    public fun init_memechain(ctx: &mut TxContext) {
        let index = PoolIndex {
            id: object::new(ctx),
            amm_pools: table::new(ctx),
            staking_pools: table::new(ctx),
        };

        transfer::share_object(index);
    }

    public fun get_amm_pool_id<A, B>(self: &PoolIndex): &ID {
        let pair = Pair {
            coin_a: type_name::get<A>(),
            coin_b: type_name::get<B>(),
        };
        table::borrow(&self.amm_pools, pair)
    }

    public fun amm_pools(self: &PoolIndex): &Table<Pair, ID> {
        &self.amm_pools
    }
}