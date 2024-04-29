module memechan::index {
    use std::option::{Self, Option};
    use std::type_name::{Self, TypeName};

    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::TxContext;
    use sui::transfer::share_object;

    use memechan::errors;

    friend memechan::go_live;
    friend memechan::seed_pool;

    // === Structs ===

    struct Registry has key {
        id: UID,
        seed_pools: Table<TypeName, address>,
        staking_pools: Table<TypeName, address>,
        interest_pools: Table<TypeName, address>,
        policies: Table<TypeName, address>
    }

    // struct RegistryV2 has key {
    //     id: UID,
    //     list: Table<TypeName, MemeData>,
    // }

    // struct MemeData has store, copy {
    //     seed_pool: address,
    //     staking_pool: Option<address>,
    //     interest_pools: Option<address>,
    //     policy: Option<address>,
    // }

    struct RegistryKey<phantom M, phantom S, phantom Meme> has drop {}

    #[allow(unused_function)]
    fun init(ctx: &mut TxContext) {
        share_object(
            Registry {
                id: object::new(ctx),
                seed_pools: table::new(ctx),
                staking_pools: table::new(ctx),
                interest_pools: table::new(ctx),
                policies: table::new(ctx),
            }
        );
    }

    public fun seed_pools(registry: &Registry): &Table<TypeName, address> {
        &registry.seed_pools
    }

    public fun seed_pool_address<M, S, Meme>(registry: &Registry): Option<address> {
        let registry_key = type_name::get<RegistryKey<M, S, Meme>>();

        if (table::contains(&registry.seed_pools, registry_key))
            option::some(*table::borrow(&registry.seed_pools, registry_key))
        else
            option::none()
    }
    
    public fun staking_pool_address<M, S, Meme>(registry: &Registry): Option<address> {
        let registry_key = type_name::get<RegistryKey<M, S, Meme>>();

        if (table::contains(&registry.staking_pools, registry_key))
            option::some(*table::borrow(&registry.staking_pools, registry_key))
        else
            option::none()
    }
    
    public fun interest_pool_address<M, S, Meme>(registry: &Registry): Option<address> {
        let registry_key = type_name::get<RegistryKey<M, S, Meme>>();

        if (table::contains(&registry.interest_pools, registry_key))
            option::some(*table::borrow(&registry.interest_pools, registry_key))
        else
            option::none()
    }
    
    public fun policy_address<M, S, Meme>(registry: &Registry): Option<address> {
        let registry_key = type_name::get<RegistryKey<M, S, Meme>>();

        if (table::contains(&registry.policies, registry_key))
            option::some(*table::borrow(&registry.policies, registry_key))
        else
            option::none()
    }

    public fun get_policy_id<T>(registry: &Registry): address {
            let type_name = type_name::get<T>();
            *table::borrow(&registry.policies, type_name)
    }

    public fun exists_seed_pool<M, S, Meme>(registry: &Registry): bool {
        table::contains(&registry.seed_pools, type_name::get<RegistryKey<M, S, Meme>>())
    }
    
    public fun add_seed_pool<M, S, Meme>(registry: &mut Registry, pool_address: address) {
        table::add(seed_pools_mut(registry), type_name::get<RegistryKey<M, S, Meme>>(), pool_address);
    }
    
    public fun assert_new_pool<M, S, Meme>(registry: &Registry) {
        let registry_key = type_name::get<RegistryKey<M, S, Meme>>();
        assert!(!table::contains(&registry.seed_pools, registry_key), errors::pool_already_deployed());
    }

    public(friend) fun seed_pools_mut(self: &mut Registry): &mut Table<TypeName, address> {
        &mut self.seed_pools
    }
    
    public(friend) fun policies_mut(self: &mut Registry): &mut Table<TypeName, address> {
        &mut self.policies
    }

    // === Test Functions ===
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}