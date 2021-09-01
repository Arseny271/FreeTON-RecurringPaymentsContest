const { TonClient } = require("@tonclient/core");
const { libNode } = require("@tonclient/lib-node");

const { loadContract, getPreparedSigner, rl } = require("./utils");
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

        const DEBOT_DEPLOYER_CONTRACT = loadContract("DebotDeployer");

        const MULTITOKEN_WALLET = loadContract("MultitokenWallet");
        const MULTITOKEN_WALLET_CODE = (await tonClient.boc.get_code_from_tvc({tvc:MULTITOKEN_WALLET.tvc})).code;

        const DEBOT_CONTRACT = loadContract("UniversalDebot");
        const DEBOT_CONTRACT_CODE = (await tonClient.boc.get_code_from_tvc({tvc:DEBOT_CONTRACT.tvc})).code;
        const DEBOT_ABI_HEX = JSON.stringify(DEBOT_CONTRACT.abi.value).hexEncode();
        const DEBOT_CONTRACT_SIGNER = await getPreparedSigner(tonClient, `../keys/debots.keypair`);
        const DebotContractManager = new Contract(tonClient, DEBOT_CONTRACT);
        await DebotContractManager.setInitParams(DEBOT_CONTRACT_SIGNER, {}, {});

        const DebotDeployerContractManager = new Contract(tonClient, DEBOT_DEPLOYER_CONTRACT);
        await DebotDeployerContractManager.setInitParams(DEBOT_CONTRACT_SIGNER, {
            m_debotCode: DEBOT_CONTRACT_CODE
        }, {});
        
        const ACTION = process.argv[2];
        switch (ACTION) {
            case "deployer": {
                const deploy_result = await DebotDeployerContractManager.deploy();
                if (deploy_result) {
                    const result = await DebotDeployerContractManager.callSigned("deploy", {
                        m_walletCode: MULTITOKEN_WALLET_CODE,
                        m_dabi: DEBOT_ABI_HEX
                    });
                    console.log(result);
                }

                break;
            }
            
            case "deploy": {
                
                const DEBOT_ABI_SLICES = DEBOT_ABI_HEX.match(/.{1,4096}/g);
                const deploy_result = await DebotContractManager.deploy();

                if (deploy_result) {    
                    /*await DebotContractManager.callSigned("setWalletCode", {
                        multiwalletCode: MULTITOKEN_WALLET_CODE
                    });*/

                    await DebotContractManager.callSigned("setABI", {
                        dabi: DEBOT_ABI_SLICES[0]
                    });

                    console.log("set abi");


                    

                    //console.log("set code");
    
                    /*for (let i = 1; i < DEBOT_ABI_SLICES.length; i++) {
                        await DebotContractManager.callSigned("attachABI", {
                            dabi: DEBOT_ABI_SLICES[i]
                        });
                    }*/
                } else {
                    process.exit(0);
                }
                break;
            }
        }

        process.exit(0);
    } catch (error) {
        console.error(error);
        process.exit(1);
    }
})()