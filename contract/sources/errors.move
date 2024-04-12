module memechan::errors {

    const ENoFundsToWithdraw: u64 = 0;

    public fun no_funds_to_withdraw(): u64 {
        ENoFundsToWithdraw
    }

}
