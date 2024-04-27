// TODO: remove
// module memechan::quote {
//     use memechan::bound;
//     use memechan::fees::{Self, Fees};
//     use memechan::bound_curve_amm::{Self, SeedPool};
//     use memechan::utils::is_coin_x;

//     public fun amount_out<CoinIn, CoinOut, LpCoin>(pool: &SeedPool, amount_in: u64): u64 { 
//         if (is_coin_x<CoinIn, CoinOut>()) {
//             let (balance_x, balance_y, fees) = get_pool_data<CoinIn, CoinOut, LpCoin>(pool);
//             let amount_in = amount_in - fees::get_fee_in_amount(&fees, amount_in);

//             get_amount_out(fees, bound::get_amount_out(amount_in, balance_x, balance_y, true))
//         } else {
//             let (balance_x, balance_y, fees) = get_pool_data<CoinOut, CoinIn, LpCoin>(pool);
//             let amount_in = amount_in - fees::get_fee_in_amount(&fees, amount_in);

//             get_amount_out(fees, bound::get_amount_out(amount_in, balance_x, balance_y, false))
//         }
//     }

//     fun get_amount_out(fees: Fees, amount_out: u64): u64 {
//         let fee_amount = fees::get_fee_out_amount(&fees, amount_out);
//         amount_out - fee_amount
//     }

//     fun get_pool_data<CoinX, CoinY, LpCoin>(pool: &SeedPool): (u64, u64, Fees) {
//         let fees = bound_curve_amm::fees<CoinX, CoinY, LpCoin>(pool);
//         let balance_x = bound_curve_amm::balance_x<CoinX, CoinY, LpCoin>(pool);
//         let balance_y = bound_curve_amm::balance_y<CoinX, CoinY, LpCoin>(pool);

//         (balance_x, balance_y, fees)
//     }
// }