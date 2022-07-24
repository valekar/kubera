module kubera::PoolScript {

    use kubera::pool::{Self};
    use std::string::{String,Self};
    use kubera::MockCoin;

    //use std::debug;

    public entry fun init_reserve<ReserveCoin>(
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
        deposit_limit: u64,
        user_deposit_limit : u64,
        borrow_limit: u64,
        protocol_liquidation_fee: u8,
        protocol_take_rate: u8
        ) {
        pool::create_reserve<ReserveCoin>(
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
            deposit_limit,
            user_deposit_limit,
            borrow_limit,
            protocol_liquidation_fee,
            protocol_take_rate
        );        

    }

    #[test(source = @kubera)]
    public entry fun init_reserve_test(source : signer) {
        MockCoin::initialize<MockCoin::WETH>(&source, 8);
        init_reserve<MockCoin::WETH>(
            &source,
            string::utf8(b"WETH Reserve"), 
            string::utf8(b"LPCoin"), 
            string::utf8(b"LPWETH"),
            8, 2, 6, 1, 80, 10, 13, 50, 10, 100, 100,80, 2, 1
        );

        //debug::print_stack_trace();

        let (collateral_coin, reserve_coin) = pool::fetch_pool_balance<MockCoin::WETH>();

        assert!(collateral_coin == 0, 1); 
        assert!(reserve_coin == 0 , 1);

         pool::add_reserve_lp_collateral_direct<MockCoin::WETH>(10);

        let (collateral_coin, reserve_coin) = pool::fetch_pool_balance<MockCoin::WETH>();

        assert!(collateral_coin == 10, 1); 
        assert!(reserve_coin == 0 , 1);

    }


}