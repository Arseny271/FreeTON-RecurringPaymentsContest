pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "./OffchainTimer.sol";

contract RootOffchainTimer {
    
    TvmCell static timer_code;

    modifier onlyOwner {
        require(msg.pubkey() == tvm.pubkey(), 102);   
        _;
    }

    constructor() public {
        require(tvm.pubkey() != 0, 101);
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();
    }

    function walletSendValue(address dest, uint128 amount, bool bounce) external pure onlyOwner {
        tvm.accept();
        dest.transfer(amount, bounce, 0);
    }

    function getTimerAddress(
        uint256 owner_public_key_, 
        address owner_address_, 
        uint256 random_value_
    ) external view responsible returns (address timer_address) {
        TvmCell stateInit = tvm.buildStateInit({
            contr: OffchainTimer,
            code: timer_code,
            pubkey: owner_public_key_,
            varInit: {
                owner_public_key: owner_public_key_,
                owner_address: owner_address_,
                random_value: random_value_
            }
        });

        return { value: 0, bounce: false, flag: 64 } address(tvm.hash(stateInit));
    }

    function deployTimer(
        uint256 owner_public_key_, 
        address owner_address_, 
        uint256 random_value_
    ) external view returns (address timer_address) {
        tvm.rawReserve(address(this).balance - msg.value, 2);
        return new OffchainTimer{
            value: 0, flag: 128,
            code: timer_code,
            pubkey: owner_public_key_,
            varInit: {
                owner_public_key: owner_public_key_,
                owner_address: owner_address_,
                random_value: random_value_
            }
        }();

    }
}
