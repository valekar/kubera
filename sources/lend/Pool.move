module Kubera::Pool {

    use Std::ASCII;
    use AptosFramework::Coin;
    //use Std::Signer;
    use Kubera::KuberaConfig;
    use AptosFramework::Timestamp;


    struct Reserve<phantom LPCoin, phantom ReserveCoin> has key{
        name : ASCII::String,
        last_update : LastUpdate, 
        liquidity : ReserveLiquidy<ReserveCoin>,
        collateral : ReserveCollateral<LPCoin>,
        config : ReserveConfig

    }

     struct LPCapability<phantom LPCoin> has key, store {
        mint_cap: Coin::MintCapability<LPCoin>,
        burn_cap: Coin::BurnCapability<LPCoin>,
    }

    struct LastUpdate has store{
        block_timestamp_last : u64,
    }

    struct ReserveLiquidy<phantom ReserveCoin> has store {
     liquidity_coin : Coin::Coin<ReserveCoin>
    }

    struct ReserveCollateral<phantom LPCoin> has  store {
       collateral_coin : Coin::Coin<LPCoin>  
    }

    struct ReserveConfig has store {
        fee : ReserveFee
    } 


    struct ReserveFee has key, store {
        borrow_fee : u64
    }


    const ERROR_ALREADY_INITIALIZED:u64 = 1;
    const COIN_ALREADY_INITIALIZED:u64 = 2000;
    const ERROR_RESORUCE_DOES_NOT_EXISTS:u64 = 2;


    public fun create_reserve<LPCoin, ReserveCoin>(
        sender : &signer,name : ASCII::String, borrow_fee : u64, 
        lp_coin_name : ASCII::String , symbol : ASCII::String, decimals : u64
    ) {

        //let addr = Signer::address_of(sender);
       let last_update = LastUpdate {
          block_timestamp_last :  Timestamp::now_seconds() % 0xFFFFFFFF 
       };

        
       intialize_reserve_coin<LPCoin>(sender, lp_coin_name, symbol, decimals);
       

       
        let liquidity = ReserveLiquidy<ReserveCoin> {
            liquidity_coin : Coin::zero<ReserveCoin>()
        };

        let collateral = ReserveCollateral<LPCoin> {
            collateral_coin : Coin::zero<LPCoin>()
        };

        let config = ReserveConfig {
            fee : ReserveFee {
                borrow_fee : borrow_fee
            }
        };

        let reserve = Reserve<LPCoin, ReserveCoin> {
            name : name,
            last_update : last_update,
            liquidity : liquidity,
            collateral : collateral,
            config : config
        };

        move_to<Reserve<LPCoin, ReserveCoin>>(sender, reserve);
 
    }
    
    
    fun intialize_reserve_coin<CoinType>(sender : &signer, lp_coin_name : ASCII::String , symbol : ASCII::String, decimals : u64) {
        assert!(!Coin::is_coin_initialized<CoinType>(), ERROR_ALREADY_INITIALIZED);
        let (mint_capability, burn_capability) = Coin::initialize<CoinType>(
            sender, lp_coin_name, symbol, decimals, true
        );
        Coin::register_internal<CoinType>(sender);
        move_to(sender, LPCapability<CoinType>{ mint_cap: mint_capability, burn_cap: burn_capability });
    }


   fun add_reserve_lp_collateral_direct<LPCoin, ReserveCoin> (x : Coin::Coin<LPCoin>) : u64  acquires Reserve {
    let addr = KuberaConfig::admin_address();
    assert!(!exists<Reserve<LPCoin, ReserveCoin>>(addr), ERROR_RESORUCE_DOES_NOT_EXISTS);
    let pool = borrow_global_mut<Reserve<LPCoin, ReserveCoin>>(KuberaConfig::admin_address());
    let collateral_coin = &mut pool.collateral.collateral_coin;
    Coin::merge(collateral_coin, x);
    
    Coin::value(collateral_coin)

   }

   fun fetch_pool_balance<LPCoin, ReserveCoin>() : (u64, u64) acquires Reserve {
    let pool = borrow_global<Reserve<LPCoin,ReserveCoin>>(KuberaConfig::admin_address());
    let collateral_coin = Coin::value(&pool.collateral.collateral_coin);
    let liquidity_coin = Coin::value(&pool.liquidity.liquidity_coin);

    (collateral_coin, liquidity_coin)
   }


    // fun tsest(sender : &signer) {

    //     MockDeploy::init_coin_and_create_store<MockCoin::WUSDC>(admin, b"USDC", b"USDC", 8);
    // }


}