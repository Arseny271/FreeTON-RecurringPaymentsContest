pragma ton-solidity ^0.47.0;
pragma AbiHeader expire;

interface ITerms {
    function feedback(
        uint256 random_value,
        address user_address_or_pubkey,
        address provider_address_or_pubkey,
        address terms_address,
        TvmCell feedback_cell
    ) external;
}
