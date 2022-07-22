module Kubera::KuberaConfig {

    use Std::Signer;

    public fun admin_address() : address {
        @Kubera
    }

    struct LendingMarket has store {
        version : u8,
        authority : address
   }

   public(script) fun initialize_lending_market(sender : &signer, version : u8) : LendingMarket {

        LendingMarket {
            version : version,
            authority : Signer::address_of(sender)
        }

   }

}