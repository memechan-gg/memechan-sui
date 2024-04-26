module memechan::math256 {
    public fun div(x: u256, y: u256): u256 {
        (x / y)
    }

    public fun mul_div(x: u256, y: u256, z: u256): u256 {
        let x = (x as u128);
        let y = (y as u128);
        let z = (z as u128);
        
        let result = (((x * y) / z) as u256);

        result
    }
    
    public fun div_mul(mul_a: u256, div_b: u256, mul_c: u256, ): u256 {
        let x = (mul_a as u128);
        let y = (div_b as u128);
        let z = (mul_c as u128);
        
        let result = (((x / y) * z) as u256);

        result
    }

    public fun pow_2(x: u256): u256 {
        x * x
    }
}