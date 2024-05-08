module memechan::events {
    use std::type_name::{Self, TypeName};
    use sui::event::emit;

    friend memechan::seed_pool;
    friend memechan::token_ir;
    friend memechan::go_live;

    struct NewPool<phantom S, phantom Meme> has copy, drop {
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        policy_address: address,
    }
    
    struct GoLive< phantom S, phantom Meme> has copy, drop {
        clamm_address: address,
        staking_pool_address: address,
        lp_type: TypeName,
    }

    struct Swap<phantom CoinIn, phantom CoinOut, T: drop + copy + store> has copy, drop {
        pool_address: address,
        amount_in: u64,
        swap_amount: T
    }

    struct AddLiquidity<phantom S, phantom M> has copy, drop {
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64,
    }

    struct RemoveLiquidity<phantom S, phantom M> has copy, drop {
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64,
        fee_x_value: u64,
        fee_y_value: u64,
    }

    public(friend) fun new_pool<S, Meme>(
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        policy_address: address,
    ) {
        emit(NewPool<S, Meme>{ pool_address, amount_x, amount_y, policy_address });
    }
    
    public(friend) fun go_live<S, Meme, LP>(
        clamm_address: address,
        staking_pool_address: address,
    ) {
        emit(GoLive<S, Meme>{ clamm_address, staking_pool_address, lp_type: type_name::get<LP>() });
    }

    public(friend) fun swap<CoinIn, CoinOut, T: copy + drop + store>(
        pool_address: address,
        amount_in: u64,
        swap_amount: T,
    ) {
        emit(Swap<CoinIn, CoinOut, T> { pool_address, amount_in, swap_amount });
    }

    public(friend) fun add_liquidity<S, M>(
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64,
    ) {
        emit(AddLiquidity<S, M> { pool_address, amount_x, amount_y, shares });
    }

    public(friend) fun remove_liquidity<S, M>(
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64,
        fee_x_value: u64,
        fee_y_value: u64,
    ) {
        emit(RemoveLiquidity<S, M> { pool_address, amount_x, amount_y, shares, fee_x_value, fee_y_value });
    }
}