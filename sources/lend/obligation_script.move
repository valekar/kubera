module kubera::obligation_script {

    use kubera::obligation;
    //use std::debug;


    public entry fun init_obligation_script<ReserveCoin>(sender : &signer, version : u8) : address {
       let resource_addr = obligation::init_new_obligation<ReserveCoin>(sender, version);
        //debug::print(&resource_addr);
        resource_addr

    }

    public entry fun init_obligation_store_script<ReserveCoin>(admin : &signer) {
        obligation::init_obligation_store<ReserveCoin>(admin);
    }

    public entry fun get_obligator_resource_script<ReserveCoin>(sender_addr : address) : address {
        obligation::get_obligator_resource<ReserveCoin>(sender_addr)
    }


    public entry fun deposit_script<ReserveCoin>(sender : &signer , deposit_amount : u64) {
        obligation::deposit<ReserveCoin>(sender, deposit_amount);
    }



    #[test_only]
    use kubera::mock_coin;
    #[test_only]
    use std::signer;
    #[test_only]
    use std::string;
    #[test_only]
    use kubera::reserve_script;
    #[test_only]
    use aptos_framework::coin;
    #[test_only]
    use kubera::base;



    #[test(admin = @kubera, end_user = @0x4 )]
    public fun test_obligation(admin:&signer, end_user : &signer) {

        mock_coin::initialize<mock_coin::WETH>(admin, 8);

        init_obligation_store_script<mock_coin::WETH>(admin);
        
        let version = 1;
        let resource_addr = init_obligation_script<mock_coin::WETH>(end_user, version);

        let stored_addr = get_obligator_resource_script<mock_coin::WETH>(signer::address_of(end_user));  

        assert!(stored_addr == resource_addr, 2);
        assert!(@0x1 != stored_addr, 1 );

    } 

    #[test(admin = @kubera, end_user = @0x4 )]
    #[expected_failure]
    public fun test_init_obligation_twice(admin:&signer, end_user : &signer) {
        base::setup_timestamp(admin);

        mock_coin::initialize<mock_coin::WETH>(admin, 8);
        init_obligation_store_script<mock_coin::WETH>(admin);

        let version = 1;
        let _ = init_obligation_script<mock_coin::WETH>(end_user, version);
        init_obligation_script<mock_coin::WETH>(end_user, version);
    }


    #[test(admin = @kubera,end_user = @0x63)]
    public fun test_deposit(admin : &signer, end_user : &signer) {
        
        base::setup_timestamp(admin);
        
        // initiate the reserce (liquidity)
        initiate_reserve(admin);
    
        // initiate the obligation
        init_obligation_store_script<mock_coin::WETH>(admin);
        let version = 1;
        let _ = init_obligation_script<mock_coin::WETH>(end_user, version);

        // mint some WETH coins to end user
        mock_coin::faucet_mint_to_script<mock_coin::WETH>(end_user, 8);
        let weth_balance = coin::balance<mock_coin::WETH>(signer::address_of(end_user));
        assert!(weth_balance == 8, 2);

        // Now deposit the WETH into obligation
        deposit_script<mock_coin::WETH>(end_user, 2);

        let (a, b,c) = obligation::get_obligation_deposit_collateral_balance<mock_coin::WETH>(end_user);

        assert!(a == 2, 1);
        assert!(b ==  2, 4);
        assert!(c == 2 , 2);

    }

    #[test_only]
    fun initiate_reserve(admin : &signer){
        mock_coin::initialize<mock_coin::WETH>(admin, 8);
        reserve_script::init_reserve_script<mock_coin::WETH>(
            admin,
            string::utf8(b"WETH Reserve"), 
            string::utf8(b"LPCoin"), 
            string::utf8(b"LPWETH"),
            8, 2, 6, 1, 80, 10, 13, 50, 10, 2 ,100, 100,80, 2, 1
        );
    }
}