const { loadTerms, loadContract, getPreparedSigner, rl } = require("./utils");
const { ROOT_TIMER_CONTRACT } = require("./contracts");
const { TIMER_CONTRACT } = require("./contracts");

const ACCOUNT_TYPE_UNINITIALIZED = 0;
const ACCOUNT_TYPE_ACTIVE = 1;

const CONTRACT_REQUIRED_DEPLOY_TOKENS = 500_000_000;

class TimerContract {
    constructor(tonClient) {
        this.tonClient = tonClient;
    }

    async getAddress(signer, random, owner_address) {
        const message_encode_params = {
            abi: TIMER_CONTRACT.abi,
            deploy_set: {
                tvc: TIMER_CONTRACT.tvc,
                initial_data: {
                    owner_public_key: "0x" + signer.keys.public,
                    random_value: random, owner_address
                }
            },
            call_set: {
                function_name: "constructor",
                input: {}
            },
            signer,
            processing_try_index: 1
        }

        const { address } = await this.tonClient.abi.encode_message(message_encode_params);
        return address;
    }

    async callSigned(signer, random, function_name, input) {
        const address = await this.getAddress(signer, random, "0:0000000000000000000000000000000000000000000000000000000000000000");
        return await this.tonClient.processing.process_message({
            send_events: false, 
            message_encode_params: {
                abi: TIMER_CONTRACT.abi, address,
                call_set: { function_name, input },
                signer,
                processing_try_index: 1
            }
        });
    }

    async deployRoot(signer, timer_code ) {
        const message_encode_params = {
            abi: ROOT_TIMER_CONTRACT.abi,
            deploy_set: {
                tvc: ROOT_TIMER_CONTRACT.tvc,
                initial_data: {
                    timer_code
                }
            },
            call_set: {
                function_name: "constructor",
                input: {}
            },
            signer,
            processing_try_index: 1
        }

        const { address } = await this.tonClient.abi.encode_message(message_encode_params);
        while (true) {
            const result = (await this.tonClient.net.query_collection({
                collection: "accounts",
                filter: {
                    id: {
                        eq: address,
                    },
                },
                result: "acc_type balance code",
            })).result;
    
            if (result.length === 0) {
                await new Promise(resolve => {
                    rl.question(`You need to transfer at least 1 token for deploy to ${address} to net.ton.dev.`, function(answer) {
                        resolve(answer.split(''));
                    });
                });
    
                continue;
            }
    
            if (result[0].acc_type === ACCOUNT_TYPE_ACTIVE) {
                console.log(`Contract ${address} is already deployed`);
                return false;
            }
    
            if (result[0].acc_type === ACCOUNT_TYPE_UNINITIALIZED && BigInt(result[0].balance) <= BigInt(
                CONTRACT_REQUIRED_DEPLOY_TOKENS)) {
                console.log(`Balance of ${address} is too low for deploy to net.ton.dev`);
                await new Promise(resolve => {
                    rl.question(`You need to transfer at least 1 token for deploy to ${address} to net.ton.dev.`, function(answer) {
                        resolve(answer.split(''));
                    });
                });
    
                continue;
            }
    
            break;
        }


        const response = await this.tonClient.processing.process_message({
            send_events: false, message_encode_params
        });
    
        console.log(`Transaction id is ${response.transaction.id}`);
        console.log(`Deploy fees are  ${JSON.stringify(response.fees, null, 2)}`);
        console.log(`Contract is successfully deployed at ${address}`);

        return true;

    }

    async deploy(signer, random) {
        const address = await this.getAddress(signer, random, "0:0000000000000000000000000000000000000000000000000000000000000000");

        while (true) {
            const result = (await this.tonClient.net.query_collection({
                collection: "accounts",
                filter: {
                    id: {
                        eq: address,
                    },
                },
                result: "acc_type balance code",
            })).result;
    
            if (result.length === 0) {
                await new Promise(resolve => {
                    rl.question(`You need to transfer at least 1 token for deploy to ${address} to net.ton.dev.`, function(answer) {
                        resolve(answer.split(''));
                    });
                });
    
                continue;
            }
    
            if (result[0].acc_type === ACCOUNT_TYPE_ACTIVE) {
                console.log(`Contract ${address} is already deployed`);
                return false;
            }
    
            if (result[0].acc_type === ACCOUNT_TYPE_UNINITIALIZED && BigInt(result[0].balance) <= BigInt(
                CONTRACT_REQUIRED_DEPLOY_TOKENS)) {
                console.log(`Balance of ${address} is too low for deploy to net.ton.dev`);
                await new Promise(resolve => {
                    rl.question(`You need to transfer at least 1 token for deploy to ${address} to net.ton.dev.`, function(answer) {
                        resolve(answer.split(''));
                    });
                });
    
                continue;
            }
    
            break;
        }

        const response = await this.tonClient.processing.process_message({
            send_events: false, message_encode_params: {
                abi: TIMER_CONTRACT.abi,
                deploy_set: {
                    tvc: TIMER_CONTRACT.tvc,
                    initial_data: {
                        owner_address: "0:0000000000000000000000000000000000000000000000000000000000000000",
                        owner_public_key: "0x" + signer.keys.public,
                        random_value: random
                    }
                },
                call_set: {
                    function_name: "constructor",
                    input: {}
                },
                signer,
                processing_try_index: 1
            }
        });
    
        console.log(`Transaction id is ${response.transaction.id}`);
        console.log(`Deploy fees are  ${JSON.stringify(response.fees, null, 2)}`);
        console.log(`Contract is successfully deployed at ${address}`);

        return true;
    }

    async setParams(signer, random, input) {
        const address = await this.getAddress(signer, random, "0:0000000000000000000000000000000000000000000000000000000000000000");
        const response = await this.callSigned(signer, random, "setTimerParams", input);
    
        console.log(`Transaction id is ${response.transaction.id}`);
        console.log(`Fees are  ${JSON.stringify(response.fees, null, 2)}`);
        console.log(`the timer at address ${address} is configured with the following parameters: ${input}`);
    }

    async start(signer, random) {
        const address = await this.getAddress(signer, random, "0:0000000000000000000000000000000000000000000000000000000000000000");
        const response = await this.callSigned(signer, random, "startTimer", {});
    
        console.log(`Transaction id is ${response.transaction.id}`);
        console.log(`Fees are  ${JSON.stringify(response.fees, null, 2)}`);
        console.log(`Timer at address ${address} started successfully.`);
    }

    async send(signer, random, input) {
        const address = await this.getAddress(signer, random, "0:0000000000000000000000000000000000000000000000000000000000000000");
        const response = await this.callSigned(signer, random, "sendValue", input);
    
        console.log(`Transaction id is ${response.transaction.id}`);
        console.log(`Fees are  ${JSON.stringify(response.fees, null, 2)}`);
        console.log(`Funds from the contract at address ${address} have been successfully withdrawn`);
    }

    async get(address, method, input) {
        const [account, message] = await Promise.all([
            this.tonClient.net.query_collection({
                collection: 'accounts',
                filter: { id: { eq: address } },
                result: 'boc'
            })
            .then(({ result }) => result[0].boc)
            .catch(() => {
                throw Error(`Failed to fetch account data`)
            }),

            this.tonClient.abi.encode_message({
                abi: TIMER_CONTRACT.abi, address,
                call_set: { function_name: method, input },
                signer: { type: 'None' }
            }).then(({ message }) => message)
        ]);

        const response = await this.tonClient.tvm.run_tvm({ message, account, abi: TIMER_CONTRACT.abi });
        console.log('Get Method result:', response.decoded.output);
    }

    async wakeUp(address, reward_to ) {
        await this.tonClient.processing.process_message({
            send_events: false, 
            message_encode_params: {
                abi: TIMER_CONTRACT.abi, address,
                call_set: { 
                    function_name: "timerWakeUp", 
                    input: {
                        reward_address: reward_to
                    }
                },
                signer: { type: 'None' },
                processing_try_index: 1
            }
        });
    }
}

module.exports = { TimerContract };