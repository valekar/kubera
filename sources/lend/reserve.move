module kubera::reserve {

    use std::string::{String};
    use aptos_framework::coin;
    use std::signer;
    use kubera::kubera_config;
    use kubera::base::LPCoin;
    //use aptos_framework::timestamp;
   // use aptos_framework::account;
   use std::debug;
   use std::option::{Self};
   use kubera::math;



    struct Reserve<phantom ReserveCoin> has key{
        name : String,
        //last_update : LastUpdate, 
        liquidity : ReserveLiquidity<ReserveCoin>,
        collateral : ReserveLP<ReserveCoin>,
        config : ReserveConfig,
        //reserve_address : address,

    }

     struct LPCapability<phantom ReserveCoin> has key, store {
        mint_cap: coin::MintCapability<LPCoin<ReserveCoin>>,
        burn_cap: coin::BurnCapability<LPCoin<ReserveCoin>>,
    }

    struct LastUpdate has store{
        block_timestamp_last : u64,
    }

    struct ReserveLiquidity<phantom ReserveCoin> has store {
        liquidity_coin : coin::Coin<ReserveCoin>,
        //supply_address : address,  - this would be address from where reserve mint arises
        /// Reserve liquidity available
        available_amount : u64,
        /// Reserve liquidity borrowed //decimals
        borrowed_amount_wads: u64,
        /// Reserve liquidity cumulative borrow rate //decimals
        cumulative_borrow_rate_wads: u64,
        /// Reserve cumulative protocol fees //decimals
        accumulated_protocol_fees_wads: u64,
        /// Reserve liquidity market price in quote currency //decimals
        market_price: u64,
        //decimals
        decimals : u64
    }

    struct ReserveLP<phantom ReserveCoin> has  store {
       lp_coins : coin::Coin<LPCoin<ReserveCoin>>,
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
        //Max user deposit limit
        user_deposit_limit : u64,
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
        borrow_fee_wad : u64,
        /// Amount of fee going to host account, if provided in liquidate and repay
        host_fee_percentage: u8,
    }


    const ERROR_ALREADY_INITIALIZED:u64 = 1;
    const ERROR_RESORUCE_DOES_NOT_EXISTS:u64 = 2;

    const ERROR_DEPOSIT_LIMIT_REACHED:u64 = 2001;
    const ERROR_INSUFFICIENT_BALANCE:u64 = 2002;
    const ERROR_BORROW_AMOUNT_IS_TOO_SMALL:u64 = 2003;



    public fun create_reserve<ReserveCoin>(
        sender : &signer,
        reserve_name : String, 
        reserve_collateral_name : String, 
        reserve_collateral_symbol : String,
        reserve_collateral_decimals : u64, 
        optimal_utilization_rate : u8,
        loan_to_value_ratio : u8,
        liquidation_bonus : u8,
        liquidation_threshold: u8,
        min_borrow_rate: u8,
        optimal_borrow_rate: u8,
        max_borrow_rate: u8,
        fees : u64,
        host_fee_percentage : u8,
        deposit_limit: u64,
        user_deposit_limit : u64,
        borrow_limit: u64,
        protocol_liquidation_fee: u8,
        protocol_take_rate: u8
    ) {
       let addr = signer::address_of(sender);

        assert!(!exists<Reserve<ReserveCoin>>(addr), ERROR_ALREADY_INITIALIZED);

    //    let last_update = LastUpdate {
    //       block_timestamp_last :  timestamp::now_seconds()
    //    };

        // INitialize store for LP Coin 
       assert!(!coin::is_coin_initialized<LPCoin<ReserveCoin>>(), ERROR_ALREADY_INITIALIZED);
        let (mint_capability, burn_capability) = coin::initialize<LPCoin<ReserveCoin>>(
            sender, reserve_collateral_name, reserve_collateral_symbol, reserve_collateral_decimals, true
        );
        coin::register_internal<LPCoin<ReserveCoin>>(sender);
        let lp_capability = LPCapability<ReserveCoin>{ mint_cap: mint_capability, burn_cap: burn_capability };
        move_to<LPCapability<ReserveCoin>>(sender, lp_capability);
        // initialize LPCOIN

       
        let liquidity = ReserveLiquidity<ReserveCoin> {
            liquidity_coin : coin::zero<ReserveCoin>(),
            available_amount : 0,
            borrowed_amount_wads: 0,
            cumulative_borrow_rate_wads: math::get_WAD(),
            accumulated_protocol_fees_wads: 0,
            market_price: 0,
            decimals : 0

        };

        let collateral = ReserveLP<ReserveCoin> {
            lp_coins : coin::zero<LPCoin<ReserveCoin>>(),
        };

        let reserve = Reserve<ReserveCoin> {
            name : reserve_name,
            //last_update : last_update,
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
                        borrow_fee_wad : fees,
                        host_fee_percentage : host_fee_percentage 
                    },
                    deposit_limit: deposit_limit,
                    user_deposit_limit : user_deposit_limit,
                    borrow_limit: borrow_limit,
                    fee_receiver: addr,
                    protocol_liquidation_fee: protocol_liquidation_fee,
                    protocol_take_rate: protocol_take_rate 
            }
        };

        move_to<Reserve<ReserveCoin>>(sender, reserve);
 
    }
    
    // This separate function did not work, had to move into the above function 
    // fun intialize_collateral_coin<ReserveCoin>(sender : &signer, reserve_collateral_name : String , reserve_collateral_symbol : String, collateral_decimals : u64) {
        
    //     assert!(!coin::is_coin_initialized<LPCoin<ReserveCoin>>(), ERROR_ALREADY_INITIALIZED);
    //     let (mint_capability, burn_capability) = coin::initialize<LPCoin<ReserveCoin>>(
    //         sender, reserve_collateral_name, reserve_collateral_symbol, collateral_decimals, true
    //     );
    //     coin::register_internal<LPCoin<ReserveCoin>>(sender);
    //     let lp_capability = LPCapability<ReserveCoin>{ mint_cap: mint_capability, burn_cap: burn_capability };
    //     move_to<LPCapability<ReserveCoin>>(sender, lp_capability);         
    // }

   public fun add_reserve_lp_collateral_direct<ReserveCoin> (amount : u64) : u64  acquires Reserve, LPCapability {
        let addr = kubera_config::admin_address();
        assert!(exists<Reserve<ReserveCoin>>(addr), ERROR_RESORUCE_DOES_NOT_EXISTS);
        let pool = borrow_global_mut<Reserve<ReserveCoin>>(kubera_config::admin_address());
        
        let lp_coins = &mut pool.collateral.lp_coins;

        let minted = mint_lp<ReserveCoin>(addr,amount);

        coin::merge<LPCoin<ReserveCoin>>(lp_coins, minted);
        
        coin::value(lp_coins)

   }

   fun mint_lp<ReserveCoin>(addr: address, amount: u64): coin::Coin<LPCoin<ReserveCoin>> acquires LPCapability {
        assert!(exists<LPCapability<ReserveCoin>>(addr),ERROR_RESORUCE_DOES_NOT_EXISTS);
        let liquidity_cap = borrow_global<LPCapability<ReserveCoin>>(kubera_config::admin_address());
        let mint_token = coin::mint<LPCoin<ReserveCoin>>(amount, &liquidity_cap.mint_cap);
        mint_token
    }

   public fun fetch_pool_balance<ReserveCoin>() : (u64, u64) acquires Reserve {
        let addr = kubera_config::admin_address();
        assert!(exists<Reserve<ReserveCoin>>(addr), ERROR_RESORUCE_DOES_NOT_EXISTS);
        let pool = borrow_global<Reserve<ReserveCoin>>(kubera_config::admin_address());
        let lp_coins = coin::value(&pool.collateral.lp_coins);
        let liquidity_coin = coin::value(&pool.liquidity.liquidity_coin);
        (lp_coins, liquidity_coin)
   }


    public fun deposit_liquidity_direct<ReserveCoin>(sender : &signer, liquidity_amount : u64) acquires Reserve, LPCapability {
        //first get allowed user deposit limit
        let allowed_lp_coins = get_user_deposit_limit<ReserveCoin>(signer::address_of(sender), liquidity_amount);
        // then get reserve deposit limit
        let mintable_lp_coins_limit = get_reserve_deposit_limit<ReserveCoin>(signer::address_of(sender), allowed_lp_coins);

        deposit_liquidity<ReserveCoin>(sender, mintable_lp_coins_limit, mintable_lp_coins_limit);

    }
   
    // WARNING : Need validation
    fun deposit_liquidity<ReserveCoin>(sender: &signer,liquidity_amount: u64, lp_amount : u64) acquires Reserve, LPCapability {
        assert_reserve_exists<ReserveCoin>();

        let admin_addr = kubera_config::admin_address();
        let reserve = borrow_global_mut<Reserve<ReserveCoin>>(admin_addr);


        let liquidity_coins = coin::withdraw<ReserveCoin>(sender, liquidity_amount);
        let reserve_liquidity_coin = &mut reserve.liquidity.liquidity_coin;
        coin::merge<ReserveCoin>(reserve_liquidity_coin, liquidity_coins);



        let balance_reserve_lp_coins = coin::balance<LPCoin<ReserveCoin>>(admin_addr);

        // if reserve lp balance is less, then mint the LPs and add them to reserve first;
        if (balance_reserve_lp_coins < lp_amount) {
            let lp_coins = &mut reserve.collateral.lp_coins;
            let minted = mint_lp<ReserveCoin>(admin_addr, lp_amount - balance_reserve_lp_coins );
            coin::merge<LPCoin<ReserveCoin>>(lp_coins, minted);
        };

        // // then extract the lps - this is done for the recording purpose 
        let lp_coins = &mut reserve.collateral.lp_coins;
        debug::print(lp_coins);
        let extracted_lp_coins = coin::extract<LPCoin<ReserveCoin>>(lp_coins, lp_amount);

        let sender_addr = signer::address_of(sender);

        if(!coin::is_account_registered<LPCoin<ReserveCoin>>(sender_addr)){
            coin::register_internal<LPCoin<ReserveCoin>>(sender);
        };
        coin::deposit<LPCoin<ReserveCoin>>(signer::address_of(sender), extracted_lp_coins);

   }
    /// WARNING : need validation
    public fun withdraw_liquidity<ReserveCoin>(sender : &signer, lp_amount : u64) acquires Reserve {
        assert_reserve_exists<ReserveCoin>();
        //user lp greater than zero
        assert_lp_greater_than_zero<ReserveCoin>(signer::address_of(sender));


        let admin_addr = kubera_config::admin_address();
        let balance_liquidity_coins = coin::balance<ReserveCoin>(admin_addr);
        assert!(balance_liquidity_coins > lp_amount, ERROR_INSUFFICIENT_BALANCE);

        let extractable_liquidity_coins = if (balance_liquidity_coins > lp_amount){
            lp_amount
        }
        else {
            balance_liquidity_coins
        };


        let lp_coins = coin::withdraw<LPCoin<ReserveCoin>>(sender, extractable_liquidity_coins);

        let reserve = borrow_global_mut<Reserve<ReserveCoin>>(admin_addr);
        //transfer lp coins back to reserve
        let reserve_lp_coins = &mut reserve.collateral.lp_coins;
        coin::merge<LPCoin<ReserveCoin>>(reserve_lp_coins, lp_coins);
        //transfer liquidity coins to sender
        let reserve_liquidity_coins = &mut reserve.liquidity.liquidity_coin;
        let extracted_liquidity_coins = coin::extract<ReserveCoin>(reserve_liquidity_coins, extractable_liquidity_coins);
        coin::deposit<ReserveCoin>(signer::address_of(sender), extracted_liquidity_coins);

    }


    fun assert_reserve_exists<ReserveCoin>() {
        let addr = kubera_config::admin_address();
        assert!(exists<Reserve<ReserveCoin>>(addr), ERROR_RESORUCE_DOES_NOT_EXISTS);  
    }

    fun assert_lp_greater_than_zero<ReserveCoin>(addr : address) {
        let balance_lp_coins = coin::balance<LPCoin<ReserveCoin>>(addr);
        assert!(balance_lp_coins > 0 , ERROR_INSUFFICIENT_BALANCE);

    }


    fun get_user_deposit_limit<ReserveCoin>(addr : address, requested_amount : u64): u64 acquires Reserve{
        
        assert!(exists<Reserve<ReserveCoin>>(kubera_config::admin_address()), ERROR_RESORUCE_DOES_NOT_EXISTS);

        let reserve = borrow_global<Reserve<ReserveCoin>>(kubera_config::admin_address());

        let user_deposit_limit = reserve.config.user_deposit_limit;

        let user_coin_balance = coin::balance<ReserveCoin>(addr);

        assert!(user_deposit_limit>user_coin_balance + requested_amount, ERROR_DEPOSIT_LIMIT_REACHED);

        let allowed_deposit = user_deposit_limit - (user_coin_balance + requested_amount);
        
        if(allowed_deposit > requested_amount) {
            requested_amount
        }
        else {
            allowed_deposit
        }

    } 

    fun get_reserve_deposit_limit<ReserveCoin>(addr : address, requested_amount : u64): u64 acquires Reserve{
                assert!(exists<Reserve<ReserveCoin>>(kubera_config::admin_address()), ERROR_RESORUCE_DOES_NOT_EXISTS);

        let reserve = borrow_global<Reserve<ReserveCoin>>(kubera_config::admin_address());

        let deposit_limit = reserve.config.deposit_limit;

        let user_coin_balance = coin::balance<ReserveCoin>(addr);

        assert!(deposit_limit>user_coin_balance + requested_amount, ERROR_DEPOSIT_LIMIT_REACHED);

        let allowed_deposit = deposit_limit - (user_coin_balance + requested_amount);
        
        if(allowed_deposit > requested_amount) {
            requested_amount
        }
        else {
            allowed_deposit
        }
    } 


    public fun get_total_suppy<ReserveCoin>(): u128 {
        assert!(coin::is_coin_initialized<ReserveCoin>(), ERROR_RESORUCE_DOES_NOT_EXISTS);
        option::get_with_default(&coin::supply<ReserveCoin>(),0)  
    }

    public fun exchange_rate<ReserveCoin>(total_liquidity : u128 ) : u128 {
        let total_supply = get_total_suppy<ReserveCoin>();

        let rate = if ( total_supply== 0 || total_liquidity == 0) {
            math::get_INITIAL_COLLATERAL_RATE()
        } else {
            total_supply/total_liquidity
        };

        rate
    }

    public fun collateral_to_liquidity(collateral_amount : u64, liquidity_amount : u64) : u64 {
        collateral_amount/liquidity_amount
    }   

    public fun liquidity_to_collateral(liquidity_amount: u64, collateral_amount:u64) : u64 {
        liquidity_amount * collateral_amount
    }


    // liquidity interest
    fun compound_interest<ReserveCoin>(current_borrow_rate : u64, blocks_elasped : u64, take_rate : u64)  acquires Reserve{

        let admin_addr = kubera_config::admin_address();

        assert!(exists<Reserve<ReserveCoin>>(admin_addr), ERROR_RESORUCE_DOES_NOT_EXISTS);

        let reserve = borrow_global_mut<Reserve<ReserveCoin>>(admin_addr);

        let reserve_liquidity = &mut reserve.liquidity;

        let cumulative_borrow_rate_wads = &mut reserve_liquidity.cumulative_borrow_rate_wads;

        let interest_rate = current_borrow_rate/(math::get_SLOTS_PER_YEAR());

        let compound_interest_rate =   (math::pow(((math::get_WAD() + interest_rate) as u128) , (blocks_elasped as u8)) as u64);


        *cumulative_borrow_rate_wads = *cumulative_borrow_rate_wads * (compound_interest_rate as u64);


        let borrowed_amount_wads = &mut reserve_liquidity.borrowed_amount_wads;

        let net_new_debt = *borrowed_amount_wads * compound_interest_rate - *borrowed_amount_wads;


        *borrowed_amount_wads = *borrowed_amount_wads + net_new_debt;

        let accumulated_protocol_fees_wads = &mut reserve_liquidity.accumulated_protocol_fees_wads;

        *accumulated_protocol_fees_wads = net_new_debt * take_rate +  *accumulated_protocol_fees_wads;


    } 

    //  /// Calculate the owner and host fees on borrow
    public fun calculate_borrow_fees<ReserveCoin>(
        borrow_amount: u128,
        fee_calculation: u8,
    ) : (u128, u128) acquires Reserve{

        let admin_addr = kubera_config::admin_address();

        assert!(exists<Reserve<ReserveCoin>>(admin_addr), ERROR_RESORUCE_DOES_NOT_EXISTS);

        let reserve = borrow_global<Reserve<ReserveCoin>>(admin_addr);

        let reserve_config = &reserve.config;

        let borrow_fee_wad = &reserve_config.fees.borrow_fee_wad;

        let host_fee_percentage = &reserve_config.fees.host_fee_percentage;


        calculate_fees(borrow_amount, *borrow_fee_wad , fee_calculation, *host_fee_percentage)
    }


    //reserve config 

   // public fun calculate_borrow_fees(borrow_amount : u128)

   fun calculate_fees(amount : u128, fee_wad : u64, fee_calculation : u8, host_fee_percentage : u8 ): (u128, u128) {
        let borrow_fee_rate = fee_wad;
        let host_fee_rate = host_fee_percentage; 

        if(borrow_fee_rate > 0 && amount > 0) {
            let need_to_assess_host_fee = host_fee_rate > 0;
            let minimum_fee = if(need_to_assess_host_fee) {
                2u64 // 1 token to owner, 1 to host
            } else {
                1u64 // 1 token to owner, nothing else
            };

            let borrow_fee_amount  = if( fee_calculation == kubera_config::EXCLUSIVE_()){
                // Calculate fee to be added to borrow: fee = amount * rate
                amount * (borrow_fee_rate as u128)
                
            }
            else if( fee_calculation == kubera_config::INCLUSIVE_()){
                // Calculate fee to be subtracted from borrow: fee = amount * (rate / (rate + 1))
                let borrow_fee_rate = borrow_fee_rate / (borrow_fee_rate + math::get_WAD());
                amount *  (borrow_fee_rate as u128)
               
            } else {
                0
            };

            assert!(borrow_fee_amount > 0 , ERROR_BORROW_AMOUNT_IS_TOO_SMALL);
        

            let borrow_fee_decimal =  math::max(borrow_fee_amount,(minimum_fee as u128)); 
            
            assert!(borrow_fee_decimal < amount, ERROR_BORROW_AMOUNT_IS_TOO_SMALL);
            

            let borrow_fee = borrow_fee_decimal;
            let host_fee = if(need_to_assess_host_fee) {
                math::max(borrow_fee_decimal * (host_fee_rate as u128) , 1u128)
                    
            } else {
                0
            };

            (borrow_fee, host_fee)
        } else {
            (0, 0)
        }


   }


 

}