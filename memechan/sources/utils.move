module memechan::utils {
    use std::ascii;
    use std::type_name;
    use std::string::{Self, String};

    use sui::coin::{Self, CoinMetadata};
    use sui::sui::SUI;

    use suitears::math64::mul_div_up;
    use memechan::errors;

    friend memechan::seed_pool;
    friend memechan::staking_pool;

    /// The amount of Mist per Sui token based on the fact that mist is
    /// 10^-9 of a Sui token
    const MIST_PER_SUI: u64 = 1_000_000_000;

    public fun mist(sui: u64): u64 { MIST_PER_SUI * sui }

    public fun are_coins_suitable<CoinA, CoinB>(): bool {
        let coin_a_type_name = type_name::get<CoinA>();
        let coin_b_type_name = type_name::get<CoinB>();

        assert!(coin_a_type_name != coin_b_type_name, errors::select_different_coins());
        true
    }

    #[allow(unused_type_parameter)]
    public fun is_coin_x<CoinA, CoinB>(): bool {
        //comparator::lt(&comparator::compare(&type_name::get<CoinA>(), &type_name::get<CoinB>()))
        &type_name::get<CoinB>() == &type_name::get<SUI>()
    }

    public fun get_optimal_add_liquidity(
        desired_amount_x: u64,
        desired_amount_y: u64,
        reserve_x: u64,
        reserve_y: u64
    ): (u64, u64) {

        if (reserve_x == 0 && reserve_y == 0) return (desired_amount_x, desired_amount_y);

        let optimal_y_amount = quote_liquidity(desired_amount_x, reserve_x, reserve_y);
        if (desired_amount_y >= optimal_y_amount) return (desired_amount_x, optimal_y_amount);

        let optimal_x_amount = quote_liquidity(desired_amount_y, reserve_y, reserve_x);
        (optimal_x_amount, desired_amount_y)
    }

    public fun quote_liquidity(amount_a: u64, reserves_a: u64, reserves_b: u64): u64 {
        mul_div_up(amount_a, reserves_b, reserves_a)
    }

    public fun get_ticket_coin_name<MemeCoin>(
        meme_coin_metadata: &CoinMetadata<MemeCoin>,
    ): String {
        let meme_coin_name = coin::get_name(meme_coin_metadata);

        let expected_ticket_coin_name = string::utf8(b"");
        string::append_utf8(&mut expected_ticket_coin_name, *string::bytes(&meme_coin_name));
        string::append_utf8(&mut expected_ticket_coin_name, b" Ticket Coin");
        expected_ticket_coin_name
    }

    public fun get_ticket_coin_symbol<MemeCoin>(
        meme_coin_metadata: &CoinMetadata<MemeCoin>,
    ): ascii::String {
        let meme_coin_symbol = coin::get_symbol(meme_coin_metadata);

        let expected_ticket_coin_symbol = string::utf8(b"");
        string::append_utf8(&mut expected_ticket_coin_symbol, b"ticket-");
        string::append_utf8(&mut expected_ticket_coin_symbol, ascii::into_bytes(meme_coin_symbol));
        string::to_ascii(expected_ticket_coin_symbol)
    }
}