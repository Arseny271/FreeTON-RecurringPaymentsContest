pragma ton-solidity ^0.47.0;
pragma AbiHeader expire;

interface IWakeUp {
    function onWakeUpCallback(bool was_restarted) external;
}
