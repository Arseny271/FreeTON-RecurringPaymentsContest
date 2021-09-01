pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../interfaces/TIP3-broxus/IRootTokenContract.sol";
import "../interfaces/TIP3-broxus/ITONTokenWallet.sol";
import "../interfaces/TIP3-broxus/ITokensReceivedCallback.sol";
import "../structs/RootTokenWalletInfo.sol";

abstract contract SingletokenManager is ITokensReceivedCallback {
    RootTokenWalletInfo ton_token_wallet_info;
    address m_root_token_wallet;

    function sendTokens(
        uint128 gas_value, bool bounce, uint16 flag, address to, uint128 tokens, 
        uint128 grams, address send_gas_to, bool notify_receiver, TvmCell payload
    ) internal {
        ITONTokenWallet(ton_token_wallet_info.ton_token_wallet).transfer{
            value: gas_value, bounce: bounce, flag: flag
        }(
            to, tokens, grams, send_gas_to, 
            notify_receiver, payload
        );
    }

    function addTonTokenWallet(
        address root_token_wallet, 
        bool need_receive_callback, 
        bool allow_non_notifiable, 
        bool need_bounce_callback
    ) internal { 
        m_root_token_wallet = root_token_wallet;
        ton_token_wallet_info = RootTokenWalletInfo(
            address.makeAddrStd(0, 0), 
            need_receive_callback, 
            allow_non_notifiable,
            need_bounce_callback, 
            false
        );

        IRootTokenContract(root_token_wallet).getWalletAddress{
            callback: SingletokenManager.onGetTonTokenWalletAddress, 
            value: 100_000_000, flag: 1, bounce: true
        }(0, address(this));
    }

    /* Callbacks */

    function tokensReceivedCallback(
        address token_wallet,
        address token_root,
        uint128 amount,
        uint256 sender_public_key,
        address sender_address,
        address sender_wallet,
        address original_gas_to,
        uint128 updated_balance,
        TvmCell payload
    ) override external {
        require(token_root == m_root_token_wallet);
        require(token_wallet == ton_token_wallet_info.ton_token_wallet);

        onTonTokenWalletReceive(token_wallet, amount, original_gas_to, updated_balance, payload);
    }

    function onGetTonTokenWalletAddress(address ton_token_wallet) external {
        require(m_root_token_wallet == msg.sender);

        RootTokenWalletInfo root_token_wallet_info = getTonTokenWallet();
        (, bool need_receive_callback, bool allow_non_notifiable, bool need_bounce_callback, bool trust)
            = root_token_wallet_info.unpack();
        require(!trust);
        tvm.accept();

        ton_token_wallet_info.ton_token_wallet = ton_token_wallet;
        
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
            callback: SingletokenManager.onGetTonTokenWalletDetails,
            value: 50_000_000, flag: 1, bounce: true
        }();
    }

    function onGetTonTokenWalletDetails(ITONTokenWallet.ITONTokenWalletDetails details) external {
        (
            address root_address, uint256 wallet_public_key, address owner_address, , 
            address receive_callback, address bounced_callback, bool allow_non_notifiable
        ) = details.unpack();

        RootTokenWalletInfo root_token_wallet_info = getTonTokenWallet();
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
        ton_token_wallet_info = root_token_wallet_info;

        onTonTokenWalletConfirm();
    }

    function onTonTokenWalletConfirm() virtual internal;
    function onTonTokenWalletReceive(
        address token_wallet, 
        uint128 amount,
        address original_gas_to,
        uint128 updated_balance,
        TvmCell payload
    ) virtual internal;

    function checkWalletReady() internal view returns (bool wallet_ready) {
        return ton_token_wallet_info.trust;
    }

    /* Get Methods */

    function getTonTokenWallet() public view returns (RootTokenWalletInfo ton_token_wallet_info_) {
        return ton_token_wallet_info;
    }
}
