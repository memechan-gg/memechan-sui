module memechan::events {
    use sui::event::emit;

    friend memechan::bound_curve_amm;
    friend memechan::token_ir;

    struct NewPool<phantom M, phantom S, phantom Meme> has copy, drop {
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        policy_address: address,
    }

    struct Swap<phantom CoinIn, phantom CoinOut, T: drop + copy + store> has copy, drop {
        pool_address: address,
        amount_in: u64,
        swap_amount: T
    }

    struct AddLiquidity<phantom M, phantom S> has copy, drop {
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64,
    }

    struct RemoveLiquidity<phantom M, phantom S> has copy, drop {
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64,
        fee_x_value: u64,
        fee_y_value: u64,
    }

    public(friend) fun new_pool<M, S, Meme>(
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        policy_address: address,
    ) {
        emit(NewPool<M, S, Meme>{ pool_address, amount_x, amount_y, policy_address });
    }

    public(friend) fun swap<CoinIn, CoinOut, T: copy + drop + store>(
        pool_address: address,
        amount_in: u64,
        swap_amount: T,
    ) {
        emit(Swap<CoinIn, CoinOut, T> { pool_address, amount_in, swap_amount });
    }

    public(friend) fun add_liquidity<M, S>(
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64,
    ) {
        emit(AddLiquidity<M, S> { pool_address, amount_x, amount_y, shares });
    }

    public(friend) fun remove_liquidity<M, S>(
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
        shares: u64,
        fee_x_value: u64,
        fee_y_value: u64,
    ) {
        emit(RemoveLiquidity<M, S> { pool_address, amount_x, amount_y, shares, fee_x_value, fee_y_value });
    }
}