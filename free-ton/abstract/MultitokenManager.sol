pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../interfaces/TIP3-broxus/IRootTokenContract.sol";
import "../interfaces/TIP3-broxus/ITONTokenWallet.sol";
import "../structs/RootTokenWalletInfo.sol";

/*
 *  MultitokenManager - Сontract for managing wallets TIP-3 tokens
 *
 *  Function addTonTokenWallet - creates a new TIP-3 wallet controlled by this contract.
 *  Before calling, you need to make sure that the wallet was not confirmed earlier.
 *    Arguments:
 *      address root_token_wallet       - root TIP-3 token wallet
 *      bool need_receive_callback,     - if true, sets a receive callback for the wallet
 *      bool allow_non_notifiable,      - if true, allows payments without notice
 *      bool need_bounce_callback       - if true, sets a bounce callback for the wallet
 *
 *
 *  Function sendTokens - sends TIP-3 tokens
 *  Before calling, you need to make sure that the wallet has been previously confirmed.
 *    Arguments:
 *      address ton_token_wallet  
 *      uint128 gas_value       - amount of gas
 *      bool bounce             - 
 *      uint16 flag             -
 *      address to              - destination address
 *      uint128 tokens          - amount of TIP-3 tokens
 *      uint128 grams           - amount of TON Crystal
 *      address send_gas_to     - gas destination address
 *      bool notify_receiver    - notify recipient
 *      TvmCell payload         - payload
 *
 *
 *  Callback onTonTokenWalletConfirm - callback when creating and confirming TIP-3 wallet
 *    Arguments:
 *      address root_token_wallet   - root wallet address
 *      address ton_token_wallet    - confirmed TIP-3 wallet
 *     
 *
 *  Get-Method safeGetTonTokenWallet - gets TIP-3 wallet address
 *    Arguments:
 *      address root_token_wallet   - root wallet address
 *    Returns:
 *      address ton_token_wallet    - TIP-3 wallet address
 *      bool trust                  - true, if the wallet is verified
 *      
 *
 *  Get-Method getTonTokenWalletInfo    - gets TIP-3 wallet address, exception if wallet does not exist
 *    Arguments:
 *      address root_token_wallet                   - root wallet address
 *    Returns:  
 *      RootTokenWalletInfo ton_token_wallet_info   - wallet information
 *
 *
 *  Get-Method getTonTokenWallets   - gets a mapping of all wallets
 *    Returns:
 *      mapping (address => RootTokenWalletInfo) wallets    - mapping of all wallets
 */

abstract contract MultitokenManager {
    mapping(address => RootTokenWalletInfo) ton_token_wallets;

    function sendTokens(
        address ton_token_wallet, 
        uint128 gas_value, bool bounce, uint16 flag,
        address to, uint128 tokens, uint128 grams, 
        address send_gas_to, bool notify_receiver, 
        TvmCell payload
    ) internal pure {
        ITONTokenWallet(ton_token_wallet).transfer{
            value: gas_value, bounce: bounce, flag: flag
        }(
            to, tokens, grams, send_gas_to, 
            notify_receiver, payload
        );
    }

    function deployTonTokenWallet(address root_token_wallet) internal {
        IRootTokenContract(root_token_wallet).deployEmptyWallet{
            value: 500_000_000, flag: 1, bounce: true
        }(50_000_000, 0, address(this), address(this));
    }

    function addTonTokenWallet(
        address root_token_wallet, 
        bool need_receive_callback, 
        bool allow_non_notifiable, 
        bool need_bounce_callback
    ) internal { 
        ton_token_wallets[root_token_wallet] = RootTokenWalletInfo(
            address.makeAddrStd(0, 0), 
            need_receive_callback, 
            allow_non_notifiable,
            need_bounce_callback, 
            false
        );

        IRootTokenContract(root_token_wallet).getWalletAddress{
            callback: MultitokenManager.onGetTonTokenWalletAddress, 
            value: 70_000_000, flag: 1, bounce: true
        }(0, address(this));
    }

    /* Callbacks */

    function onGetTonTokenWalletAddress(address ton_token_wallet) external {
        address root_token_wallet = msg.sender;
        RootTokenWalletInfo root_token_wallet_info = getTonTokenWalletInfo(root_token_wallet);
        (, bool need_receive_callback, bool allow_non_notifiable, bool need_bounce_callback, bool trust)
            = root_token_wallet_info.unpack();
        require(!trust);
        tvm.accept();

        ton_token_wallets[msg.sender].ton_token_wallet = ton_token_wallet;
        
        if (need_receive_callback) {
            ITONTokenWallet(ton_token_wallet).setReceiveCallback{
                value: 15_000_000, flag: 1, bounce: true
            }(address(this), allow_non_notifiable);
        } 
        
        if (need_bounce_callback) {
            ITONTokenWallet(ton_token_wallet).setBouncedCallback{
                value: 15_000_000, flag: 1, bounce: true
            }(address(this));
        }

        ITONTokenWallet(ton_token_wallet).getDetails{
            callback: MultitokenManager.onGetTonTokenWalletDetails,
            value: 70_000_000, flag: 1, bounce: true
        }();
    }

    function onGetTonTokenWalletDetails(ITONTokenWallet.ITONTokenWalletDetails details) external {
        (
            address root_address, uint256 wallet_public_key, address owner_address, , 
            address receive_callback, address bounced_callback, bool allow_non_notifiable
        ) = details.unpack();

        RootTokenWalletInfo root_token_wallet_info = getTonTokenWalletInfo(root_address);
        (
            address ton_token_wallet,
            bool need_receive_callback, 
            bool saved_allow_non_notifiable, 
            bool need_bounce_callback, 
            bool trust
        ) = root_token_wallet_info.unpack();

        require(!trust);
        require(ton_token_wallet == msg.sender);
        require(saved_allow_non_notifiable == allow_non_notifiable);

        require((need_bounce_callback && (bounced_callback == address(this))) 
            || (!need_bounce_callback && (bounced_callback.value == 0)));

        require((need_receive_callback && (receive_callback == address(this))) 
            || (!need_receive_callback && (receive_callback.value == 0)));

        require(owner_address == address(this));
        require(wallet_public_key == 0);
        tvm.accept();

        root_token_wallet_info.trust = true;
        ton_token_wallets[root_address] = root_token_wallet_info;

        onTonTokenWalletConfirm(root_address, ton_token_wallet);
    }

    function onTonTokenWalletConfirm(address root_token_wallet, address ton_token_wallet) internal {}

    /* Get Methods */

    function safeGetTonTokenWallet(address root_token_wallet) public view returns (address ton_token_wallet, bool trust) {       
        optional(RootTokenWalletInfo) opt_root_token_wallet = ton_token_wallets.fetch(root_token_wallet);

        if (opt_root_token_wallet.hasValue()) {
            RootTokenWalletInfo root_token_wallet_info;
            root_token_wallet_info = opt_root_token_wallet.get();
            return(root_token_wallet_info.ton_token_wallet, root_token_wallet_info.trust);
        } else {
            return (address.makeAddrStd(0, 0), false);
        }
    }

    function getTonTokenWallet(address root_token_wallet) public view returns (address ton_token_wallet, bool trust) {       
        RootTokenWalletInfo root_token_wallet_info = getTonTokenWalletInfo(root_token_wallet);
        return(root_token_wallet_info.ton_token_wallet, root_token_wallet_info.trust);
    }

    function getTonTokenWalletInfo(address root_token_wallet) public view returns (RootTokenWalletInfo ton_token_wallet_info) {
        return ton_token_wallets.at(root_token_wallet);
    }

    function getTonTokenWallets() public view returns (mapping (address => RootTokenWalletInfo) wallets) {
        return ton_token_wallets;
    }

}
