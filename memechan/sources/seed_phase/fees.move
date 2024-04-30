module memechan::fees {
    use suitears::math256::mul_div_up;

    const PRECISION: u256 = 1_000_000_000_000_000_000;

    struct Fees has store, copy, drop {
        fee_in_percent: u256,
        fee_out_percent: u256,
    }

    public fun new(fee_in_percent: u256, fee_out_percent: u256): Fees {
        Fees {
            fee_in_percent,
            fee_out_percent
        }
    }

    public fun fee_in_percent(fees: &Fees): u256 {
        fees.fee_in_percent
    }

    public fun fee_out_percent(fees: &Fees): u256 {
        fees.fee_out_percent
    }

    public fun get_fee_in_amount(fees: &Fees, amount: u64): u64 {
        get_fee_amount(amount, fees.fee_in_percent)
    }

    public fun get_fee_out_amount(fees: &Fees, amount: u64): u64 {
        get_fee_amount(amount, fees.fee_out_percent)
    }

    public fun get_gross_amount(fees: &Fees, amount: u64): u64 {
        get_initial_amount(amount, fees.fee_in_percent)
    }

    public fun get_fee_out_initial_amount(fees: &Fees, amount: u64): u64 {
        get_initial_amount(amount, fees.fee_out_percent)
    }

    fun get_fee_amount(x: u64, percent: u256): u64 {
        (mul_div_up((x as u256), percent, PRECISION) as u64)
    }

    fun get_initial_amount(x: u64, percent: u256): u64 {
        (mul_div_up((x as u256), PRECISION, PRECISION - percent) as u64)
    }
}