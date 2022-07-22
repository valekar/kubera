module Kubera::Lend {

   use AptosFramework::Coin;

   struct LPToken<phantom LPCollateral> has store {
      collateral : Coin::Coin<LPCollateral>,
       
   }

}