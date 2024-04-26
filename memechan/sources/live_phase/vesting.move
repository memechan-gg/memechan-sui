module memechan::vesting {
    use sui::clock::{Self, Clock};
    
    friend memechan::staking_pool;

    const DEFAULT_CLIFF: u64 = 172800000; // 48 hours; TODO: test
    const DEFAULT_LINEAR: u64 = 1209600000; // 14 days; TODO: test

    struct VestingConfig has store {
        start_ts: u64,
        cliff_ts: u64,
        end_ts: u64,
    }

    struct VestingData has store {
        released: u64,
        notional: u64,
    }

    public fun default_config(clock: &Clock): VestingConfig {
        let current_ts = clock::timestamp_ms(clock);

        VestingConfig {
            start_ts: current_ts,
            cliff_ts: current_ts + DEFAULT_CLIFF,
            end_ts: current_ts + DEFAULT_CLIFF + DEFAULT_LINEAR // TODO: Unit test
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
        let to_release = total_vested(self, config, current_ts) - self.released;

        to_release
    }

    // Unchecked
    public(friend) fun release(self: &mut VestingData, amount: u64) {
        self.released = self.released + amount;
    }

    // Getters
    public fun released(self: &VestingData) : u64 {self.released}

    public fun notional(self: &VestingData) : u64 {self.notional}

    public fun current_stake(self: &VestingData) : u64 {self.notional - self.released}
}