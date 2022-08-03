module kubera::base {

    struct LPCoin<phantom ReserveCoin> {}


    #[test_only]
    use aptos_framework::timestamp::{Self};
    #[test_only]
    public entry fun setup_timestamp(root: &signer) {
        timestamp::set_time_has_started_for_testing(root)
    }
}