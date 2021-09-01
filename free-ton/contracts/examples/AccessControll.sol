pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "../MultitokenWallet.sol";

import "../../abstract/SingletokenManager.sol";
import "../../abstract/TimerManager.sol";
import "../../interfaces/Subscriptions/IService.sol";
import "../../interfaces/Subscriptions/ISpender.sol";

import "../../structs/SubscriptionTerms.sol";
import "../../structs/UserWalletInformation.sol";

contract AccessController is SingletokenManager, TimerManager, IService, ISpender {
    event onNewSubscription(address _terms_address, uint256 public_key_);
    event onNewPayment(address _terms_address, uint256 public_key_);
    event onUnsubscribe(address _terms_address, uint256 public_key_);

    uint128 constant timer_reward = 65_000_000;
    uint128 constant timer_compensation = 35_000_000;

    address static terms_address;
    SubscriptionTerms m_subscription_terms;
    UserWalletInformation m_user_information;
    uint64 m_available_until;
    uint64 m_alignment;
    uint128 m_tonTokenWalletBalance;

    constructor(SubscriptionTerms terms, UserWalletInformation user_info) public {
        require(tvm.pubkey() != 0, 101);
        require(msg.pubkey() == tvm.pubkey() || msg.sender == terms_address, 102);
        require(address(this).balance > 600_000_000);
        tvm.accept();

        m_subscription_terms = terms;
        m_user_information = user_info;
        m_available_until = 0;
        m_alignment = 0;

        TimerManager.deployTimer();
        if (terms.root_token_wallet.value != 0) {
            SingletokenManager.addTonTokenWallet(terms.root_token_wallet, true, true, false);
        }
    }



    /* Timer callbacks */

    function onTimerDeployedCallback() override internal {
        checkReady();
    }

    function onTimerWakeUpCallback() override internal {
        spendFromWallet();
        sendTokensToProvider(0, m_tonTokenWalletBalance, 128 );
        m_tonTokenWalletBalance = 0;
    }



    /* TIP-3 wallet callbacks */

    function onTonTokenWalletConfirm() override internal {
        checkReady();
    }



    /* Ready callback */

    function onReadyCallback() override internal {
        address addr = address.makeAddrExtern(terms_address.value, 256);
        emit onNewSubscription{dest: addr}(terms_address, tvm.pubkey());
        TimerManager.setTimer(timer_reward, m_subscription_terms.period, m_alignment, false);
        spendFromWallet();
        m_user_information.wallet_for_spend.transfer({ value: 0, flag: 128 });
    }



    /* Receive Callbacks */

    receive() external {
        if (m_user_information.tokens_source == msg.sender 
          && m_subscription_terms.value <= msg.value
          && m_subscription_terms.root_token_wallet.value == 0) {
            onFundsReceive();
        }
    }

    function onTonTokenWalletReceive(
        address token_wallet, 
        uint128 amount,
        address original_gas_to,
        uint128 updated_balance,
        TvmCell payload
    ) override internal {
        require(amount >= m_subscription_terms.value);
        m_tonTokenWalletBalance = updated_balance;

        onFundsReceive();
    }
    
    function onFundsReceive() override internal {
        address addr = address.makeAddrExtern(terms_address.value, 256);
        emit onNewPayment{dest: addr}(terms_address, tvm.pubkey());

        uint64 new_aviable_time = math.max(uint64(now), m_available_until) + m_subscription_terms.period;
        if (uint64(now) > m_available_until && uint64(now) < m_available_until + m_subscription_terms.max_payment_delay) {
            new_aviable_time -= uint64(now) - m_available_until;
        }

        m_available_until = new_aviable_time;
        TimerManager.startTimer(timer_reward + timer_compensation);
    }



    /* subscription status callback */

    function notifyApprove(SpendTerms terms) override external {
        require(m_user_information.wallet_for_spend == msg.sender);
        tvm.accept();

        m_alignment = terms.start + 60;
        checkReady();
    }

    function notifyDisapprove() override external {
        require(m_user_information.wallet_for_spend == msg.sender);
        tvm.accept();
        returnTokensToUser();        
    }



    /* Utils */

    function checkReady() internal {
        if (m_alignment != 0 && TimerManager.checkTimerReady() 
          && (m_subscription_terms.root_token_wallet.value == 0 
          || SingletokenManager.checkWalletReady())) {
            onReadyCallback();
        }
    }

    function spendFromWallet() internal view {
        MultitokenWallet(m_user_information.wallet_for_spend).spend{
            value: 100_000_000, flag: 1, bounce: true
        }();
    }

    //function returnFunds

    function sendTokensToProvider(uint128 gas_value, uint128 tokens_value, uint8 flag) internal {
        if (m_subscription_terms.root_token_wallet.value == 0) {
            m_subscription_terms.send_value_to.transfer({ value: gas_value, flag: flag });
        } else {
            TvmCell payload;
            SingletokenManager.sendTokens(gas_value, true, flag,
                m_subscription_terms.send_value_to, tokens_value, 0, 
                m_user_information.wallet_for_spend, true, payload
            );
        }
    }

    function returnTokensToUser() internal {
        address addr = address.makeAddrExtern(terms_address.value, 256);
        emit onUnsubscribe{dest: addr}(terms_address, tvm.pubkey());

        if (m_available_until <= uint64(now)) {
            sendTokensToProvider(0, m_tonTokenWalletBalance, 128);
            return;
        } 

        uint128 balance = m_tonTokenWalletBalance;
        if (m_subscription_terms.root_token_wallet.value == 0) {
            balance = address(this).balance - msg.value;
        }

        uint64 service_unused_time = m_subscription_terms.period - ((uint64(now) - m_alignment) % m_subscription_terms.period);
        uint64 unused_part = (service_unused_time * 10) / m_subscription_terms.period;
        uint64 used_part = 10 - unused_part;

        uint128 balance_to_provider = (balance * used_part) / 10;
        uint128 balance_to_user = balance - balance_to_provider;

        TimerManager.sendFromTimer(m_user_information.wallet_for_spend, 0, true, 128);
        if (m_subscription_terms.root_token_wallet.value != 0) {
            TvmCell payload;
            sendTokensToProvider(75_000_000, balance_to_provider, 0);
            SingletokenManager.sendTokens(0, true, 128,
                m_user_information.tokens_source, balance_to_user, 0, 
                m_user_information.wallet_for_spend, true, payload
            );

            m_tonTokenWalletBalance = 0;
        } else {
            m_subscription_terms.send_value_to.transfer({ value: balance_to_provider, flag: 0 });
            m_user_information.wallet_for_spend.transfer({ value: 0, flag: 128 });
        }
    }


    /* Get Methods */

    function getInfo() external view returns (
        address terms_address_, 
        SubscriptionTerms subscription_terms, 
        UserWalletInformation user_information,
        address timer_address,
        bool timer_was_deployed_,
        uint64 available_until
    ) {
        return (terms_address, m_subscription_terms, m_user_information, m_timer_address, timer_was_deployed, m_available_until);
    }

    function getAvailableUntil() override external view returns (uint64) {
        return m_available_until + m_subscription_terms.max_payment_delay;
    }

}