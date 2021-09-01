pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../interfaces/TIP3-broxus/IRootTokenContract.sol";
import "../interfaces/TIP3-broxus/ITONTokenWallet.sol";
import "../interfaces/Subscriptions/ITimerDeployedCallback.sol";
import "../interfaces/Subscriptions/IWakeUp.sol";
import "../structs/RootTokenWalletInfo.sol";

import "../contracts/RootOffchainTimer.sol";

abstract contract TimerManager is ITimerDeployedCallback, IWakeUp {
    address constant timer_root_address = address.makeAddrStd(0, 
        0xb4a2d34eec146505e4166988a35ada1776faa7447974e9786bbdfd16cd8287f4);

    address m_timer_address;
    bool timer_was_deployed;



    /* internal functions */

    function deployTimer() internal {
        m_timer_address = address.makeAddrStd(0, 0);
        timer_was_deployed = false;
        RootOffchainTimer(timer_root_address).getTimerAddress{
            callback: TimerManager.onGetTimerContractAddress, 
            value: 100_000_000, flag: 1, bounce: true
        }(0, address(this), address(this).value);
    }

    function setTimer(uint128 reward, uint64 period, uint64 alignment, bool auto_restart ) internal {
        OffchainTimer(m_timer_address).setTimerParams(
            address(this), reward, period, alignment, auto_restart);
    }

    function startTimer(uint128 value) internal {
        OffchainTimer(m_timer_address).startTimer{
            value: value, flag: 1
        }();
    }

    function sendFromTimer(address dest, uint128 amount, bool bounce, uint16 flag) internal {
        OffchainTimer(m_timer_address).sendValue(dest, amount, bounce, flag);
    }



    /* external callbacks */

    function onGetTimerContractAddress(address timer_address) external {
        require(msg.sender == timer_root_address);
        tvm.accept();

        m_timer_address = timer_address;
        RootOffchainTimer(timer_root_address).deployTimer{
            value: 350_000_000, flag: 1, bounce: true
        }(0, address(this), address(this).value);
    }

    function notifyTimerDeployed() override external {
        require(msg.sender == m_timer_address);
        tvm.accept();
        timer_was_deployed = true;
        onTimerDeployedCallback();
    }

    function onWakeUpCallback(bool was_restarted) override external {
        require(m_timer_address == msg.sender);
        tvm.accept();
        onTimerWakeUpCallback();
    }


    /* internal callbacks */

    function onTimerDeployedCallback() virtual internal;
    function onTimerWakeUpCallback() virtual internal;



    /* internal inline get methods */

    function getTimerAddress() internal view returns (address timer_address) {
        return m_timer_address;
    }

    function checkTimerReady() internal view returns (bool timer_ready) {
        return timer_was_deployed;
    }
}
