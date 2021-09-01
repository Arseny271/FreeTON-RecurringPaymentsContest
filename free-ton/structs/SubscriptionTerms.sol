pragma ton-solidity ^0.47.0;

struct SubscriptionTerms {
    address debot_address;          // адрес дебота
    uint256 shipper_pubkey;         // публичный ключ поставщика
    uint256 verifier_pubkey;        // публичный ключ верификатора
    address send_value_to;          // адрес для отправки средств
    address root_token_wallet;      // корневой кошелёк TIP-3
    uint128 value;                  // размер платежа   
    uint128 gas_value;              // размер комиссии
    uint64 period;                  // период платежа  
    uint32 max_payment_delay;       // допустимая задержка   
    bytes name;
    bytes info;          
}