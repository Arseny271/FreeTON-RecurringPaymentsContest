pragma ton-solidity ^0.47.0;

struct SpendTerms {
    address send_value_to;
    address root_token_wallet; 
    uint128 value;  
    uint128 gas_value;
    uint64 period;                  
    uint64 start;      
    bytes info;               
}

struct SpendInfo {
    SpendTerms terms;
    uint64 time_of_next_payment;
}