const { TonClient } = require("@tonclient/core");
const { libNode } = require("@tonclient/lib-node");
const { rl } = require("./utils");

const { TIMER_CONTRACT } = require("./contracts");
const { TimerContract } = require("./timer-contract");

TonClient.useBinaryLibrary(libNode);

(async () => {
    try {
        const tonClient = new TonClient({
            network: {
                endpoints: ["net1.ton.dev", "net5.ton.dev"],
                message_processing_timeout: 60000,
                message_retries_count: 3
            }
        });

        const TimerContractManager = new TimerContract(tonClient);

        async function onEventCallback(params, responseType) {
            try {
                if (responseType !== 100) throw new Error();

                const decoded = (await tonClient.abi.decode_message({
                    abi: TIMER_CONTRACT.abi,
                    message: params.result.boc
                }));

                const timeout = -(Math.floor(Date.now() / 1000) - decoded.value.wakeup_time);
                if (timeout > 0) {

                    console.log(`| New Request | ${decoded.value.wakeup_time} | ${decoded.value.timer_address} | ${decoded.value.reward} |`);
                    console.log(`+-------------+------------+--------------------------------------------------------------------+----------+`);

                    const wakeupFunction = () => {
                        TimerContractManager.wakeUp(decoded.value.timer_address, process.argv[2])
                        .then(() => {
                            console.log(`|   Success   | ${decoded.value.wakeup_time} | ${decoded.value.timer_address} | ${decoded.value.reward} |`);
                            console.log(`+-------------+------------+--------------------------------------------------------------------+----------+`);
                        })
                        .catch(() => {
                            console.log(`|     Fail    | ${decoded.value.wakeup_time} | ${decoded.value.timer_address} | 0        |`);
                            console.log(`+-------------+------------+--------------------------------------------------------------------+----------+`);
                        });
                    }

                    setTimeout(wakeupFunction, timeout * 1000);
                }
            } catch (e) {
                console.log(`+-------------+------------+--------------------------------------------------------------------+----------+`);
                console.log(`| Error       | Code: ${responseType}  |                                                                    |          |`);
                console.log(`+-------------+------------+--------------------------------------------------------------------+----------+`);
                console.log(e);
                console.log(`+-------------+------------+--------------------------------------------------------------------+----------+`);
            }
        }


        const subscriptionMessageHandle = (await tonClient.net.subscribe_collection({
            collection: 'messages',
            filter: {
                dst: { eq: ":4242424242424242" },
            },
            result: "boc",
        }, onEventCallback)).handle;

        console.log(`+-------------+------------+--------------------------------------------------------------------+----------+`);
        console.log(`| Event type  |    Time    |                              Address                               |  Reward  |`);
        console.log(`+-------------+------------+--------------------------------------------------------------------+----------+`);

    } catch (error) {
        console.error(error);
        process.exit(1);
    }
})()
