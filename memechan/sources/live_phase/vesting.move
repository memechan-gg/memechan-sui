module memechan::vesting {
    use sui::clock::{Self, Clock};
    
    friend memechan::staking_pool;
    friend memechan::seed_pool;

    const DEFAULT_CLIFF: u64 = 172800000;
    const DEFAULT_LINEAR: u64 = 1209600000;

    // Errors
    const EInconsistentTimestamps: u64 = 0;
    const EInconsistentVestingData: u64 = 1;

    struct VestingConfig has store {
        start_ts: u64,
        cliff_ts: u64,
        end_ts: u64,
    }

    struct VestingData has store {
        released: u64,
        notional: u64,
    }

    struct AccountingDfKey has drop, copy, store {}

    // ===== Public Functions =====

    public fun new_config(
        start_ts: u64,
        cliff_ts: u64,
        end_ts: u64,
    ): VestingConfig {
        assert!(start_ts <= cliff_ts, EInconsistentTimestamps);
        assert!(cliff_ts <= end_ts, EInconsistentTimestamps);

        VestingConfig {
            start_ts,
            cliff_ts,
            end_ts,
        }
    }

    public fun default_config(clock: &Clock): VestingConfig {
        let current_ts = clock::timestamp_ms(clock);

        VestingConfig {
            start_ts: current_ts,
            cliff_ts: current_ts + DEFAULT_CLIFF,
            end_ts: current_ts + DEFAULT_CLIFF + DEFAULT_LINEAR
        }
    }

    public fun new_vesting_data(
        notional: u64,
    ): VestingData {
        VestingData {
            released: 0,
            notional,
        }
    }

    public fun total_vested(self: &VestingData, config: &VestingConfig, current_ts: u64): u64 {
        if (current_ts < config.cliff_ts) return 0;
        if (current_ts > config.end_ts) return self.notional;
        (self.notional * (current_ts - config.start_ts)) / duration(config)
    }

    public fun duration(config: &VestingConfig): u64 {
        config.end_ts - config.start_ts
    }

    public fun to_release(self: &VestingData, config: &VestingConfig, current_ts: u64): u64 {
        assert!(self.released <= total_vested(self, config, current_ts), EInconsistentVestingData);
        let to_release = total_vested(self, config, current_ts) - self.released;

        to_release
    }

    public fun destroy_config(config: VestingConfig) {
        let VestingConfig {
            start_ts: _,
            cliff_ts: _,
            end_ts: _,
        } = config;
    }

    public fun destroy_vesting_data(
        data: VestingData,
    ) {
        let VestingData {
            released: _,
            notional: _,
        } = data;
    }

    // ===== Friend Functions =====

    // Unchecked
    public(friend) fun release(self: &mut VestingData, amount: u64) {
        self.released = self.released + amount;
    }

    public(friend) fun notional_mut(self: &mut VestingData) : &mut u64 { &mut self.notional }
    public(friend) fun accounting_key(): AccountingDfKey { AccountingDfKey {} }

    // ===== Getters =====

    public fun start_ts(self: &VestingConfig): u64 { self.start_ts }
    public fun cliff_ts(self: &VestingConfig): u64 { self.cliff_ts }
    public fun end_ts(self: &VestingConfig): u64 { self.end_ts }

    public fun released(self: &VestingData) : u64 {self.released}
    public fun notional(self: &VestingData) : u64 {self.notional}
    public fun current_stake(self: &VestingData) : u64 {self.notional - self.released}

    // ===== Tests =====

    #[test_only]
    use sui::test_scenario::{Self as ts, ctx};

    #[test]
    fun test_vesting() {
        let scenario = ts::begin(@0x1);

        let clock = clock::create_for_testing(ctx(&mut scenario));

        clock::set_for_testing(&mut clock, 1704067200000); // Mon Jan 01 2024 00:00:00 GMT+0000

        let config = default_config(&clock);
        let vesting_data = new_vesting_data(1_000_000);

        assert!(total_vested(&vesting_data, &config, 1704067200000) == 0, 0);       // Wed Jan 03 2024 (+1 days)
        assert!(total_vested(&vesting_data, &config, 1704239999000) == 0, 0);
        assert!(total_vested(&vesting_data, &config, 1704240000000) == 125_000, 0); // Wed Jan 03 2024 (+2 days)
        assert!(total_vested(&vesting_data, &config, 1704326400000) == 187500, 0);  // Wed Jan 04 2024 (+3 days)
        assert!(total_vested(&vesting_data, &config, 1704412800000) == 250000, 0);  // Wed Jan 05 2024 (+4 days)
        assert!(total_vested(&vesting_data, &config, 1704499200000) == 312500, 0);  // Wed Jan 06 2024 (+5 days)
        assert!(total_vested(&vesting_data, &config, 1704585600000) == 375000, 0);  // Wed Jan 07 2024 (+6 days)
        assert!(total_vested(&vesting_data, &config, 1704672000000) == 437500, 0);  // Wed Jan 08 2024 (+7 days)
        assert!(total_vested(&vesting_data, &config, 1704758400000) == 500000, 0);  // Wed Jan 09 2024 (+8 days)
        assert!(total_vested(&vesting_data, &config, 1704844800000) == 562500, 0);  // Wed Jan 10 2024 (+9 days)
        assert!(total_vested(&vesting_data, &config, 1704931200000) == 625000, 0);  // Wed Jan 11 2024 (+10 days)
        assert!(total_vested(&vesting_data, &config, 1705017600000) == 687500, 0);  // Wed Jan 12 2024 (+11 days)
        assert!(total_vested(&vesting_data, &config, 1705104000000) == 750000, 0);  // Wed Jan 13 2024 (+12 days)
        assert!(total_vested(&vesting_data, &config, 1705190400000) == 812500, 0);  // Wed Jan 14 2024 (+13 days)
        assert!(total_vested(&vesting_data, &config, 1705276800000) == 875000, 0);  // Wed Jan 15 2024 (+14 days)
        assert!(total_vested(&vesting_data, &config, 1705363200000) == 937500, 0);  // Wed Jan 16 2024 (+15 days)
        assert!(total_vested(&vesting_data, &config, 1705449600000) == 1000000, 0); // Wed Jan 17 2024 (+16 days)

        // to_release

        assert!(to_release(&vesting_data, &config, 1704067200000) == 0, 0);       // Wed Jan 03 2024 (+1 days)
        assert!(to_release(&vesting_data, &config, 1704239999000) == 0, 0);

        release(&mut vesting_data, 100_000);
        assert!(to_release(&vesting_data, &config, 1704240000000) == 25_000, 0); // Wed Jan 03 2024 (+2 days)
        assert!(to_release(&vesting_data, &config, 1704326400000) == 87500, 0);  // Wed Jan 04 2024 (+3 days)
        assert!(to_release(&vesting_data, &config, 1704412800000) == 150000, 0);  // Wed Jan 05 2024 (+4 days)
        assert!(to_release(&vesting_data, &config, 1704499200000) == 212500, 0);  // Wed Jan 06 2024 (+5 days)
        assert!(to_release(&vesting_data, &config, 1704585600000) == 275000, 0);  // Wed Jan 07 2024 (+6 days)
        assert!(to_release(&vesting_data, &config, 1704672000000) == 337500, 0);  // Wed Jan 08 2024 (+7 days)
        assert!(to_release(&vesting_data, &config, 1704758400000) == 400000, 0);  // Wed Jan 09 2024 (+8 days)

        release(&mut vesting_data, 400_000);

        assert!(to_release(&vesting_data, &config, 1704844800000) == 62_500, 0);  // Wed Jan 10 2024 (+9 days)
        assert!(to_release(&vesting_data, &config, 1704931200000) == 125_000, 0);  // Wed Jan 11 2024 (+10 days)
        assert!(to_release(&vesting_data, &config, 1705017600000) == 187_500, 0);  // Wed Jan 12 2024 (+11 days)
        assert!(to_release(&vesting_data, &config, 1705104000000) == 250_000, 0);  // Wed Jan 13 2024 (+12 days)
        assert!(to_release(&vesting_data, &config, 1705190400000) == 312_500, 0);  // Wed Jan 14 2024 (+13 days)
        assert!(to_release(&vesting_data, &config, 1705276800000) == 375_000, 0);  // Wed Jan 15 2024 (+14 days)
        assert!(to_release(&vesting_data, &config, 1705363200000) == 437_500, 0);  // Wed Jan 16 2024 (+15 days)
        assert!(to_release(&vesting_data, &config, 1705449600000) == 500_000, 0); // Wed Jan 17 2024 (+16 days)

        destroy_config(config);
        destroy_vesting_data(vesting_data);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}