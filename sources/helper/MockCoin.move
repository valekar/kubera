// token holder address, not admin address

module kubera::MockCoin {
    use aptos_framework::coin;
    use aptos_framework::type_info;
    use std::string::{Self};
    use std::signer;

    spec module {
        pragma verify = false;
    }

    struct TokenSharedCapability<phantom TokenType> has key, store {
        mint: coin::MintCapability<TokenType>,
        burn: coin::BurnCapability<TokenType>,
    }

    // mock BTC token
    struct WBTC has copy, drop, store {}

    // mock ETH token
    struct WETH has copy, drop, store {}

    // mock USDT token
    struct WUSDT has copy, drop, store {}

    // mock USDC token
    struct WUSDC has copy, drop, store {}

    // mock DAI token
    struct WDAI has copy, drop, store {}

    // mock DOT token
    struct WDOT has copy, drop, store {}

    // mock SOL token
    struct WSOL has copy, drop, store {}


    public fun initialize<TokenType>(account: &signer, decimals: u64){
        let name = string::utf8(type_info::struct_name(&type_info::type_of<TokenType>()));
        let (mint_capability, burn_capability) = coin::initialize<TokenType>(
            account,
            name,
            name,
            decimals,
            true
        );
        coin::register_internal<TokenType>(account);

        move_to(account, TokenSharedCapability { mint: mint_capability, burn: burn_capability });
    }

    public fun mint<TokenType>(amount: u64): coin::Coin<TokenType> acquires TokenSharedCapability{
        //token holder address
        let addr = type_info::account_address(&type_info::type_of<TokenType>());
        let cap = borrow_global<TokenSharedCapability<TokenType>>(addr);
        coin::mint<TokenType>( amount, &cap.mint,)
    }

    public fun burn<TokenType>(tokens: coin::Coin<TokenType>) acquires TokenSharedCapability{
        //token holder address
        let addr = type_info::account_address(&type_info::type_of<TokenType>());
        let cap = borrow_global<TokenSharedCapability<TokenType>>(addr);
        coin::burn<TokenType>(tokens, &cap.burn);
    }

    public fun faucet_mint_to<TokenType>(to: &signer, amount: u64) acquires TokenSharedCapability {
        let to_addr = signer::address_of(to);
        if (!coin::is_account_registered<TokenType>(to_addr)) {
            coin::register_internal<TokenType>(to);
        };
        let coin = mint<TokenType>(amount);
        coin::deposit(to_addr, coin);
    }

    public entry fun faucet_mint_to_script<TokenType>(to: &signer, amount: u64) acquires  TokenSharedCapability {
        faucet_mint_to<TokenType>(to, amount);
    }


    #[test(admin=@kubera, user=@0x1234567, core=@0xa550c18)]
    public entry fun test_mint_script(admin: &signer, user: &signer) acquires TokenSharedCapability {
        initialize<WETH>(admin, 6);
        faucet_mint_to_script<WETH>(user, 1000000);
    }

}



