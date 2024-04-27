#[test_only]
module memechan::fees_tests {
    use sui::test_utils::assert_eq;
    use sui::test_scenario::{Self as test, next_tx};

    use memechan::fees;
    use memechan::deploy_utils::{people, scenario};

    const INITIAL_FEE_PERCENT: u256 = 250000000000000; // 0.025%

    #[test]
    fun sets_initial_state_correctly() {
        let scenario = scenario();
        let (alice, _) = people();

        let test = &mut scenario;

        next_tx(test, alice);
        {
            
            let fees = fees::new(INITIAL_FEE_PERCENT, INITIAL_FEE_PERCENT + 1);

            let fee_in = fees::fee_in_percent(&fees);
            let fee_out = fees::fee_out_percent(&fees);

            assert_eq(fee_in, INITIAL_FEE_PERCENT);
            assert_eq(fee_out, INITIAL_FEE_PERCENT + 1);
        };
        test::end(scenario);
    }
}