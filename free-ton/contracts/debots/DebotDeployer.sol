pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "./UniversalDebot.sol";

interface IDebot {
    function setWalletCode(TvmCell multiwalletCode) external;
    function setABI_(string dabi) external;
}

contract DebotDeployer {

    TvmCell static m_debotCode;

    constructor() public {
        require(tvm.pubkey() != 0, 101);
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();
    }

    function deploy(
        TvmCell m_walletCode,
        string m_dabi
    ) external returns (address) {
        require(msg.pubkey() == tvm.pubkey(), 102);
        tvm.accept();

        address debot = new UserDebot{
            value: 100_000_000,
            flag: 1,
            code: m_debotCode,
            pubkey: tvm.pubkey(),
            varInit: {}
        }();

        
        IDebot(debot).setWalletCode{value: 100_000_000, flag: 1}(m_walletCode);
        IDebot(debot).setABI_{value: 100_000_000, flag: 1}(m_dabi);
        return debot;
    }
}

