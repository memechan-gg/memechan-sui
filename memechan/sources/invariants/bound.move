
module memechan::bound {
    use suitears::math256::sqrt_down;

    use memechan::errors;

    const PRECISION: u256 = 1_000_000_000_000_000_000;

    const MAX_X: u256 = 900_000_000 * PRECISION;
    const MAX_Y: u256 =      30_000 * PRECISION;

    const DECIMALS_X: u256 = 1_000_000;
    const DECIMALS_Y: u256 = 1_000_000_000;

    public fun invariant_(x: u64, y: u64): u256 {
        let res_y = MAX_Y - ((y as u256) * PRECISION) / DECIMALS_Y;
        let x = ((x as u256) * PRECISION) / DECIMALS_X;

        (x as u256) * PRECISION - res_y * res_y
    }

    public fun get_amount_out(coin_in_amount: u64, balance_x: u64, balance_y: u64, is_x: bool): u64 {
        assert!(coin_in_amount != 0, errors::no_zero_coin());
        assert!(balance_x != 0, errors::insufficient_liquidity());
        let check_bounds = if (is_x) {
            let cumulative_balance = (balance_x + coin_in_amount as u256) * PRECISION;
            cumulative_balance / DECIMALS_X <= MAX_X
        } else {
            let cumulative_balance = (balance_y + coin_in_amount as u256) * PRECISION;
            cumulative_balance / DECIMALS_Y <= MAX_Y
        };

        assert!(check_bounds, errors::insufficient_liquidity());

        let (coin_in_amount, balance_x, balance_y) = (
                    ((coin_in_amount as u256) * PRECISION) / if (is_x) {DECIMALS_X} else {DECIMALS_Y},
                    ((balance_x as u256) * PRECISION) / DECIMALS_X,
                    ((balance_y as u256) * PRECISION) / DECIMALS_Y
                );

        let res_y = MAX_Y - balance_y;

        let res = if (is_x) {
            let new_balance_x = balance_x + coin_in_amount;
            
            let nres = sqrt_down(new_balance_x) - sqrt_down(balance_x);
            (nres * DECIMALS_Y) / sqrt_down(PRECISION)
        } else {
            let new_balance_y = res_y - coin_in_amount;
            
            let nres = res_y * res_y - new_balance_y * new_balance_y;
            (nres * DECIMALS_X) / (PRECISION * PRECISION)
        };

        (res as u64)
    }

    public fun get_amount_in(coin_out_amount: u64, balance_x: u64, balance_y: u64, is_x: bool): u64 {
        assert!(coin_out_amount != 0, errors::no_zero_coin());
        assert!(balance_x != 0 && if (is_x) {(balance_y + coin_out_amount as u256) <= MAX_Y} else {balance_x >= coin_out_amount}, errors::insufficient_liquidity());
        let (coin_out_amount, balance_x, balance_y) = (
                    ((coin_out_amount as u256) * PRECISION) / if (is_x) {DECIMALS_X} else {DECIMALS_Y},
                    ((balance_x as u256) * PRECISION) / DECIMALS_X,
                    ((balance_y as u256) * PRECISION) / DECIMALS_Y
                );
        
        let res_y = MAX_Y - balance_y;
        let res_x = MAX_X - balance_x;
        
        let res = if (is_x) {
            let new_balance_x = res_x - coin_out_amount;

            res_y - sqrt_down(new_balance_x)
        } else {
            let new_balance_y = res_y + coin_out_amount;
            
            new_balance_y * new_balance_y - res_y * res_y
        };

        let nres = (res * if (is_x) {DECIMALS_Y} else {DECIMALS_X}) / (PRECISION * PRECISION);

        (nres as u64)
    }
}
