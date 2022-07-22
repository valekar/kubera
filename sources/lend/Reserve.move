module Kubera::Reserve {

    use Std::ASCII;
    use AptosFramework::Coin;
    //use Std::Signer;
    use Kubera::KuberaConfig;


    struct Pool<phantom LPCoin, phantom PoolToken> has key{
        name : ASCII::String,
        last_update : LastUpdate, 
        liquidity : PoolLiquidy<PoolToken>,
        collateral : PoolCollateral<LPCoin>,
        config : PoolConfig

    }

     struct LPCapability<phantom LPCoin> has key, store {
        mint_cap: Coin::MintCapability<LPCoin>,
        burn_cap: Coin::BurnCapability<LPCoin>,
    }

    struct LastUpdate has store{
        block_time : u64,
    }

    struct PoolLiquidy<phantom PoolToken> has store {
     liquidity_token : Coin::Coin<PoolToken>
    }

    struct PoolCollateral<phantom LPCoin> has  store {
       collateral_token : Coin::Coin<LPCoin>  
    }

    struct PoolConfig has store {
        fee : PoolFee
    } 


    struct PoolFee has key, store {
        borrow_fee : u64
    }




    const ERROR_ALREADY_INITIALIZED:u64 = 1;
    const COIN_ALREADY_INITIALIZED:u64 = 2000;

    
    public fun intialize_pool_collateral<LPCoin>(sender : &signer, lp_coin_name : ASCII::String , symbol : ASCII::String, decimals : u64) {
        assert!(Coin::is_coin_initialized<LPCoin>(), ERROR_ALREADY_INITIALIZED);
        let (mint_capability, burn_capability) = Coin::initialize<LPCoin>(
            sender, lp_coin_name, symbol, decimals, true
        );
        Coin::register_internal<LPCoin>(sender);
        move_to(sender, LPCapability<LPCoin>{ mint_cap: mint_capability, burn_cap: burn_capability });
    }


   fun add_lp_liquidity_direct<LPCoin, PoolCoin> (x : Coin::Coin<LPCoin>) : u64  acquires Pool {

    let pool = borrow_global_mut<Pool<LPCoin, PoolCoin>>(KuberaConfig::admin_address());
    let collateral_token = &mut pool.collateral.collateral_token;
    Coin::merge(collateral_token, x);
    
    Coin::value(collateral_token)

   }


}