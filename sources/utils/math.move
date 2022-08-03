module kubera::math {



    const WAD: u64 = 1000000000000000000;
    /// Collateral tokens are initially valued at a ratio of 5:1 (collateral:liquidity)
    // @FIXME: restore to 5
    const INITIAL_COLLATERAL_RATE: u128 = 1;


    /// Half of identity
    const HALF_WAD: u64 = 500000000000000000;
    /// Scale for percentages
    const PERCENT_SCALER: u64 = 10000000000000000;

    /// Number of slots per year
    // 2 (slots per second) * 60 * 60 * 24 * 365 = 63072000
    const SLOTS_PER_YEAR: u64 = 63072000;


    public fun get_WAD(): u64 {
        WAD
    }

    public fun get_INITIAL_COLLATERAL_RATE() : u128 {
        INITIAL_COLLATERAL_RATE
    }

    public fun get_HALF_WAD() : u64 {
        HALF_WAD
    }

    public fun get_PERCENT_SCALER() : u64 {
        PERCENT_SCALER
    }


    public fun from_percent(percent : u8) : u128 {
        ((percent as u64) * PERCENT_SCALER as u128)
    }

    public fun from_scaled_value(value : u64) : u128 {
        (value as u128)
    }

    public fun wad() : u128 {
        (WAD as u128)
    }

    public fun zero() : u128 {
        (0 as u128)
    }

    public fun get_SLOTS_PER_YEAR() : u64 {
        SLOTS_PER_YEAR
    }

    public fun power(value : u128 , power : u8):u128 {
        value << power
    }


    public fun pow(base: u128, exp: u8): u128 {
        let result = 1u128;
        loop {
            if (exp & 1 == 1) { result = result * base; };
            exp = exp >> 1;
            base = base * base;
            if (exp == 0u8) { break };
        };
        result
    }


    public fun max(a: u128, b: u128): u128 {
        if (a < b) b else a
    }

    public fun min(a: u64, b: u64): u64 {
        if (a > b) b else a
    }

 

}