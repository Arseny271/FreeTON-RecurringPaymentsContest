pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../structs/SubscriptionTerms.sol";
import "../structs/UserWalletInformation.sol";

contract AbstractService {
    address static terms_address;

    constructor(SubscriptionTerms terms, UserWalletInformation user_info) public {
        
    }

    function getAvailableUntil() external view returns (uint64) {return 0;}

}
