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

        const WALLET_CONTRACT = loadContract("MultitokenWallet");
        const WALLET_CONTRACT_SIGNER = await getPreparedSigner(tonClient, `../keys/MultitokenWallet.keypair`);

        const WalletContractManager = new Contract(tonClient, WALLET_CONTRACT);
        await WalletContractManager.setInitParams(WALLET_CONTRACT_SIGNER, {}, {});

        const ACTION = process.argv[2];
        switch (ACTION) {
            case "deploy": {
                await WalletContractManager.deploy();
                break;
            }

            case "new": {
              await WalletContractManager.callSigned("walletDeployTonTokenWallet", {
                  root_token_wallet: process.argv[3]
              });
              break;
            }

            case "add": {
                await WalletContractManager.callSigned("walletAddTonTokenWallet", {
                    root_token_wallet: process.argv[3],
                    need_deploy: true,
                    need_receive_callback: false,
                    allow_non_notifiable: true,
                    need_bounce_callback: false
                });
                break;
            }

            case "get": {
                console.log((await WalletContractManager.callGet(process.argv[3], process.argv[4], process.argv[5])).value0);
                break;
            }
        }

        process.exit(0);
    } catch (error) {
        console.error(error);
        process.exit(1);
    }
})();
