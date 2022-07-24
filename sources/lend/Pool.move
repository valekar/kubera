module Kubera::Pool {

    use Std::ASCII;
    use AptosFramework::Coin;
    use Std::Signer;
    use Kubera::KuberaConfig;
    use AptosFramework::Timestamp;


    struct LPCoin<phantom ReserveCoin> {}

    struct Reserve<phantom ReserveCoin> has key{
        name : ASCII::String,
        last_update : LastUpdate, 
        liquidity : ReserveLiquidy<ReserveCoin>,
        collateral : ReserveCollateral<ReserveCoin>,
        config : ReserveConfig

    }

     struct LPCapability<phantom ReserveCoin> has key, store {
        mint_cap: Coin::MintCapability<LPCoin<ReserveCoin>>,
        burn_cap: Coin::BurnCapability<LPCoin<ReserveCoin>>,
    }

    struct LastUpdate has store{
        block_timestamp_last : u64,
    }

    struct ReserveLiquidy<phantom ReserveCoin> has store {
     liquidity_coin : Coin::Coin<ReserveCoin>
    }

    struct ReserveCollateral<phantom ReserveCoin> has  store {
       collateral_coin : Coin::Coin<LPCoin<ReserveCoin>>  
    }

    struct ReserveConfig has store {
        optimal_utilization_rate: u8,
        // Target ratio of the value of borrows to deposits, as a percentage
        // 0 if use as collateral is disabled
        loan_to_value_ratio: u8,
        /// Bonus a liquidator gets when repaying part of an unhealthy obligation, as a percentage
        liquidation_bonus: u8,
        /// Loan to value ratio at which an obligation can be liquidated, as a percentage
        liquidation_threshold: u8,
        /// Min borrow APY
        min_borrow_rate: u8,
        /// Optimal (utilization) borrow APY
        optimal_borrow_rate: u8,
        /// Max borrow APY
        max_borrow_rate: u8,
        fees: ReserveFees,
        /// Maximum deposit limit of liquidity in native units, u64::MAX for inf
        deposit_limit: u64,
        /// Borrows disabled
        borrow_limit: u64,
        /// Reserve liquidity fee receiver address
        fee_receiver: address,
        /// Cut of the liquidation bonus that the protocol receives, as a percentage
        protocol_liquidation_fee: u8,
        /// Protocol take rate is the amount borrowed interest protocol recieves, as a percentage  
        protocol_take_rate: u8,
    } 


    struct ReserveFees has key, store {
        borrow_fees : u64
    }


    const ERROR_ALREADY_INITIALIZED:u64 = 1;
    const COIN_ALREADY_INITIALIZED:u64 = 2000;
    const ERROR_RESORUCE_DOES_NOT_EXISTS:u64 = 2;


    public fun create_reserve<ReserveCoin>(
        sender : &signer,
        reserve_name : ASCII::String, 
        reserve_collateral_name : ASCII::String, 
        reserve_collateral_symbol : ASCII::String,
        collateral_decimals : u64, 
        optimal_utilization_rate : u8,
        loan_to_value_ratio : u8,
        liquidation_bonus : u8,
        liquidation_threshold: u8,
        min_borrow_rate: u8,
        optimal_borrow_rate: u8,
        max_borrow_rate: u8,
        fees : u64,
        deposit_limit: u64,
        borrow_limit: u64,
        protocol_liquidation_fee: u8,
        protocol_take_rate: u8
    ) {
       let addr = Signer::address_of(sender);

        assert!(!exists<Reserve<ReserveCoin>>(addr), ERROR_ALREADY_INITIALIZED);

       let last_update = LastUpdate {
          block_timestamp_last :  Timestamp::now_seconds() % 0xFFFFFFFF 
       };

       intialize_collateral_coin<LPCoin<ReserveCoin>>(sender, reserve_collateral_name, reserve_collateral_symbol, collateral_decimals);
       
        let liquidity = ReserveLiquidy<ReserveCoin> {
            liquidity_coin : Coin::zero<ReserveCoin>()
        };

        let collateral = ReserveCollateral<ReserveCoin> {
            collateral_coin : Coin::zero<LPCoin<ReserveCoin>>()
        };

        let reserve = Reserve<ReserveCoin> {
            name : reserve_name,
            last_update : last_update,
            liquidity : liquidity,
            collateral : collateral,
            config : ReserveConfig {
                    optimal_utilization_rate : optimal_utilization_rate ,
                    loan_to_value_ratio : loan_to_value_ratio,
                    liquidation_bonus : liquidation_bonus,
                    liquidation_threshold:liquidation_threshold ,
                    min_borrow_rate: min_borrow_rate,
                    optimal_borrow_rate: optimal_borrow_rate,
                    max_borrow_rate: max_borrow_rate,
                    fees : ReserveFees {
                        borrow_fees : fees
                    },
                    deposit_limit: deposit_limit,
                    borrow_limit: borrow_limit,
                    fee_receiver: addr,
                    protocol_liquidation_fee: protocol_liquidation_fee,
                    protocol_take_rate: protocol_take_rate 
            }
        };

        move_to<Reserve<ReserveCoin>>(sender, reserve);
 
    }
    
    
    fun intialize_collateral_coin<CoinType>(sender : &signer, lp_coin_name : ASCII::String , symbol : ASCII::String, decimals : u64) {
        assert!(!Coin::is_coin_initialized<CoinType>(), ERROR_ALREADY_INITIALIZED);
        let (mint_capability, burn_capability) = Coin::initialize<LPCoin<CoinType>>(
            sender, lp_coin_name, symbol, decimals, true
        );
        Coin::register_internal<CoinType>(sender);
        move_to(sender, LPCapability<CoinType>{ mint_cap: mint_capability, burn_cap: burn_capability });
    }


   fun add_reserve_lp_collateral_direct<ReserveCoin> (x : Coin::Coin<LPCoin<ReserveCoin>>) : u64  acquires Reserve {
    let addr = KuberaConfig::admin_address();
    assert!(!exists<Reserve<ReserveCoin>>(addr), ERROR_RESORUCE_DOES_NOT_EXISTS);
    let pool = borrow_global_mut<Reserve<ReserveCoin>>(KuberaConfig::admin_address());
    let collateral_coin = &mut pool.collateral.collateral_coin;
    Coin::merge(collateral_coin, x);
    
    Coin::value(collateral_coin)

   }

   public fun fetch_pool_balance<ReserveCoin>() : (u64, u64) acquires Reserve {
    let pool = borrow_global<Reserve<ReserveCoin>>(KuberaConfig::admin_address());
    let collateral_coin = Coin::value(&pool.collateral.collateral_coin);
    let liquidity_coin = Coin::value(&pool.liquidity.liquidity_coin);

    (collateral_coin, liquidity_coin)
   }

 

}