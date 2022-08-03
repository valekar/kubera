module kubera::reserve_script {

    use kubera::reserve::{Self};
    use std::string::{String};
    
    //use std::debug;

    public entry fun init_reserve_script<ReserveCoin>(
        admin : &signer , 
        reserve_name : String, 
        reserve_collateral_name : String, 
        reserve_collateral_symbol : String,
        collateral_decimals : u64, 
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
        reserve::create_reserve<ReserveCoin>(
            admin, 
            reserve_name, 
           reserve_collateral_name, 
           reserve_collateral_symbol,
           collateral_decimals , 
            optimal_utilization_rate ,
            loan_to_value_ratio ,
            liquidation_bonus ,
            liquidation_threshold,
            min_borrow_rate,
            optimal_borrow_rate,
            max_borrow_rate,
            fees ,
            host_fee_percentage,
            deposit_limit,
            user_deposit_limit,
            borrow_limit,
            protocol_liquidation_fee,
            protocol_take_rate
        );        

    }

    #[test_only]
    use kubera::mock_coin;
    #[test_only]    
    use std::string::{Self};
    #[test_only]
    use kubera::base;
    #[test_only]
    use std::debug;
    // #[test_only]
    // use aptos_framework::coin;
    // #[test_only]
    // use aptos_framework::signer;

    #[test(source = @kubera)]
    public entry fun init_reserve_test(source : &signer) {
        init_reserve(source);

        //debug::print_stack_trace();

        let (collateral_coin, reserve_coin) = reserve::fetch_liquidity_balance<mock_coin::WETH>();

        assert!(collateral_coin == 0, 1); 
        assert!(reserve_coin == 0 , 1);

         reserve::add_reserve_lp_collateral_direct<mock_coin::WETH>(10);

        let (collateral_coin, reserve_coin) = reserve::fetch_liquidity_balance<mock_coin::WETH>();

        assert!(collateral_coin == 10, 1); 
        assert!(reserve_coin == 0 , 1);

    }

    
    #[test(source = @kubera, end_user =  @0x123)]
    public entry fun get_total_liquidity_suppy_test(source : &signer, end_user : &signer) {
        init_reserve(source);

       // let addr = signer::address_of(source);

        let supply = reserve::get_total_liquidity_suppy<mock_coin::WETH>();
        //debug::print(&supply);
        assert!(supply == 0, 1);



        // mint some WETH coins to end user
        mock_coin::faucet_mint_to_script<mock_coin::WETH>(end_user, 8);
        reserve::deposit_liquidity_direct<mock_coin::WETH>(end_user, 5);

        let supply = reserve::get_total_liquidity_suppy<mock_coin::WETH>();
        debug::print( &supply);
        assert!(supply == 5, 1);

    }


    fun init_reserve(source : &signer) {
        base::setup_timestamp(source);
        mock_coin::initialize<mock_coin::WETH>(source, 50);
        init_reserve_script<mock_coin::WETH>(
            source,
            string::utf8(b"WETH Reserve"), 
            string::utf8(b"LPCoin"), 
            string::utf8(b"LPWETH"),
            8, 2, 6, 1, 80, 10, 13, 50, 10, 2,100, 100,80, 2, 1
        );
    }

}