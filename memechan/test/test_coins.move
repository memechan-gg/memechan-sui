#[test_only]
module memechan::eth {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct ETH has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: ETH, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<ETH>(
            witness, 
            9, 
            b"ETH",
            b"Ether", 
            b"Ethereum Native Coin", 
            option::none(), 
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ETH {}, ctx);
    }
}


#[test_only]
module amm::btc {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct BTC has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: BTC, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<BTC>(
            witness, 
            9, 
            b"BTC",
            b"Bitcoin", 
            b"Bitcoin Native Coin", 
            option::none(), 
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(BTC {}, ctx);
    }
}

#[test_only]
module amm::usdc {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct USDC has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: USDC, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<USDC>(
            witness, 
            6, 
            b"USDC",
            b"USD Coin", 
            b"USD Stable Coin by Circle", 
            option::none(), 
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(USDC {}, ctx);
    }
}

#[test_only]
module amm::usdt {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct USDT has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: USDT, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<USDT>(
            witness, 
            6, 
            b"USDT",
            b"USD Tether", 
            b"Stable coin", 
            option::none(), 
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(USDT {}, ctx);
    }
}

#[test_only]
module amm::ac_b_btc {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct AC_B_BTC has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: AC_B_BTC, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<AC_B_BTC>(
            witness, 
            6, 
            b"",
            b"", 
            b"", 
            option::none(), 
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(AC_B_BTC {}, ctx);
    }
}

#[test_only]
module amm::ac_b_usdc {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct AC_B_USDC has drop {}
        
    #[lint_allow(share_owned)]
    fun init(witness: AC_B_USDC, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<AC_B_USDC>(
            witness, 
            6, 
            b"",
            b"", 
            b"", 
            option::none(), 
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(AC_B_USDC {}, ctx);
    }
}

// * Invalid Coin

#[test_only]
module amm::ac_btce {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct AC_BTCE has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: AC_BTCE, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<AC_BTCE>(
            witness, 
            8, 
            b"",
            b"", 
            b"", 
            option::none(), 
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(AC_BTCE {}, ctx);
    }
}
