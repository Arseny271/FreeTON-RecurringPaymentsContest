const { rl } = require("../utils");

const ACCOUNT_TYPE_UNINITIALIZED = 0;
const ACCOUNT_TYPE_ACTIVE = 1;
const CONTRACT_REQUIRED_DEPLOY_TOKENS = 100_000_000;

class Contract {
    constructor(tonClient, contract) {
        this.tonClient = tonClient;
        this.contract = contract;
    }

    async setInitParams(signer, initial_data, input) {
        this.signer = signer;
        this.constructor_encode_params = {
            abi: this.contract.abi,
            deploy_set: {
                tvc: this.contract.tvc,
                initial_data
            },
            call_set: {
                function_name: "constructor",
                input
            },
            signer,
            processing_try_index: 1
        }

        const { address } = await this.tonClient.abi.encode_message(
            this.constructor_encode_params);

        this.address = address;
    }

    async deploy() {
        while (true) {
            const result = (await this.tonClient.net.query_collection({
                collection: "accounts",
                filter: {
                    id: {
                        eq: this.address,
                    },
                },
                result: "acc_type balance code",
            })).result;
    
            if (result.length === 0) {
                await new Promise(resolve => {
                    rl.question(`You need to transfer at least 0.1 token for deploy to ${this.address} to net.ton.dev.`, function(answer) {
                        resolve(answer.split(''));
                    });
                });
    
                continue;
            }
    
            if (result[0].acc_type === ACCOUNT_TYPE_ACTIVE) {
                console.log(`Contract ${this.address} is already deployed`);
                return false;
            }
    
            if (result[0].acc_type === ACCOUNT_TYPE_UNINITIALIZED && BigInt(result[0].balance) <= BigInt(
                CONTRACT_REQUIRED_DEPLOY_TOKENS)) {
                console.log(`Balance of ${this.address} is too low for deploy to net.ton.dev`);
                await new Promise(resolve => {
                    rl.question(`You need to transfer at least 0.1 token for deploy to ${this.address} to net.ton.dev.`, function(answer) {
                        resolve(answer.split(''));
                    });
                });
    
                continue;
            }
    
            break;
        }

        const response = await this.tonClient.processing.process_message({
            send_events: false, message_encode_params: this.constructor_encode_params
        });
    
        console.log(`Transaction id is ${response.transaction.id}`);
        console.log(`Contract is successfully deployed at ${this.address}`);

        return response;
    }

    async callSigned(function_name, input) {
        const response = await this.tonClient.processing.process_message({
            send_events: false, 
            message_encode_params: {
                abi: this.contract.abi, 
                address: this.address,
                call_set: { function_name, input },
                signer: this.signer,
                processing_try_index: 1
            }
        });

        console.log(`Transaction id is ${response.transaction.id}`);
        console.log(`Function called successfully at ${this.address}`);

        return response;
    }
    
    async callGet(address, method, input) {
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
                abi: this.contract.abi, 
                address,
                call_set: { function_name: method, input: {
                    _answer_id: 1
                } },
                signer: { type: 'None' }
            }).then(({ message }) => message)
        ]);

        return (await this.tonClient.tvm.run_tvm({ 
            message, account, 
            abi: this.contract.abi 
        })).decoded.output;
    }
}

module.exports = { Contract };