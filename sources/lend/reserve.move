module kubera::reserve {

    use std::string::{String};
    use aptos_framework::coin;
    //use aptos_framework::coins;
    use std::signer;
    use kubera::kubera_config;
    use kubera::base::LPCoin;
    use aptos_framework::timestamp;
   // use aptos_framework::account;
   //use std::debug;
   //use std::option::{Self};
   use kubera::math;



    struct Reserve<phantom ReserveCoin> has key{
        name : String,
        last_update : LastUpdate, 
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

    const ERROR_UNAUTHORIZED:u64 = 2004;
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

       let last_update = LastUpdate {
          block_timestamp_last :  timestamp::now_seconds()
       };

        // INitialize store for LP Coin 
       assert!(!coin::is_coin_initialized<LPCoin<ReserveCoin>>(), ERROR_ALREADY_INITIALIZED);
        let (mint_capability, burn_capability) = coin::initialize<LPCoin<ReserveCoin>>(
            sender, reserve_collateral_name, reserve_collateral_symbol, reserve_collateral_decimals, true
        );
        coin::register<LPCoin<ReserveCoin>>(sender);
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

    fun burn_lp_from<ReserveCoin>(addr : address, amount : u64) acquires LPCapability  {
        assert!(exists<LPCapability<ReserveCoin>>(addr),ERROR_RESORUCE_DOES_NOT_EXISTS);
        let liquidity_cap = borrow_global<LPCapability<ReserveCoin>>(kubera_config::admin_address());
        coin::burn_from<LPCoin<ReserveCoin>>(addr, amount, &liquidity_cap.burn_cap);
    }

    fun burn_lp<ReserveCoin>(addr: address,coin : coin::Coin<LPCoin<ReserveCoin>>) acquires LPCapability {
        assert!(exists<LPCapability<ReserveCoin>>(addr),ERROR_RESORUCE_DOES_NOT_EXISTS);
        let liquidity_cap = borrow_global<LPCapability<ReserveCoin>>(kubera_config::admin_address());
        coin::burn<LPCoin<ReserveCoin>>(coin, &liquidity_cap.burn_cap);

    }

   public fun fetch_liquidity_balance<ReserveCoin>() : (u64, u64) acquires Reserve {
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

         deposit_liquidity<ReserveCoin>(sender, mintable_lp_coins_limit);

    }
   
    // WARNING : Need validation
    fun deposit_liquidity<ReserveCoin>(sender: &signer,amount: u64) acquires Reserve, LPCapability {
        assert_reserve_exists<ReserveCoin>();

        let admin_addr = kubera_config::admin_address();
        let reserve = borrow_global_mut<Reserve<ReserveCoin>>(admin_addr);


        let liquidity_coins = coin::withdraw<ReserveCoin>(sender, amount);
        let reserve_liquidity_coin = &mut reserve.liquidity.liquidity_coin;
        coin::merge<ReserveCoin>(reserve_liquidity_coin, liquidity_coins);



        let balance_reserve_lp_coins = coin::balance<LPCoin<ReserveCoin>>(admin_addr);

        // if reserve lp balance is less, then mint the LPs and add them to reserve first;
        if (balance_reserve_lp_coins < amount) {
            let lp_coins = &mut reserve.collateral.lp_coins;
            let minted = mint_lp<ReserveCoin>(admin_addr, amount - balance_reserve_lp_coins );
            coin::merge<LPCoin<ReserveCoin>>(lp_coins, minted);
        };

        // // then extract the lps - this is done for the recording purpose 
        let lp_coins = &mut reserve.collateral.lp_coins;
        //debug::print(lp_coins);
        let extracted_lp_coins = coin::extract<LPCoin<ReserveCoin>>(lp_coins, amount);

        let sender_addr = signer::address_of(sender);

        if(!coin::is_account_registered<LPCoin<ReserveCoin>>(sender_addr)){
            coin::register<LPCoin<ReserveCoin>>(sender);
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

    // public fun deposit_to_admin_wallet<ReserveCoin>(sender : &signer, amount : u64) acquires Reserve{
    //     let admin = kubera_config::admin_address();

    //     assert!(signer::address_of(sender) == admin, ERROR_UNAUTHORIZED);

    //     let reserve = borrow_global_mut<Reserve<ReserveCoin>>(admin);

    //     let liquidity = &mut reserve.liquidity;

    //     let reserve_coins = coin::extract<ReserveCoin>(&mut liquidity.liquidity_coin, amount);

    //     coin::deposit<ReserveCoin>(admin, reserve_coins);

    // }


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


    public fun get_total_liquidity_suppy<ReserveCoin>(): u128 acquires Reserve{
        assert!(coin::is_coin_initialized<ReserveCoin>(), ERROR_RESORUCE_DOES_NOT_EXISTS);

        let admin_addr = kubera_config::admin_address();

        let reserve = borrow_global<Reserve<ReserveCoin>>(admin_addr);
        let liquidity = &reserve.liquidity;
        let reserve_coin = &liquidity.liquidity_coin;

        let balance = coin::value<ReserveCoin>(reserve_coin);

        (balance as u128) 
    }

    public fun total_supply<ReserveCoin>() : u64 acquires Reserve{
        assert_reserve_exists<ReserveCoin>();

        let admin_addr = kubera_config::admin_address();

        let reserve = borrow_global<Reserve<ReserveCoin>>(admin_addr);

        let available_amount = reserve.liquidity.available_amount;

        let borrowed_amount_wads = reserve.liquidity.borrowed_amount_wads;

        let accumulated_protocol_fees_wads  = reserve.liquidity.accumulated_protocol_fees_wads;

        available_amount+ borrowed_amount_wads - accumulated_protocol_fees_wads
    }

    public fun exchange_rate<ReserveCoin>(total_liquidity : u128 ) : u128 acquires Reserve{
        let total_supply = get_total_liquidity_suppy<ReserveCoin>();

        let rate = if ( total_supply== 0 || total_liquidity == 0) {
            math::get_INITIAL_COLLATERAL_RATE()
        } else {
            total_supply/total_liquidity
        };

        rate
    }

    
    public fun collateral_exchange_rate<ReserveCoin>():u128 acquires Reserve{
        let total_liquidity  = (total_supply<ReserveCoin>() as u128);
        exchange_rate<ReserveCoin>(total_liquidity)
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


    public fun repay<ReserveCoin>(repay_amount : u64, settle_amount : u64) acquires Reserve{
        assert_reserve_exists<ReserveCoin>();

        let admin_addr = kubera_config::admin_address();

        let reserve = borrow_global_mut<Reserve<ReserveCoin>>(admin_addr);

        let available_amount = &mut reserve.liquidity.available_amount;

        *available_amount = *available_amount + repay_amount;

        let borrowed_amount_wads = &mut reserve.liquidity.borrowed_amount_wads;


        let safe_settle_amount = math::min(settle_amount , *borrowed_amount_wads);

        *borrowed_amount_wads = *borrowed_amount_wads - safe_settle_amount;


    }


    public fun redeem_fees<ReserveCoin>(withdraw_amount : u64) acquires Reserve{
        assert_reserve_exists<ReserveCoin>();

        let admin_addr = kubera_config::admin_address();

        let reserve = borrow_global_mut<Reserve<ReserveCoin>>(admin_addr);

        let available_amount = &mut reserve.liquidity.available_amount;

        *available_amount = *available_amount - withdraw_amount;

        let accumulated_protocol_fees_wads = &mut reserve.liquidity.accumulated_protocol_fees_wads;

        *accumulated_protocol_fees_wads = *accumulated_protocol_fees_wads - withdraw_amount;
        
    }
    

    public fun utilization_rate<ReserveCoin>() : u64 acquires Reserve{
        assert_reserve_exists<ReserveCoin>();
    
        let total_supply = total_supply<ReserveCoin>();

        if(total_supply == 0){
            0
        } else {
            let admin_addr = kubera_config::admin_address();
            let reserve = borrow_global<Reserve<ReserveCoin>>(admin_addr);

            let borrowed_amount_wads = reserve.liquidity.borrowed_amount_wads;

            borrowed_amount_wads/ total_supply    
        }
    }


   public fun redeem_collateral<ReserveCoin>(sender: &signer, collateral_amount : u64) acquires Reserve, LPCapability {
        assert_reserve_exists<ReserveCoin>();
        let sender_addr = signer::address_of(sender);

        assert!(coin::is_account_registered<LPCoin<ReserveCoin>>(sender_addr), ERROR_INSUFFICIENT_BALANCE);
        let sender_lp_coins = coin::withdraw<LPCoin<ReserveCoin>>(sender, collateral_amount);
        burn_lp<ReserveCoin>(sender_addr,sender_lp_coins) ;

        // get liquidity to deposit to sender
        let collateral_exchange_rate = collateral_exchange_rate<ReserveCoin>();
        let liquidity_amount = collateral_to_liquidity(collateral_amount, (collateral_exchange_rate as u64));

        // get liqudiity
        let admin_addr = kubera_config::admin_address();
        let reserve = borrow_global_mut<Reserve<ReserveCoin>>(admin_addr);
        let liquidity_coins = &mut reserve.liquidity.liquidity_coin;

        // extract reserve coins
        let extracted_liquidity_coins = coin::extract<ReserveCoin>(liquidity_coins, liquidity_amount);

        // now deposit
        coin::deposit<ReserveCoin>(sender_addr, extracted_liquidity_coins);

    }


    /// Calculate the current borrow rate
    public fun current_borrow_rate<ReserveCoin>() : u128 acquires Reserve{

        assert_reserve_exists<ReserveCoin>();
        let utilization_rate = utilization_rate<ReserveCoin>();

        let admin_addr = kubera_config::admin_address();
        let reserve = borrow_global<Reserve<ReserveCoin>>(admin_addr);

        let optimal_utilization_rate = reserve.config.optimal_utilization_rate; 
        let optimal_borrow_rate = reserve.config.optimal_borrow_rate;

        let optimal_utilization_rate: u128 = (math::from_percent(optimal_utilization_rate) as u128);
        let low_utilization : bool = (utilization_rate as u128)< optimal_utilization_rate;
        if(low_utilization || optimal_utilization_rate  == 100){

            let min_borrow_rate = reserve.config.min_borrow_rate;

            let normalized_rate = (utilization_rate<ReserveCoin>() as u128) / optimal_utilization_rate;
            let min_rate = math::from_percent(min_borrow_rate);
            let rate_range = math::from_percent(optimal_borrow_rate - min_borrow_rate);
            

            (normalized_rate * rate_range) + min_rate
        } else {

            let max_borrow_rate = reserve.config.max_borrow_rate;
            if(optimal_borrow_rate == max_borrow_rate) {
                let rate = math::from_percent(50u8);
                if(max_borrow_rate == 251u8) {
                    rate = rate * 6;
                };
                if(max_borrow_rate == 252u8) {
                    rate = rate * 7;
                };
                 if(max_borrow_rate == 253u8) {
                    rate = rate * 8;
                };
                 if(max_borrow_rate == 254u8) {
                    rate = rate * 10;
                };
                 if(max_borrow_rate == 255u8) {
                    rate = rate * 12;
                };
                if(max_borrow_rate == 250u8) {
                    rate = rate * 20;
                };
                 if(max_borrow_rate == 249u8) {
                    rate = rate * 30;
                };
                 if(max_borrow_rate == 248u8) {
                    rate = rate * 40;
                };

                if(max_borrow_rate == 247u8) {
                    rate = rate *50;
                };
                
                rate
                
            } else {
                let normalized_rate = ((utilization_rate as u128)- optimal_utilization_rate)/ math::from_percent( 100u8 - (optimal_utilization_rate as u8));
                        
                
                let min_rate = math::from_percent(optimal_borrow_rate);
                let rate_range = math::from_percent(max_borrow_rate - optimal_borrow_rate);

                (normalized_rate * rate_range)+ min_rate
            }          
        }
    }

    /// Update borrow rate and accrue interest
    public fun accrue_interest<ReserveCoin>(current_timestamp: u64) acquires Reserve{        
        assert_reserve_exists<ReserveCoin>();
        let admin_addr = kubera_config::admin_address();

        let reserve = borrow_global<Reserve<ReserveCoin>>(admin_addr);

        let last_update = reserve.last_update.block_timestamp_last;

        let time_elapsed = current_timestamp - last_update;
        if(time_elapsed > 0) {
            let take_rate = math::from_percent(reserve.config.protocol_take_rate);
            let current_borrow_rate  = current_borrow_rate<ReserveCoin>() ;
            compound_interest<ReserveCoin>((current_borrow_rate as u64), (time_elapsed as u64), (take_rate as u64));
        }   
    }



    /// Repay liquidity up to the borrowed amount
    public fun calculate_repay(
        amount_to_repay: u64,
        borrowed_amount: u128,
    ):u128 {
        let settle_amount = if(amount_to_repay == math::u64_MAX()) {
            borrowed_amount
        } else {
             math::min_128((amount_to_repay as u128), borrowed_amount)
        };
        
        settle_amount                
    }


        /// Calculate protocol cut of liquidation bonus always at least 1 lamport
    public fun calculate_protocol_liquidation_fee<ReserveCoin>(amount_liquidated: u64,):u64 acquires Reserve {

        assert_reserve_exists<ReserveCoin>();
        let admin_addr = kubera_config::admin_address();
        let reserve = borrow_global<Reserve<ReserveCoin>>(admin_addr);

        let liquidation_bonus = reserve.config.liquidation_bonus;
        let protocol_liquidation_fee = reserve.config.protocol_liquidation_fee;

        let bonus_rate = math::from_percent(liquidation_bonus) + (math::get_WAD() as u128);
        let amount_liquidated_wads = (amount_liquidated as u128);

        let bonus = amount_liquidated_wads  - ((amount_liquidated_wads as u128)/ bonus_rate);

        // After deploying must update all reserves to set liquidation fee then redeploy with this line instead of hardcode
         let protocol_fee = math::max(bonus * (math::from_percent(protocol_liquidation_fee)), 1);
        //let protocol_fee = math::max(bonus * math::from_percent(0), 1);
        (protocol_fee as u64)
    }


     /// Calculate protocol fee redemption accounting for availible liquidity and accumulated fees
    public  fun calculate_redeem_fees<ReserveCoin>():u64  acquires Reserve{
        assert_reserve_exists<ReserveCoin>();
        let admin_addr = kubera_config::admin_address();
        let reserve = borrow_global<Reserve<ReserveCoin>>(admin_addr);

        let available_amount = reserve.liquidity.available_amount;
        let accumulated_protocol_fees_wads = reserve.liquidity.accumulated_protocol_fees_wads;
        
        math::min(available_amount,accumulated_protocol_fees_wads)
    }
 
    

}