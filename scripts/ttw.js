const { TonClient } = require("@tonclient/core");
const { libNode } = require("@tonclient/lib-node");

const { loadContract, getPreparedSigner } = require("./utils");
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

        const TON_TOKEN_WALLET_SIGNER = await getPreparedSigner(tonClient, `../keys/user-tokens.keypair`);
        const TON_TOKEN_WALLET = loadContract("broxus/TONTokenWallet");
        const TON_TOKEN_WALLET_CODE = (await tonClient.boc.get_code_from_tvc({tvc:TON_TOKEN_WALLET.tvc})).code;

        const TtwContractManager = new Contract(tonClient, TON_TOKEN_WALLET);
        /*await TtwContractManager.setInitParams(TON_TOKEN_WALLET_SIGNER, {
            _randomNonce: 0, name: "AnusToken".hexEncode(), symbol: "ANUS".hexEncode(), decimals: 2, 
            wallet_code: TON_TOKEN_WALLET_CODE
        }, {
            root_public_key_: `0x${ROOT_TOKEN_WALLET_SIGNER.keys.public}`,
            root_owner_address_: "0:0000000000000000000000000000000000000000000000000000000000000000"
        });*/

        const ACTION = process.argv[2];
        switch (ACTION) {
            /*case "deploy": {
                await RtwContractManager.deploy();
                break;
            }*/

            case "get": {
                console.log(await TtwContractManager.callGet(process.argv[3], process.argv[4]));
                break;
            }
        }

        process.exit(0);
    } catch (error) {
        console.error(error);
        process.exit(1);
    }
})();