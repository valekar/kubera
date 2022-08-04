module kubera::kubera_config {

    use std::signer;
    use aptos_framework::account;

    const KUBERA_ADDRESS:address = @0x01;

    const  EXCLUSIVE : u8  = 1;
    const INCLUSIVE :u8 = 0;



    public fun EXCLUSIVE_():u8 {
        EXCLUSIVE
    }

    public fun INCLUSIVE_():u8 {
        INCLUSIVE
    }


    public fun admin_address() : address {
        @kubera
    }

    public fun kubera_address() : address {
        KUBERA_ADDRESS
    }


    public fun create_account_if_not_existing(addr : address)  {
         if(!account::exists_at(addr)) {
            account::create_account(addr);
         };
    }


    struct LendingMarket has key ,store {
        version : u8,
        authority : address
   }

   public fun initialize_lending_market(sender : &signer, version : u8)  {
      let lending_market =   LendingMarket {
            version : version,
            authority : signer::address_of(sender)
        };

        move_to<LendingMarket>(sender, lending_market);
    }



}