module amm::fee_distribution {

    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::table::{Self, Table};
    use sui::tx_context::{Self, TxContext};

    use amm::errors;

    const PRECISION : u256 = 1_000_000_000_000_000;

    struct FeeState<phantom CoinX, phantom CoinY> {
        fees_x: Balance<CoinX>,
        fees_y: Balance<CoinY>,
        user_withdrawals_x: Table<address, u64>,
        user_withdrawals_y: Table<address, u64>,
        user_stakes: Table<address, u64>,
        stakes_total: u64,
        fees_x_total: u64,
        fees_y_total: u64,
    }

    public fun withdraw<CoinX, CoinY>(state: &mut FeeState<CoinX, CoinY>, ctx: &mut TxContext): (Coin<CoinX>, Coin<CoinY>) {
        let sender = tx_context::sender(ctx);
        let user_stake = *table::borrow(&state.user_stakes, sender);
        
        let user_withdrawals_x = table::borrow_mut(&mut state.user_withdrawals_x, sender);
        let max_withdrawal_x = get_max_withdraw(*user_withdrawals_x, state.fees_x_total, user_stake, state.stakes_total);
        *user_withdrawals_x = ((*user_withdrawals_x + max_withdrawal_x) as u64);

        let user_withdrawals_y = table::borrow_mut(&mut state.user_withdrawals_y, sender);
        let max_withdrawal_y = get_max_withdraw(*user_withdrawals_y, state.fees_y_total, user_stake, state.stakes_total);
        *user_withdrawals_y = ((*user_withdrawals_y + max_withdrawal_y) as u64);

        (coin::from_balance(balance::split(&mut state.fees_x, max_withdrawal_x), ctx), 
        coin::from_balance(balance::split(&mut state.fees_y, max_withdrawal_y), ctx))
    }

    public(friend) fun update_stake<CoinX, CoinY>(user_new_stake: u64, state: &mut FeeState<CoinX, CoinY>, ctx: &mut TxContext) : (Coin<CoinX>, Coin<CoinY>) {
        let (coin_x, coin_y) = withdraw(state, ctx);

        let sender = tx_context::sender(ctx);

        let user_stake = table::borrow_mut(&mut state.user_stakes, sender);
        let stake_diff = (((*user_stake - user_new_stake) as u256) * PRECISION) / (*user_stake as u256);
        
        let user_withdrawals_x = table::borrow_mut(&mut state.user_withdrawals_x, sender);
        let withdraw_diff_x = get_withdraw_diff(*user_withdrawals_x, stake_diff);
        *user_withdrawals_x = *user_withdrawals_x - withdraw_diff_x;


        let user_withdrawals_y = table::borrow_mut(&mut state.user_withdrawals_y, sender);
        let withdraw_diff_y = get_withdraw_diff(*user_withdrawals_y, stake_diff);
        *user_withdrawals_y = *user_withdrawals_y - withdraw_diff_y;

        state.stakes_total = state.stakes_total - (*user_stake - user_new_stake);
        *user_stake = user_new_stake;

        (coin_x, coin_y)
    }

    fun get_max_withdraw(user_withdrawals: u64, fees_total: u64, user_stake: u64, stakes_total: u64) : u64 {
        
        let (user_withdrawals_total, fees_total, user_stake, stakes_total) = (
            (user_withdrawals as u256),
            (fees_total as u256),
            (user_stake as u256),
            (stakes_total as u256)
        );

        let max_user_withdrawal = fees_total * ((user_stake * PRECISION) / stakes_total);

        assert!(max_user_withdrawal <= user_withdrawals_total * PRECISION, errors::no_funds_to_withdraw());

        let allowed_withdrawal = max_user_withdrawal - user_withdrawals_total;

        ((allowed_withdrawal / PRECISION) as u64)
    }

    fun get_withdraw_diff(user_withdrawals: u64, stake_diff: u256) : u64 {
        let withdraw_diff_x = ((user_withdrawals as u256) * stake_diff) / PRECISION;
        (withdraw_diff_x as u64)
    }



}