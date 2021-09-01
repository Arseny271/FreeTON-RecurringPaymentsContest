pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;

import "../interfaces/Subscriptions/IWakeUp.sol";
import "../interfaces/Subscriptions/ITimerDeployedCallback.sol";

contract OffchainTimer {
    event WakeUpRequest(
        address timer_address, 
        address owner_address, 
        uint256 owner_pubkey, 
        uint256 random, 
        uint64 wakeup_time, 
        uint128 reward,
        bool is_restart
    );

    uint128 constant target_gas_balance = 0.05 ton;

    uint256 static owner_public_key;
    address static owner_address;
    uint256 static random_value;

    uint64 wake_up_time;

    uint128 reward;
    uint128 next_reward;
    address notify_address;

    bool repeat_request;
    uint64 period;
    uint64 start;

    modifier onlyOwner {
        require((owner_address.value != 0 && owner_address == msg.sender) ||
                (owner_public_key != 0 && owner_public_key == msg.pubkey()));
        _;
    }

    constructor() public {
        require(owner_public_key == tvm.pubkey() && (owner_address.value == 0 || owner_public_key == 0));
        tvm.accept();

        if (owner_address.value != 0) {
            ITimerDeployedCallback(owner_address).notifyTimerDeployed{value: 10_000_000, flag: 1}();
        }
    }

    function setTimerParams(address new_notify_address, uint128 new_reward, uint64 new_period, uint64 new_start, bool need_repeat) external onlyOwner {
        tvm.accept();
        notify_address = new_notify_address;
        next_reward = new_reward;
        period = new_period;
        start = new_start;
        repeat_request = need_repeat;
    }

    function sendValue(address dest, uint128 amount, bool bounce, uint16 flag) external onlyOwner {
        tvm.accept();
        if (reward != 0) {
            tvm.rawReserve(reward + target_gas_balance, 2);
        }

        dest.transfer(amount, bounce, flag);
    }

    function startTimer() external onlyOwner {
        require((address(this).balance > next_reward + target_gas_balance), 103);
        tvm.accept();

        sendWakeUpRequest();
    }



    /* Wake-up function */

    function timerWakeUp(address reward_address) external {
        require(reward != 0, 105);
        require(wake_up_time < uint64(now), 104);
        tvm.accept();

        bool need_restart = repeat_request && (address(this).balance > reward + next_reward + target_gas_balance);

        IWakeUp(notify_address).onWakeUpCallback{
            value: 10_000_000, bounce: true, flag: 0
        }(need_restart);
        reward_address.transfer(reward, true, 0);

        if (need_restart) {
            sendWakeUpRequest();
        } else {
            reward = 0;
        }
    }



    /* Utils */

    function sendWakeUpRequest() internal {
        reward = next_reward;
        bool is_restart = wake_up_time > uint64(now);
        wake_up_time = getNextWakeUpTime(period, start);
        address addr = address.makeAddrExtern(0x4242424242424242, 64);
        
        emit WakeUpRequest{dest: addr}(
            address(this), 
            owner_address, 
            owner_public_key, 
            random_value,
            wake_up_time, 
            reward,
            is_restart
        );
    }

    function getNextWakeUpTime(
        uint64 period_, 
        uint64 start_
    ) private returns (uint64 next_wake_up_time) {
        if (start_ == 0xFFFFFFFFFFFFFFFF) {      // alignment disabled
            return (uint64(now) + period_);
        } else {
            uint64 time_until_next_wake_up_time = period_ - ((uint64(now) - start_) % period_);
            return (uint64(now) + time_until_next_wake_up_time);
        }
    }



    /* Get-Method */

    function getInfo() external view returns ( 
        uint256 _owner_public_key,
        address _owner_address,
        uint256 _random_value, 
        uint64 _wake_up_time,
        uint128 _reward,
        uint128 _next_reward,
        address _notify_address,
        bool _repeat_request,
        uint64 _period,
        uint64 _start
    ) {
        return (
            owner_public_key,
            owner_address,
            random_value, 
            wake_up_time,
            reward,
            next_reward,
            notify_address,
            repeat_request,
            period,
            start
        );
    }
}
