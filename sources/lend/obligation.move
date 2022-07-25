module kubera::obligation {

    use std::vector;
    use aptos_framework::coin;
    use kubera::base::LPCoin;
    use std::signer;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::table::{Table, Self};
    use kubera::kubera_config;

    const MAX_OBLIGATION_RESERVES: u8 = 10;
    const OBLIGATION_PRECISION : u64 = 1000000;
    const ERROR_OBLIGATION_NOT_INITIALIZED:u64 = 1;
    const ERROR_NOT_AUTHORISED:u64 = 2;




    struct Obligation<phantom ReserveCoin> has key{
        /// Version of the struct
        version : u8,
        // /// Last update to collateral, liquidity, or their market values
        //last_update : LastUpdate,
        /// Owner authority which can borrow liquidity
        owner : address,
         /// Deposited collateral for the obligation, unique by deposit lp coin
        deposits : vector<ObligationCollateral<LPCoin<ReserveCoin>>>,
        /// Borrowed liquidity for the obligation, unique by borrow reserve coin
        borrows : vector<ObligationLiquidity<ReserveCoin>>,
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
        /// User collateral is deposited to
        deposit_lp_coin : coin::Coin<LPCoin>
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


    struct ObligationStore has key {
        obligators :  Table<address, address>
    }


    public fun init_obligation_store(admin : &signer) {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @kubera, ERROR_NOT_AUTHORISED);
        if(!exists<ObligationStore>(admin_addr)){
            move_to(admin , ObligationStore {
                obligators : table::new<address, address>()
            })
        } 
    }

    public fun create_obligation<ReserveCoin>(sender : &signer, version : u8) : address  acquires ObligationStore {

        let admin_addr = kubera_config::admin_address();

        assert!(exists<ObligationStore>(admin_addr), ERROR_OBLIGATION_NOT_INITIALIZED);

        // create resource account 
        let (obligation_signer, obligation_signer_cap) = 
            account::create_resource_account(sender, b"obligation");

        let obligation = Obligation<ReserveCoin> {
            version : version,
            owner : signer::address_of(sender),
            deposits : vector::empty<ObligationCollateral<LPCoin<ReserveCoin>>>(),
            borrows : vector::empty<ObligationLiquidity<ReserveCoin>>(),
            deposited_value : 0,
            borrowed_value : 0,
            allowed_borrow_value : 0,
            unhealthy_borrow_value : 0,
            obligation_signer_cap : obligation_signer_cap

        };

        move_to(&obligation_signer, obligation);

        let obligation_resource_addr = signer::address_of(&obligation_signer);

        
        let obligation_store = borrow_global_mut<ObligationStore>(admin_addr);

        let obligators = &mut obligation_store.obligators;

        table::add(obligators, signer::address_of(sender), obligation_resource_addr);


        obligation_resource_addr

    }


    public fun get_obligator_resource(addr : address) : address  acquires ObligationStore{
        let admin_addr = kubera_config::admin_address();
        let obligation_store = borrow_global<ObligationStore>(admin_addr);
        let obligators = &obligation_store.obligators;

        *table::borrow<address, address>(obligators, addr)
    }
   

}