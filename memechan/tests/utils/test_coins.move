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
module memechan::boden {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct BODEN has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: BODEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<BODEN>(
            witness,
            6,
            b"BODEN",
            b"Joe Boden",
            b"Joe Boden Token",
            option::none(),
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(BODEN {}, ctx);
    }
}

#[test_only]
module memechan::ticket_boden {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct TICKET_BODEN has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: TICKET_BODEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<TICKET_BODEN>(
            witness,
            6,
            b"sBODEN",
            b"Ticket Joe Boden",
            b"Ticket Joe Boden Token",
            option::none(),
            ctx
        );

        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TICKET_BODEN {}, ctx);
    }
    
    #[test_only]
    public fun otw_for_testing(): TICKET_BODEN {
        TICKET_BODEN {}
    }
}


#[test_only]
module memechan::btc {
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
module memechan::usdc {
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
module memechan::usdt {
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
module memechan::ticket_btc {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct TICKET_BTC has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: TICKET_BTC, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<TICKET_BTC>(
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
        init(TICKET_BTC {}, ctx);
    }
}

#[test_only]
module memechan::ticket_usdc {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct TICKET_USDC has drop {}
        
    #[lint_allow(share_owned)]
    fun init(witness: TICKET_USDC, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<TICKET_USDC>(
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
        init(TICKET_USDC {}, ctx);
    }
}

// * Invalid Coin

#[test_only]
module memechan::tickettce {
    use std::option;

    use sui::transfer;
    use sui::coin;
    use sui::tx_context::{Self, TxContext};

    struct TICKETTCE has drop {}

    #[lint_allow(share_owned)]
    fun init(witness: TICKETTCE, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<TICKETTCE>(
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
        init(TICKETTCE {}, ctx);
    }
}
