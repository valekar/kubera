module kubera::obligation_script {

    use kubera::obligation;
    use std::debug;
    use std::signer;


    public entry fun init_obligation_script<ReserveCoin>(sender : &signer, version : u8) : address {
       let resource_addr = obligation::create_obligation<ReserveCoin>(sender, version);
        debug::print(&resource_addr);
        resource_addr

    }

    public entry fun init_obligation_store_script(admin : &signer) {
        obligation::init_obligation_store(admin);
    }

    public entry fun get_obligator_resource_script(sender_addr : address) : address {
        obligation::get_obligator_resource(sender_addr)
    }



    #[test_only]
    use kubera::mock_coin;

    #[test(admin = @kubera, end_user = @0x4 )]
    public fun test_obligation(admin:&signer, end_user : &signer) {

        init_obligation_store_script(admin);

        let version = 1;
        mock_coin::initialize<mock_coin::WETH>(admin, 8);
        let resource_addr = init_obligation_script<mock_coin::WETH>(end_user, version);

        let stored_addr = get_obligator_resource_script(signer::address_of(end_user));  

        assert!(stored_addr == resource_addr, 2);
        assert!(@0x1 != stored_addr, 1 );

    } 



}