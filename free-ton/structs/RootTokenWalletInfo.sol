pragma ton-solidity ^0.47.0;

struct RootTokenWalletInfo {
    address ton_token_wallet;
    bool need_receive_callback;
    bool allow_non_notifiable;
    bool need_bounce_callback;
    bool trust;
}