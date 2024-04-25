// TODO: remove
// module memechan::bound {
//     use suitears::math256::sqrt_down;

//     use memechan::errors;
//     use memechan::math::pow_2;

//     const PRECISION: u256 = 1_000_000_000_000_000_000;

//     const MAX_X: u256 = 900_000_000 * PRECISION;
//     const MAX_Y: u256 =      30_000 * PRECISION;

//     const DECIMALS_X: u256 = 1_000_000;
//     const DECIMALS_Y: u256 = 1_000_000_000;

//     public fun invariant_(x: u64, y: u64): u256 {
//         let res_y = MAX_Y - ((y as u256) * PRECISION) / DECIMALS_Y;
//         let x = ((x as u256) * PRECISION) / DECIMALS_X;

//         (x as u256) * PRECISION - res_y * res_y
//     }

//     public fun get_amount_out(delta_in: u64, x_t0: u64, y_t0: u64, sell_x: bool): u64 {
//         assert!(delta_in != 0, errors::no_zero_coin());
//         assert!(x_t0 != 0, errors::insufficient_liquidity());
//         let check_bounds = if (sell_x) {
//             let cumulative_balance = (x_t0 + delta_in as u256) * PRECISION;
//             cumulative_balance / DECIMALS_X <= MAX_X
//         } else {
//             let cumulative_balance = (y_t0 + delta_in as u256) * PRECISION;
//             cumulative_balance / DECIMALS_Y <= MAX_Y
//         };

//         assert!(check_bounds, errors::insufficient_liquidity());

//         let (delta_in, x_t0, y_t0) = (
//             ((delta_in as u256) * PRECISION) / if (sell_x) {DECIMALS_X} else {DECIMALS_Y},
//             ((x_t0 as u256) * PRECISION) / DECIMALS_X,
//             ((y_t0 as u256) * PRECISION) / DECIMALS_Y
//         );

//         let delta_out = if (sell_x) {
//             let x_t1 = x_t0 + delta_in;
            
//             let delta_out_ = sqrt_down(x_t1) - sqrt_down(x_t0);
//             (delta_out_ * DECIMALS_Y) / sqrt_down(PRECISION)
//         } else {
//             let unfunded_y_t0 = MAX_Y - y_t0;
//             let unfunded_y_t1 = unfunded_y_t0 - delta_in;
            
//             let delta_out_ = pow_2(unfunded_y_t0) - pow_2(unfunded_y_t1);
//             (delta_out_ * DECIMALS_X) / (PRECISION * PRECISION)
//         };

//         (delta_out as u64)
//     }
// }
