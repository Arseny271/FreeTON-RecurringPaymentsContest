const { TonClient } = require("@tonclient/core");
const { libNode } = require("@tonclient/lib-node");

const { loadTerms, loadContract, getPreparedSigner, rl } = require("./utils");
const { ACCESS_CONTROLL_CONTRACT_NAME } = require("./contracts");
const { AccessControllContract } = require("./access-controll-contract");

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

        const ACCESS_CONTROLL_CONTRACT_SIGNER = await getPreparedSigner(tonClient, `../keys/${ACCESS_CONTROLL_CONTRACT_NAME}.keypair`);
        const TERMS_INFO = loadTerms("TERM_1");
        const USER_INFO = {
            wallet_for_spend: "0:3db64f52fe36b6182789780bed728574c961061b911a18a56e7dace0b5472b6f",
            tokens_source: "0:3db64f52fe36b6182789780bed728574c961061b911a18a56e7dace0b5472b6f",
            timer_contract: "0:3e3c6bc49b049e67459016faae111dfa7f47d7beff23350218842e64c633073a",
            timer_reward: "100_000_000"
        };
        TERMS_INFO.shipper_pubkey = `0x${ACCESS_CONTROLL_CONTRACT_SIGNER.keys.public}`;

        const AccessControllContractManager = new AccessControllContract(tonClient, TERMS_INFO, USER_INFO);

        const ACTION = process.argv[2];
        switch (ACTION) {

            case "deploy": {
                await AccessControllContractManager.deploy(ACCESS_CONTROLL_CONTRACT_SIGNER);
                break;
            }

            case "get": {
                await AccessControllContractManager.get( process.argv[3], process.argv[4]);
                break;
            }
        }

        process.exit(0);
    } catch (error) {
        console.error(error);
        process.exit(1);
    }
})()