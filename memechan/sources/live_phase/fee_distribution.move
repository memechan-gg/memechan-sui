module memechan::fee_distribution {

    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::table::{Self, Table};
    use sui::tx_context::{Self, TxContext};

    use memechan::errors;

    friend memechan::staking_pool;

    const PRECISION : u256 = 1_000_000_000_000_000;

    struct FeeState<phantom M, phantom S> has store {
        fees_x: Balance<M>,
        fees_y: Balance<S>,
        user_withdrawals_x: Table<address, u64>,
        user_withdrawals_y: Table<address, u64>,
        stakes_total: u64,
        fees_x_total: u64,
        fees_y_total: u64,
    }

    // ===== Public Functions =====

    /// Withdraws fees from the `FeeState` and updates user's withdrawals records.
    ///
    /// # Arguments
    ///
    /// * `state` - A mutable reference to the FeeState.
    /// * `user_stake` - The stake amount of the user.
    /// * `ctx` - A mutable reference to the transaction context.
    ///
    /// # Returns
    ///
    /// A tuple containing the withdrawn balances of type M and S.
    ///
    public fun withdraw<M, S>(
        state: &mut FeeState<M, S>,
        user_stake: u64,
        ctx: &mut TxContext
    ): (Balance<M>, Balance<S>) {
        let sender = tx_context::sender(ctx);
        
        let user_withdrawals_x = table::borrow_mut(&mut state.user_withdrawals_x, sender);
        let max_withdrawal_x = get_max_withdraw(*user_withdrawals_x, state.fees_x_total, user_stake, state.stakes_total);
        *user_withdrawals_x = ((*user_withdrawals_x + max_withdrawal_x) as u64);

        let user_withdrawals_y = table::borrow_mut(&mut state.user_withdrawals_y, sender);
        let max_withdrawal_y = get_max_withdraw(*user_withdrawals_y, state.fees_y_total, user_stake, state.stakes_total);
        *user_withdrawals_y = ((*user_withdrawals_y + max_withdrawal_y) as u64);

        (balance::split(&mut state.fees_x, max_withdrawal_x),
        balance::split(&mut state.fees_y, max_withdrawal_y))
    }

    // ===== Friend Functions =====

    /// Creates a new FeeState instance.
    ///
    /// # Arguments
    ///
    /// * `stakes_total` - Total stakes accumulated.
    /// * `ctx` - A mutable reference to the transaction context.
    ///
    /// # Returns
    ///
    /// A new instance of FeeState.
    public(friend) fun new<M, S>(
        stakes_total: u64,
        ctx: &mut TxContext
    ): FeeState<M, S> {
        return FeeState{
            fees_x: balance::zero(),
            fees_y: balance::zero(),
            user_withdrawals_x: table::new(ctx),
            user_withdrawals_y: table::new(ctx),
            stakes_total,
            fees_x_total: 0,
            fees_y_total: 0,
        }
    }

    /// Adds fees to the FeeState.
    ///
    /// # Arguments
    ///
    /// * `state` - A mutable reference to the FeeState.
    /// * `coin_m` - The amount of fees in Coin<M>.
    /// * `coin_s` - The amount of fees in Coin<S>.
    public(friend) fun add_fees<M, S>(state: &mut FeeState<M, S>, coin_m: Coin<M>, coin_s: Coin<S>) {
        state.fees_x_total = state.fees_x_total + coin::value(&coin_m);
        state.fees_y_total = state.fees_y_total + coin::value(&coin_s);

        balance::join(&mut state.fees_x, coin::into_balance(coin_m));
        balance::join(&mut state.fees_y, coin::into_balance(coin_s));
    }
    
    /// Updates the stake of a user and withdraws corresponding fees.
    ///
    /// # Arguments
    ///
    /// * `user_old_stake` - The old stake of the user.
    /// * `user_stake_diff` - The difference in stake.
    /// * `state` - A mutable reference to the FeeState.
    /// * `ctx` - A mutable reference to the transaction context.
    ///
    /// # Returns
    ///
    /// A tuple containing the withdrawn balances of type M and S.
    public(friend) fun update_stake<M, S>(
        user_old_stake: u64,
        user_stake_diff: u64,
        state: &mut FeeState<M, S>,
        ctx: &mut TxContext
    ) : (Balance<M>, Balance<S>) {
        let (coin_x, coin_y) = withdraw(state, user_old_stake, ctx);

        let sender = tx_context::sender(ctx);

        let stake_diff = ((user_stake_diff as u256) * PRECISION) / (user_old_stake as u256);
        
        let user_withdrawals_x = table::borrow_mut(&mut state.user_withdrawals_x, sender);
        let withdraw_diff_x = get_withdraw_diff(*user_withdrawals_x, stake_diff);
        *user_withdrawals_x = *user_withdrawals_x - withdraw_diff_x;


        let user_withdrawals_y = table::borrow_mut(&mut state.user_withdrawals_y, sender);
        let withdraw_diff_y = get_withdraw_diff(*user_withdrawals_y, stake_diff);
        *user_withdrawals_y = *user_withdrawals_y - withdraw_diff_y;

        state.stakes_total = state.stakes_total - user_stake_diff;

        (coin_x, coin_y)
    }

    // ===== Private Functions =====

    /// Calculates the maximum amount of fees a user can withdraw.
    ///
    /// # Arguments
    ///
    /// * `user_withdrawals` - The total amount the user has already withdrawn.
    /// * `fees_total` - The total fees collected.
    /// * `user_stake` - The stake of the user.
    /// * `stakes_total` - The total stakes accumulated.
    ///
    /// # Returns
    ///
    /// The maximum amount of fees the user can withdraw.
    fun get_max_withdraw(
        user_withdrawals: u64,
        fees_total: u64,
        user_stake: u64,
        stakes_total: u64
    ) : u64 {
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

    /// Calculates the withdrawal difference based on stake difference.
    ///
    /// # Arguments
    ///
    /// * `user_withdrawals` - The total amount the user has already withdrawn.
    /// * `stake_diff` - The difference in stake.
    ///
    /// # Returns
    ///
    /// The withdrawal difference.
    fun get_withdraw_diff(user_withdrawals: u64, stake_diff: u256) : u64 {
        let withdraw_diff_x = ((user_withdrawals as u256) * stake_diff) / PRECISION;
        (withdraw_diff_x as u64)
    }
}