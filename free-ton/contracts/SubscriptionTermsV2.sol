pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "../interfaces/Subscriptions/ITerms.sol";
import "../abstract/AbstractService.sol";

import "../structs/SubscriptionTerms.sol";
import "../structs/UserWalletInformation.sol";

contract SubscriptionTermsContract {
    uint128 constant feedback_target_gas_balance = 0.25 ton;

    uint256 static random_value;
    TvmCell static mediator_contract_code;

    SubscriptionTerms m_subscription_terms;
    constructor(SubscriptionTerms subscription_terms) public {
        require(tvm.pubkey() != 0, 101);
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();

        m_subscription_terms = subscription_terms;
    }

    modifier onlyOwner {
        require(msg.pubkey() == tvm.pubkey());        
        _;
    }

    function sendValue(address dest, uint128 amount, bool bounce, uint16 flag) public pure onlyOwner {
        dest.transfer(amount, bounce, flag);
    }

    function deployMediatorContract(uint256 user_pubkey, UserWalletInformation user_info) public view returns (address mediator_address) {
        tvm.rawReserve(address(this).balance - msg.value, 2);

        address contract_address = new AbstractService{
            value: 0,
            flag: 128,
            code: mediator_contract_code,
            pubkey: user_pubkey,
            varInit: {
                terms_address: address(this)
            }
        }(m_subscription_terms, user_info);

        return contract_address;
    }

    /*function feedback(
        uint256 random_value_,
        address user_address_or_pubkey,
        address provider_address_or_pubkey,
        address terms_address,
        TvmCell feedback_cell
    ) override external {
        uint128 reserve = math.max(feedback_target_gas_balance, address(this).balance - msg.value);
        require(address(this).balance > reserve);
        tvm.rawReserve(reserve, 2);
        
        msg.sender.transfer({ value: 0, flag: 128 });
    }*/

    /* Get methods */
    function getTerms() public view returns (SubscriptionTerms terms) {
        return (m_subscription_terms);
    }    

    function getMediatorContractCode() public view returns (TvmCell contract_code, uint256 code_hash) {
        return (mediator_contract_code, tvm.hash(mediator_contract_code));
    }
}
