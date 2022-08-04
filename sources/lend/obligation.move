/**
Design thinking -

    We use ObligationStore for storing who has obligated with @kubera protocol
    

*/
module kubera::obligation {

    use aptos_framework::coin;
    use aptos_framework::coins;
    use kubera::base::LPCoin;
    use std::signer;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::table::{Table, Self};
    use kubera::kubera_config;
    use aptos_framework::type_info::{TypeInfo,type_of};
    use aptos_framework::account::create_signer_with_capability;

    //reserve
    use kubera::reserve;

    
    const MAX_OBLIGATION_RESERVES: u8 = 10;
    const OBLIGATION_PRECISION : u64 = 1000000;
    const ERROR_OBLIGATION_NOT_INITIALIZED:u64 = 1;
    const ERROR_NOT_AUTHORISED:u64 = 2;
    const ERROR_OBLIGATION_ALREADY_INITIALIZED:u64 = 2;
    const ERROR_OBLIGATION_STORE_NOT_INITIALIZED:u64 = 3;


    struct Obligation<phantom ReserveCoin> has key{
        /// Version of the struct
        version : u8,
        // /// Last update to collateral, liquidity, or their market values
        //last_update : LastUpdate,
        /// Owner authority which can borrow liquidity
        owner : address,
         /// Deposited collateral for the obligation, unique by deposit lp coin
        deposits : Table<TypeInfo, ObligationCollateral<LPCoin<ReserveCoin>>>,
        /// Borrowed liquidity for the obligation, unique by borrow reserve coin
        borrows : Table<TypeInfo, ObligationLiquidity<ReserveCoin>>,
         /// Market value of deposits
        deposited_value: u128,
        /// Market value of borrows
         borrowed_value: u128,
        /// The maximum borrow value at the weighted average loan to value ratio
         allowed_borrow_value: u128,
        /// The dangerous borrow value at the weighted average liquidation threshold
         unhealthy_borrow_value: u128,
        /// signer capability
         obligation_signer_cap : SignerCapability

    }

     struct LastUpdate has store{
        block_timestamp_last : u64,
    }

    struct ObligationCollateral<phantom LPCoin>  has store {
        /// Amount of collateral deposited
        deposited_amount : u64,
        /// Collateral market value in quote currency
        market_value : u128,
        // User collateral is deposited to
        //deposit_lp_coin : coin::Coin<LPCoin>
    }


    struct ObligationLiquidity<phantom ReserveCoin> has store {
        /// Reserve liquidity is borrowed from
        borrow_reserve_coin : coin::Coin<ReserveCoin>,
        /// Borrow rate used for calculating interest
        cumulative_borrow_rate_wads : u128,
        /// Amount of liquidity borrowed plus interest
        borrowed_amount_wads : u128,
        /// Liquidity market value in quote currency
        market_value : u128,
    }

    

    // obligators - Table <senderAddress, ResourceAddress>
    // ResourceAddress - This is where we keep new Obligations - This resource address is owned by this module.
    // This is designed in this way because if there arises liquidation, then module could liquidate the user 

    // multiple obligations could be created by one user
    struct ObligationStore<phantom ReserveCoin> has key {
        obligators :  Table<address, address>
    }


    public fun init_obligation_store<ReserveCoin>(admin : &signer) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @kubera, ERROR_NOT_AUTHORISED);
        if(!exists<ObligationStore<ReserveCoin>>(admin_addr)){
            move_to(admin , ObligationStore<ReserveCoin> {
                obligators : table::new<address, address>()
            })
        } 
    }

    // create new obligation
    public fun init_new_obligation<ReserveCoin>(sender : &signer, version : u8) : address  acquires ObligationStore {

        let admin_addr = kubera_config::admin_address();
        assert!(exists<ObligationStore<ReserveCoin>>(admin_addr), ERROR_OBLIGATION_NOT_INITIALIZED);
        
        // create resource account 
        let (obligation_signer, obligation_signer_cap) = 
            account::create_resource_account(sender, b"obligation");

        assert!(!exists<Obligation<ReserveCoin>>(signer::address_of(&obligation_signer)), 
                    ERROR_OBLIGATION_ALREADY_INITIALIZED);

        let obligation = Obligation<ReserveCoin> {
            version : version,
            owner : signer::address_of(sender),
            deposits : table::new<TypeInfo, ObligationCollateral<LPCoin<ReserveCoin>>>(),
            borrows : table::new<TypeInfo, ObligationLiquidity<ReserveCoin>>(),
            deposited_value : 0,
            borrowed_value : 0,
            allowed_borrow_value : 0,
            unhealthy_borrow_value : 0,
            obligation_signer_cap : obligation_signer_cap

        };
        // move the obligation resource to module_addr()
        move_to(&obligation_signer, obligation);

        // store the sender_addr, Resource address in the ObligationStore
        let obligation_resource_addr = signer::address_of(&obligation_signer);
        let obligation_store = borrow_global_mut<ObligationStore<ReserveCoin>>(admin_addr);
        let obligators = &mut obligation_store.obligators;
        table::add(obligators, signer::address_of(sender), obligation_resource_addr);


        obligation_resource_addr

    }

    public fun get_obligator_resource<ReserveCoin>(addr : address) : address  acquires ObligationStore{
        let admin_addr = kubera_config::admin_address();
        assert!(exists<ObligationStore<ReserveCoin>>(admin_addr), ERROR_OBLIGATION_STORE_NOT_INITIALIZED);
        
        let obligation_store = borrow_global<ObligationStore<ReserveCoin>>(admin_addr);
        let obligators = &obligation_store.obligators;

        *table::borrow<address, address>(obligators, addr)
    }


    fun deposit_collateral<ReserveCoin>(sender : &signer, resource_addr : address, deposit_amount : u64) acquires Obligation{

        assert!(exists<Obligation<ReserveCoin>>(resource_addr), ERROR_OBLIGATION_NOT_INITIALIZED);
        let obligation = borrow_global_mut<Obligation<ReserveCoin>>(resource_addr);

        let resource_signer = create_signer_with_capability(&obligation.obligation_signer_cap);

        let deposits = &mut obligation.deposits;

        let lp_coins = coin::withdraw<LPCoin<ReserveCoin>>(sender, deposit_amount);
        
        if(table::contains<TypeInfo, ObligationCollateral<LPCoin<ReserveCoin>>>(deposits, type_of<ReserveCoin>())) {
            // check if user already deposited, if yes, then update 
            let obligation_collateral =  table::borrow_mut<TypeInfo, 
                ObligationCollateral<LPCoin<ReserveCoin>>>(deposits, type_of<ReserveCoin>());

            let deposited_amount = &mut obligation_collateral.deposited_amount;
            *deposited_amount  = *deposited_amount + deposit_amount;

            //let deposit_lp_coins = &mut obligation_collateral.deposit_lp_coin;
           // coin::merge<LPCoin<ReserveCoin>>(deposit_lp_coins, lp_coins);

            coin::deposit<LPCoin<ReserveCoin>>(resource_addr, lp_coins);

            let market_value = &mut obligation_collateral.market_value;
            *market_value = *market_value + (deposit_amount as u128);

  
        } else {

             if(!coin::is_account_registered<LPCoin<ReserveCoin>>(resource_addr)){
                coins::register<LPCoin<ReserveCoin>>(&resource_signer);
            };
            coin::deposit<LPCoin<ReserveCoin>>(resource_addr, lp_coins);
            
            // else create new obligation collateral
            let obligation_collateral = ObligationCollateral<LPCoin<ReserveCoin>>{
                deposited_amount : deposit_amount,
                market_value : (deposit_amount as u128),
            };
            table::add<TypeInfo, ObligationCollateral<LPCoin<ReserveCoin>>>(deposits, type_of<ReserveCoin>() , obligation_collateral);
        };
    }

    /**
        1. First deposit the reserve coin into liquidity
        2. This deposition will result in LP COIN deposition to this method initiater
        3. Then deposit those LPCOIN as obligation into the obligation stat 
    */
    public fun deposit<ReserveCoin>(sender : &signer, deposit_amount : u64) acquires Obligation, ObligationStore{
        //1. 
        reserve::deposit_liquidity_direct<ReserveCoin>(sender, deposit_amount);
        // get resource addr from the obligation store
        let resource_addr = get_obligator_resource<ReserveCoin>(signer::address_of(sender));  
        //3. deposit LP coins  
        deposit_collateral<ReserveCoin>(sender, resource_addr, deposit_amount); 
    }


    public fun get_obligation_deposit_collateral_balance<ReserveCoin>(sender : &signer):(u64, u128, u64) acquires Obligation, ObligationStore {
        let resource_addr = get_obligator_resource<ReserveCoin>(signer::address_of(sender));
        
        assert!(exists<Obligation<ReserveCoin>>(resource_addr), ERROR_OBLIGATION_NOT_INITIALIZED);

        let obligation = borrow_global<Obligation<ReserveCoin>>(resource_addr);
        let deposits = &obligation.deposits;

        if(table::contains<TypeInfo, ObligationCollateral<LPCoin<ReserveCoin>>>(deposits, type_of<ReserveCoin>())) {
            let lp_balance = coin::balance<LPCoin<ReserveCoin>>(resource_addr);

            let obligation = table::borrow<TypeInfo, 
                ObligationCollateral<LPCoin<ReserveCoin>>>(deposits, type_of<ReserveCoin>());
            (obligation.deposited_amount, obligation.market_value,lp_balance)          
        } else {
            (0,0,0) 
        }
    }

    
}