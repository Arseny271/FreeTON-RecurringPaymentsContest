const { loadTerms, loadContract, getPreparedSigner, rl } = require("./utils");
const { ACCESS_CONTROLL_CONTRACT_NAME, ACCESS_CONTROLL_CONTRACT } = require("./contracts");

const ACCOUNT_TYPE_UNINITIALIZED = 0;
const ACCOUNT_TYPE_ACTIVE = 1;

const CONTRACT_REQUIRED_DEPLOY_TOKENS = 500_000_000;

class AccessControllContract {

    constructor(tonClient, terms, user) {
        this.tonClient = tonClient;
        this.terms = terms;
        this.user = user;
    }

    async getAddress(signer) {
        const message_encode_params = {
            abi: ACCESS_CONTROLL_CONTRACT.abi,
            deploy_set: {
                tvc: ACCESS_CONTROLL_CONTRACT.tvc,
                initial_data: {}
            },
            call_set: {
                function_name: "constructor",
                input: {
                    terms: this.terms,
                    user_info: this.user
                }
            },
            signer,
            processing_try_index: 1
        }

        const { address } = await this.tonClient.abi.encode_message(message_encode_params);
        return address;
    }

    async callSigned(signer, function_name, input) {
        const address = await this.getAddress(signer);
        return await this.tonClient.processing.process_message({
            send_events: false, 
            message_encode_params: {
                abi: ACCESS_CONTROLL_CONTRACT.abi, address,
                call_set: { function_name, input },
                signer,
                processing_try_index: 1
            }
        });
    }

    async deploy(signer) {
        const address = await this.getAddress(signer);

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
                abi: ACCESS_CONTROLL_CONTRACT.abi,
                deploy_set: {
                    tvc: ACCESS_CONTROLL_CONTRACT.tvc,
                    initial_data: {}
                },
                call_set: {
                    function_name: "constructor",
                    input: {
                        terms: this.terms,
                        user_info: this.user
                    }
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
                abi: ACCESS_CONTROLL_CONTRACT.abi, address,
                call_set: { function_name: method, input },
                signer: { type: 'None' }
            }).then(({ message }) => message)
        ]);

        const response = await this.tonClient.tvm.run_tvm({ message, account, abi: ACCESS_CONTROLL_CONTRACT.abi });
        console.log('Get Method result:', response.decoded.output);
    }
}

module.exports = { AccessControllContract };