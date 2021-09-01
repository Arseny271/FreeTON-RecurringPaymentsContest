const { TonClient } = require("@tonclient/core");
const { libNode } = require("@tonclient/lib-node");

const { crc32, loadTokens, loadContract, getPreparedSigner } = require("./utils");
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

        const ACTION = process.argv[2];
        const TOKEN = loadTokens(process.argv[3]);

        const ROOT_TOKEN_WALLET_SIGNER = await getPreparedSigner(tonClient, `../keys/tokens.keypair`);
        const ROOT_TOKEN_WALLET = loadContract("broxus/RootTokenContract");
        
        const TON_TOKEN_WALLET = loadContract("broxus/TONTokenWallet");
        const TON_TOKEN_WALLET_CODE = (await tonClient.boc.get_code_from_tvc({tvc:TON_TOKEN_WALLET.tvc})).code;

        const RtwContractManager = new Contract(tonClient, ROOT_TOKEN_WALLET);
        await RtwContractManager.setInitParams(ROOT_TOKEN_WALLET_SIGNER, {
            _randomNonce: crc32(process.argv[3]), name: TOKEN.name.hexEncode(), symbol: TOKEN.symbol.hexEncode(), decimals: TOKEN.decimals, 
            wallet_code: TON_TOKEN_WALLET_CODE
        }, {
            root_public_key_: `0x${ROOT_TOKEN_WALLET_SIGNER.keys.public}`,
            root_owner_address_: "0:0000000000000000000000000000000000000000000000000000000000000000"
        });

        switch (ACTION) {
            case "deploy": {
                await RtwContractManager.deploy();
                break;
            }

            case "deploy-wallet": {
                console.log((await RtwContractManager.callSigned("deployWallet", {
                    tokens: process.argv[4], deploy_grams: "100_000_000", 
                    wallet_public_key_: `0x${ROOT_TOKEN_WALLET_SIGNER.keys.public}`,
                    owner_address_: "0:0000000000000000000000000000000000000000000000000000000000000000",
                    gas_back_address: "0:0000000000000000000000000000000000000000000000000000000000000000"
                })));
                break;
            }

            case "give": {
                await RtwContractManager.callSigned("mint", {
                    to: process.argv[4], tokens: process.argv[5]
                });
                break;
            }
        }

        process.exit(0);
    } catch (error) {
        console.error(error);
        process.exit(1);
    }
})();