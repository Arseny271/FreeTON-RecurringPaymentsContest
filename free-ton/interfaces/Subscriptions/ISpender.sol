pragma ton-solidity ^0.47.0;

import "../../structs/SpendTerms.sol";

interface ISpender {
    function notifyApprove(SpendTerms terms) external;
    function notifyDisapprove() external;
}
