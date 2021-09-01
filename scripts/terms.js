const { TonClient } = require("@tonclient/core");
const { libNode } = require("@tonclient/lib-node");

const { crc32, loadTerms, loadContract, getPreparedSigner } = require("./utils");
const { Contract } = require("./contracts/contract");

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

        const TERMS_CONTRACT = loadContract("SubscriptionTermsV2");
        const TERMS_CONTRACT_SIGNER = await getPreparedSigner(tonClient, `../keys/terms.keypair`);
        const TermsContractManager = new Contract(tonClient, TERMS_CONTRACT);

        const ACTION = process.argv[2];
        switch (ACTION) {
            case "deploy": {
                const BROKER_CONTRACT = loadContract("AccessControll");
                const BROKER_CONTRACT_CODE = (await tonClient.boc.get_code_from_tvc({tvc:BROKER_CONTRACT.tvc})).code;

                const TERMS_INFO = loadTerms(process.argv[3]);
                TERMS_INFO.shipper_pubkey = `0x${TERMS_CONTRACT_SIGNER.keys.public}`;
                TERMS_INFO.name = TERMS_INFO.name.hexEncode();
                TERMS_INFO.info = TERMS_INFO.info.hexEncode();

                await TermsContractManager.setInitParams(TERMS_CONTRACT_SIGNER, {
                    mediator_contract_code: BROKER_CONTRACT_CODE, random_value: crc32(process.argv[3])
                }, {subscription_terms: TERMS_INFO});

                await TermsContractManager.deploy();
                break;
            }
        }

        process.exit(0);
    } catch (error) {
        console.error(error);
        process.exit(1);
    }
})();
