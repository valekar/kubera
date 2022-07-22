module Kubera::Reserve {

    use AptosFramework::Coin;
    //use AptosFramework::Timestamp;
    use Std::ASCII;

    struct Pool<phantom LPCoin, phantom PoolCoin> has key{
        name : ASCII::String,
        last_update : LastUpdate, 
        liquidity : PoolLiquidy<PoolCoin>,
        collateral : PoolCollateral<LPCoin>,
        config : PoolConfig

    }

    struct LastUpdate has store{
        block_time : u64,
    }

    struct PoolLiquidy<phantom PoolCoin> has store {
     liquidity_token : Coin::Coin<PoolCoin>
    }

    struct PoolCollateral<phantom LPCoin> has store {
       collateral_token : Coin::Coin<LPCoin>  
    }

    struct PoolConfig has store {
        fee : PoolFee
    } 


    struct PoolFee has store {
        borrow_fee : u64
    }

    
}