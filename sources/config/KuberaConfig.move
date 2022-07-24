module kubera::kubera_config {

    use std::signer;

    public fun admin_address() : address {
        @kubera
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