pragma ton-solidity ^0.47.0;

abstract contract IService {
    function onFundsReceive() virtual internal;
    function onReadyCallback() virtual internal;

    function getAvailableUntil() virtual external view returns (uint64);
}
