module memechan::fields {
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};
    use sui::dynamic_field as df;

    friend memechan::go_live;
    friend memechan::seed_pool;
    friend memechan::staking_pool;

    // === Structs ===

    struct FieldsDfKey has copy, store, drop {}
    
    struct Fields has key, store {
        id: UID,
    }

    public(friend) fun init_fields(
        uid: &mut UID,
        ctx: &mut TxContext,
    ) {
        df::add(uid, FieldsDfKey {}, Fields { id: object::new(ctx) });
    }
    
    public(friend) fun fields(
        uid: &UID,
    ): &UID {
        let fields: &Fields = df::borrow(uid, FieldsDfKey {});

        &fields.id
    }
    
    public(friend) fun fields_mut(
        uid: &mut UID,
    ): &mut UID {
        let fields: &mut Fields = df::borrow_mut(uid, FieldsDfKey {});

        &mut fields.id
    }
    
    public(friend) fun insert_fields(
        uid: &mut UID,
        fields: Fields,
    ) {
        df::add(uid, FieldsDfKey {}, fields);
    }
    
    public(friend) fun pop_fields(
        uid: &mut UID,
    ): Fields {
        df::remove(uid, FieldsDfKey {})
    }
}