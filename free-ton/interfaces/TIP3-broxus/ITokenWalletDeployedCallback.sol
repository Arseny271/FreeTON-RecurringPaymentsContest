pragma ton-solidity ^0.47.0;

interface ITokenWalletDeployedCallback {
    function notifyWalletDeployed(address root) external;
}
