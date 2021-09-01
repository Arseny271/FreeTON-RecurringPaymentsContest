const { TonClient } = require("@tonclient/core");
const { libNode } = require("@tonclient/lib-node");

const { loadTerms, loadContract, getPreparedSigner, rl } = require("./utils");
const { TIMER_CONTRACT_NAME, TIMER_CONTRACT } = require("./contracts");
const { TimerContract } = require("./timer-contract");

TonClient.useBinaryLibrary(libNode);

(async () => {
    try {
        const tonClient = new TonClient({
            network: {
                endpoints: ["net1.ton.dev", "net5.ton.dev"],
                message_processing_timeout: 60000,
                message_retries_count: 3
            },
        });

        const TimerContractManager = new TimerContract(tonClient);
        const TIMER_CONTRACT_SIGNER = await getPreparedSigner(tonClient, `../keys/${TIMER_CONTRACT_NAME}.keypair`);

        const ACTION = process.argv[2];
        switch (ACTION) {
            case "help": {

                break;
            }

            case "deploy": {
                await TimerContractManager.deploy(TIMER_CONTRACT_SIGNER, 0);
                break;
            }

            case "deploy-root": {
                const timer_code = (await tonClient.boc.get_code_from_tvc({tvc:TIMER_CONTRACT.tvc})).code;
                await TimerContractManager.deployRoot(TIMER_CONTRACT_SIGNER, timer_code);
                break;
            }

            case "set": {
                await TimerContractManager.setParams(TIMER_CONTRACT_SIGNER, 0, {
                    new_notify_address: process.argv[3],
                    new_reward: process.argv[4],
                    new_period: process.argv[5],
                    new_start: process.argv[6],
                    need_repeat: process.argv[7]
                });
                break;
            }

            case "get": {
                await TimerContractManager.get( process.argv[3], process.argv[4]);
                break;
            }

            case "start": {
                await TimerContractManager.start(TIMER_CONTRACT_SIGNER, 0);
                break;
            }

            case "wakeup": {
                await TimerContractManager.wakeUp(process.argv[3], process.argv[4]);
                break;
            }

        }

        process.exit(0);
    } catch (error) {
        console.error(error);
        process.exit(1);
    }
})()