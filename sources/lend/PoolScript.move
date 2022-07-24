module Kubera::PoolScript {

    use Kubera::Pool;
    use Std::ASCII;
    use Kubera::MockCoin;

    public entry fun init_reserve<ReserveCoin>(
        admin : &signer , 
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
        Pool::create_reserve<ReserveCoin>(
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
            borrow_limit,
            protocol_liquidation_fee,
            protocol_take_rate
        );        

    }


    #[test(source = @0x1)]
    public entry fun init_reserve_test(source : signer) {
        MockCoin::initialize<MockCoin::WETH>(&source, 8);
        init_reserve<MockCoin::WETH>(
            &source,
            ASCII::string(b"WETH Reserve"),
            ASCII::string(b"LPCoin"),
             ASCII::string(b"LPWETH"),
        8, 
        2,
        6,
       1,
        80,
        10,
        13,
        50,
        10,
        100,
        80,
        2,
        1
        );
    }


}