pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "../structs/SpendTerms.sol";
import "../abstract/MultitokenManager.sol";
import "../interfaces/Subscriptions/ISpender.sol";

contract MultitokenWallet is MultitokenManager {
    uint128 constant target_gas_balance = 0.075 ton;
    uint8 constant INSUFFICIENT_FUNDS_ERROR = 1;
    uint8 constant PREMATURE_ATTEMPT_TO_SPEND_ERROR = 2;

    event OnSpentEvent(address spender, uint64 time_next_payment);
    event OnSpentErrorEvent(address spender, uint8 err_id);
    event OnBounceEvent(address wallet);

    mapping(address => SpendInfo) active_spenders;


    modifier onlyOwner {
        require(msg.pubkey() == tvm.pubkey());        
        _;
    }

    constructor() public {
        require(tvm.pubkey() != 0);
        require(msg.pubkey() == tvm.pubkey());
        tvm.accept();
    }

    function approve(address spender, SpendTerms terms) external onlyOwner {
        address root_token_wallet = terms.root_token_wallet;
        if (root_token_wallet.value != 0) {
            (, bool trust) = MultitokenManager.getTonTokenWallet(root_token_wallet);
            require(trust);
        }

        tvm.accept();
        active_spenders[spender] = SpendInfo(terms, 0);
        ISpender(spender).notifyApprove{flag: 1, value: terms.gas_value}(terms);
    }

    function disapprove(address spender) external onlyOwner {
        delete active_spenders[spender];
        tvm.accept();
        ISpender(spender).notifyDisapprove{flag: 1}();
    }

    function spend() external {
        SpendInfo spend_info = active_spenders.at(msg.sender);
        (SpendTerms terms, uint64 time_of_next_payment) = spend_info.unpack();
        requireSpendEvent(time_of_next_payment < uint64(now), PREMATURE_ATTEMPT_TO_SPEND_ERROR);

        (
            address send_value_to, address root_token_wallet,
            uint128 value, uint128 gas_value, uint64 period, uint64 start, 
        ) = terms.unpack();

        uint64 new_time_of_next_payment = getNextPaymentTime(time_of_next_payment, period, start);

        TvmCell payload;
        if (root_token_wallet.value == 0) {
            requireSpendEvent(address(this).balance - msg.value > value, INSUFFICIENT_FUNDS_ERROR);
            uint128 reserve = math.max(target_gas_balance, address(this).balance - msg.value - value);
            requireSpendEvent(address(this).balance - value > reserve, INSUFFICIENT_FUNDS_ERROR);
            tvm.rawReserve(reserve, 2);
            
            send_value_to.transfer(value, true, 1, payload);
            emit OnSpentEvent(msg.sender, new_time_of_next_payment);
            msg.sender.transfer(0, true, 128);
        } else {
            requireSpendEvent(address(this).balance - msg.value > gas_value, INSUFFICIENT_FUNDS_ERROR);
            emit OnSpentEvent(msg.sender, new_time_of_next_payment);
            (address ton_token_wallet, ) = MultitokenManager.getTonTokenWallet(root_token_wallet);
            MultitokenManager.sendTokens(ton_token_wallet, gas_value, true, 0, 
                send_value_to, value, 0, msg.sender, true, payload);
        }

        active_spenders[msg.sender] = SpendInfo(terms, new_time_of_next_payment);
    }

    function getNextPaymentTime(uint64 old_next_payment_time, uint64 period, uint64 start) 
    private returns (uint64 next_payment_time) {
        if (start == 0xFFFFFFFFFFFFFFFF) {      // alignment disabled
            return (old_next_payment_time + period);
        } else {
            uint64 time_until_next_payment = period - ((uint64(now) - start) % period);
            return uint64(now) + time_until_next_payment;
        }
    }

    function walletSendValue(address dest, uint128 amount, bool bounce, TvmCell payload) external pure onlyOwner {
        tvm.accept();
        dest.transfer(amount, bounce, 0, payload);
    }

    function walletSendTokens(
        address root_token_wallet, uint128 gas_value, 
        bool bounce, uint16 flag, address to, 
        uint128 tokens, uint128 grams, address send_gas_to, 
        bool notify_receiver, TvmCell payload
    ) external view onlyOwner {
        (address ton_token_wallet, bool trust) = MultitokenManager.getTonTokenWallet(root_token_wallet);
        require(trust);
        tvm.accept();

        MultitokenManager.sendTokens(ton_token_wallet, gas_value, bounce, flag, 
            to, tokens, grams, send_gas_to, notify_receiver, payload);
    }

    function walletDeployTonTokenWallet(
        address root_token_wallet
    ) external onlyOwner {
        (address ton_token_wallet, bool trust) = MultitokenManager.safeGetTonTokenWallet(root_token_wallet);
        require(!trust);
        tvm.accept();

        MultitokenManager.deployTonTokenWallet(root_token_wallet);
    }

    function walletAddTonTokenWallet(
        address root_token_wallet, 
        bool need_receive_callback, 
        bool allow_non_notifiable, 
        bool need_bounce_callback
    ) external onlyOwner {
        (address ton_token_wallet, bool trust) = MultitokenManager.safeGetTonTokenWallet(root_token_wallet);
        require(!trust);
        tvm.accept();

        MultitokenManager.addTonTokenWallet(
            root_token_wallet, 
            need_receive_callback, 
            allow_non_notifiable, 
            need_bounce_callback
        );
    }

    function requireSpendEvent(bool cond, uint8 err_code) internal {
        if (!cond) {
            tvm.rawReserve(address(this).balance - msg.value, 2);
            emit OnSpentErrorEvent(msg.sender, err_code);
            revert(150 + err_code);
        }
    }

    onBounce(TvmSlice body) external {
        emit OnBounceEvent(msg.sender);
    }

    /* Get Methods */

    function getActiveSpenders() external returns (mapping(address => SpendInfo)) {
        return active_spenders;
    }
}
