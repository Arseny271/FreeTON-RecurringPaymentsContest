pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;
pragma AbiHeader time;


import "../../interfaces/Debots/Debot.sol";
import "../../interfaces/Debots/AddressInput.sol";
import "../../interfaces/Debots/AmountInput.sol";
import "../../interfaces/Debots/ConfirmInput.sol";
import "../../interfaces/Debots/SigningBoxInput.sol";
import "../../interfaces/Debots/Terminal.sol";
import "../../interfaces/Debots/UserInfo.sol";
import "../../interfaces/Debots/Menu.sol";
import "../../interfaces/Debots/Sdk.sol";
import "../../interfaces/Debots/QRCode.sol";

import "../../interfaces/TIP3-broxus/IRootTokenContract.sol";
import "../../interfaces/TIP3-broxus/ITONTokenWallet.sol";

import "../../structs/SpendTerms.sol";
import "../../structs/SubscriptionTerms.sol";
import "../../structs/UserWalletInformation.sol";
import "../../structs/RootTokenWalletInfo.sol";

import "../../abstract/AbstractService.sol";
import "../../abstract/MultitokenManager.sol";

import "../SubscriptionTermsV2.sol";
import "../MultitokenWallet.sol";


contract UserDebot is Debot {

    /* Setters */

    bytes m_icon;

    function setIcon(bytes icon) external {
        tvm.accept();
        m_icon = icon;
    }

    bool wallet_code_setted = false;
    function setWalletCode(TvmCell multiwalletCode) external { 
        require(!wallet_code_setted);
        tvm.accept();
        m_walletCode = multiwalletCode;
        wallet_code_setted = true;
    }

    bool abi_setted = false;
    function setABI_(string dabi) external {
        require(!abi_setted);
        tvm.accept();
        setABI(dabi);
        abi_setted = true;
    }

    TvmCell m_walletCode;

    address m_subscriptionTermsAddress;

    SubscriptionTerms m_subscriptionTerms;
    TvmCell m_mediatorContractCode;

    uint256 m_userPubkey;
    address m_userWallet;
    address m_mediatorAddress;

    address[] m_spendersList;
    address[] m_rootTokenWalletList;
    address m_spenderSelected;
    address m_tonTokenWalletSelected;
        
    uint128 m_tonTokensValueToSend;
    address m_brokerTip3Address;

    address m_addressToSendCrystals;
    address m_addressToSendTokens;
    address m_rootTokenAddressToDeployTTW;


    /* Update Ton Token Wallet Info Utils */
    mapping(address => RootTokenWalletInfo) m_tonTokensMapping;
    mapping(address => IRootTokenContract.IRootTokenContractDetails) m_rootTokensDetails;
    uint32 m_tonTokensWalletCounter;
    uint32 m_onUpdateTonTokenWallets;

    function updateTonTokenWalletsInfo(uint32 afterUpdateId) private {
        m_onUpdateTonTokenWallets = afterUpdateId;
        getWalletTonTokenWallets(tvm.functionId(onGetTonTokenWalletsMapping_), tvm.functionId(startDeBot));
    }

    function onGetTonTokenWalletsMapping_(mapping (address => RootTokenWalletInfo) wallets) public {
        m_tonTokensMapping = wallets;
        m_tonTokensWalletCounter = 0;
        optional(uint256) none;

        for ((address root, RootTokenWalletInfo info) : wallets) { 
            if (info.trust) {
                m_tonTokensWalletCounter += 1;
                IRootTokenContract(root).getDetails{
                    abiVer: 2,
                    extMsg: true,
                    sign: false,
                    pubkey: none,
                    time: uint64(now),
                    expire: 0,
                    callbackId: tvm.functionId(onGetTonTokenWalletsDetails_),
                    onErrorId: tvm.functionId(onGetTonTokenWalletsError_)
                }();
            }
        }

        if (m_tonTokensWalletCounter == 0) {
            onGetTonTokenWalletsAll();
        }
    }

    function onGetTonTokenWalletsDetails_(IRootTokenContract.IRootTokenContractDetails details) public {
        m_rootTokensDetails[msg.sender] = details;
        m_tonTokensWalletCounter -= 1;
        if (m_tonTokensWalletCounter == 0) {
            onGetTonTokenWalletsAll();
        }
    }

    function onGetTonTokenWalletsError_() public {
        m_tonTokensWalletCounter -= 1;
        if (m_tonTokensWalletCounter == 0) {
            onGetTonTokenWalletsAll();
        }
    }

    function onGetTonTokenWalletsAll() public {
        if (m_onUpdateTonTokenWallets == tvm.functionId(showMainMenu)) {
            showMainMenu();
        } else if (m_onUpdateTonTokenWallets == tvm.functionId(showAllActiveWallets)) {
            showAllActiveWallets();
        }
    }


    /* Update Subscriptions Info Util */
    mapping(address => SpendInfo) m_spendersMapping;    // all spenders
    mapping(address => uint64) m_subAvailableUntil;     // aviable service time
    mapping(address => bool) m_subIsActive;             // true if service active    
    uint32 m_serviceCounter;
    uint32 m_onUpdateActiveSubscriptions;

    function updateActiveSubscriptionsInfo(uint32 afterUpdateId) private {
        m_onUpdateActiveSubscriptions = afterUpdateId;
        getWalletActiveSpenders(tvm.functionId(onGetActiveSubscriptionsMapping));  
    }

    function onGetActiveSubscriptionsMapping(mapping(address => SpendInfo) spenders) public {
        m_spendersMapping = spenders;
        m_serviceCounter = 0;

        for ((address service, SpendInfo info) : spenders) { 
            m_serviceCounter += 1;
            getWalletServiceAviable(service, tvm.functionId(onGetActiveSubscriptionTime), tvm.functionId(onGetActiveSubscriptionError));
        }

        if (m_serviceCounter == 0) {
            onGetActiveSubscriptionsAll();
        }
    }

    function onGetActiveSubscriptionTime(uint64 time) public {
        m_subAvailableUntil[msg.sender] = time;
        m_subIsActive[msg.sender] = uint64(now) < time;
        m_serviceCounter -= 1;
        if (m_serviceCounter == 0) {
            onGetActiveSubscriptionsAll();
        }
    }

    function onGetActiveSubscriptionError() public {
        m_subAvailableUntil[msg.sender] = 0;
        m_subIsActive[msg.sender] = false;
        m_serviceCounter -= 1;
        if (m_serviceCounter == 0) {
            onGetActiveSubscriptionsAll();
        }
    }

    function onGetActiveSubscriptionsAll() public {
        if (m_onUpdateActiveSubscriptions == tvm.functionId(updateTonTokenWallets)) {
            updateTonTokenWallets();
        } else if (m_onUpdateActiveSubscriptions == tvm.functionId(onUpdateActiveSubscr)) {
            onUpdateActiveSubscr();
        }   
    }









    /* Start */

    function startDeBot() public {
        UserInfo.getPublicKey(tvm.functionId(onGetDefaultPubkey));        
    }

    function onGetDefaultPubkey(uint256 value) public { 
        m_userPubkey = value;

        if (value == 0) {
            getUserWallet();
        } else {
            TvmCell stateInit = tvm.buildStateInit({
                contr: MultitokenWallet, varInit: {},
                pubkey: value, code: m_walletCode
            });

            m_userWallet = address(tvm.hash(stateInit));
            Sdk.getAccountType(tvm.functionId(onCheckUserWalletType), m_userWallet);
        }
    }

    function onCheckUserWalletType(int8 acc_type) public {
        if (acc_type == -1 || acc_type == 0 || acc_type == 2) {
            getUserWallet();
        } else {
            ConfirmInput.get(tvm.functionId(onGetUserWalletSelect_), format("Want to use an existing wallet at {}?", m_userWallet));
        }
    }

    function onGetUserWalletSelect_(bool value) public {
        if (value) {
            updateWalletInfo();
        } else {
            getUserWallet();
        }
    }

    function getUserWallet() public {
        AddressInput.get(tvm.functionId(onGetUserWallet), "Enter the address of the wallet with support for subscriptions");
    }

    function onGetUserWallet(address value) public {
        m_userWallet = value;
        Sdk.getAccountType(tvm.functionId(onGetUserWalletType), value);
    }

    function onGetUserWalletType(int8 acc_type) public {
        if (!checkAddressActiveStatus(acc_type, "Wallet")) {
            startDeBot(); return;}

        updateWalletInfo();
    }

    function updateWalletInfo() public  {
        updateActiveSubscriptionsInfo(tvm.functionId(updateTonTokenWallets));       
    }

    function updateTonTokenWallets() public {
        updateTonTokenWalletsInfo(tvm.functionId(showMainMenu));
    }



    /* Main menu */

    function showMainMenu() public {
        Menu.select("Main menu.", "",[
            MenuItem("Send Tokens", "", tvm.functionId(showAllActiveWallets)),
            MenuItem("Get Tokens", "", tvm.functionId(startGettingTokens)),
            MenuItem("Add TIP-3 Wallet", "", tvm.functionId(createTonTokenWallet)),
            MenuItem("New subscription", "", tvm.functionId(newSubscription)),
            MenuItem("Subscriptions management", "", tvm.functionId(showActiveSubscriptions)),
            MenuItem("Change wallet", "", tvm.functionId(startDeBot))
        ]);
    }


    /* Get TIP-3 Tokens */

    function startGettingTokens() public {
        MenuItem[] items;
        items.push(MenuItem("TON Crystal (TON)", "", tvm.functionId(onRootTokenWalletSelectForGet)));
        delete m_rootTokenWalletList;
        for ((address root, IRootTokenContract.IRootTokenContractDetails value) : m_rootTokensDetails) {
            items.push(MenuItem(format("{} ({})", value.name, value.symbol), "", tvm.functionId(onRootTokenWalletSelectForGet)));
            m_rootTokenWalletList.push(root);
        }
        items.push(MenuItem("Back", "", tvm.functionId(showMainMenu)));
        Menu.select("Select", "", items);
    }

    function onRootTokenWalletSelectForGet(uint32 index) public {
        bytes text;
        address addr_to_send;

        if (index != 0) {
            address root_token_wallet = m_rootTokenWalletList[index -1];
            address ton_token_wallet = m_tonTokensMapping[root_token_wallet].ton_token_wallet;
            IRootTokenContract.IRootTokenContractDetails value = m_rootTokensDetails[root_token_wallet];

            text = format("{} ({})", value.name, value.symbol);
            addr_to_send = ton_token_wallet;
        } else {
            text = "TON Crystal (TON)";
            addr_to_send = m_userWallet;
        }

        QRCode.draw(tvm.functionId(showMainMenu), format("{} address {}", text, addr_to_send), format("{}", addr_to_send));
    }


    /* Send TIP-3 Token */

    function showAllActiveWallets() public {
        MenuItem[] items;
        items.push(MenuItem("TON Crystal (TON)", "", tvm.functionId(sendTonCrystal)));
        delete m_rootTokenWalletList;
        for ((address root, IRootTokenContract.IRootTokenContractDetails value) : m_rootTokensDetails) {
            items.push(MenuItem(format("{} ({})", value.name, value.symbol), "", tvm.functionId(onRootTokenWalletSelect)));
            m_rootTokenWalletList.push(root);
        }
        items.push(MenuItem("Back", "", tvm.functionId(showMainMenu)));
        Menu.select("Select", "", items);
    }

    function onRootTokenWalletSelect(uint32 index) public {
        address root_token_wallet = m_rootTokenWalletList[index -1];
        m_tonTokenWalletSelected = m_rootTokenWalletList[index -1];

        AddressInput.get(tvm.functionId(onTonTokenInputAddressForSend), "Enter the address for sending");
    }

    function onTonTokenInputAddressForSend(address value) public {
        address ton_token_wallet = m_tonTokensMapping[m_tonTokenWalletSelected].ton_token_wallet;
        m_addressToSendTokens = value;
        optional(uint256) none;
        ITONTokenWallet(ton_token_wallet).balance{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onTonTokenWalletGetBalance),
            onErrorId: tvm.functionId(onError)
        }();

    }

    function onTonTokenWalletGetBalance(uint128 value) public {
        uint8 decimals = m_rootTokensDetails[m_tonTokenWalletSelected].decimals;
        AmountInput.get(tvm.functionId(getTonTokenWalletGas), "Enter amount of tokens:", decimals, 0, value);
    }

    function getTonTokenWalletGas(uint128 value) public {
        m_tonTokensValueToSend = value;
        AmountInput.get(tvm.functionId(startSendingTokens), "Enter amount of gas:", 9, 0, 10000e9);
    }

    function startSendingTokens(uint128 value) public {
        address ton_token_wallet = m_tonTokensMapping[m_tonTokenWalletSelected].ton_token_wallet;

        TvmCell payload;
        MultitokenWallet(m_userWallet).walletSendTokens{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: m_userPubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onSuccess),
            onErrorId: tvm.functionId(onError)
        }(m_tonTokenWalletSelected, value, true, 1, 
            m_addressToSendTokens, m_tonTokensValueToSend, 
            0, ton_token_wallet, true, payload 
        );
    }



    /* Add TIP-3 Wallet */

    function onConfirmNewWallerCreation(bool value) public {
        if (!value) {
            showMainMenu();
            return;
        } else {
            onInputRootTokenAddress(m_subscriptionTerms.root_token_wallet);
        }
    }

    function createTonTokenWallet() public {
        AddressInput.get(tvm.functionId(onInputRootTokenAddress), "Enter the root TIP-3 wallet address");
    }

    function onInputRootTokenAddress(address value) public {
        if (m_tonTokensMapping.exists(value)) {
            Terminal.print(0, "The wallet has already been created.");
            showMainMenu();
            return;
        }

        m_rootTokenAddressToDeployTTW = value;
        optional(uint256) none;
        m_tonTokensWalletCounter += 1;
        IRootTokenContract(value).getDetails{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onGetTip3TokenRootDetailsForCreation),
            onErrorId: tvm.functionId(onError)
        }();
    }

    function onGetTip3TokenRootDetailsForCreation(IRootTokenContract.IRootTokenContractDetails details) public {
        bytes tokenInfo = format("{} ({})", details.name, details.symbol);
        Terminal.print(tvm.functionId(onRootTokenWalletInfoPrint), 
            format("{} \n", tokenInfo) +
            format("Tokens in circulation {} {}\n", getTokensValue(details.total_supply, details.decimals), details.symbol) +
            format("Root Token address: {}\n", m_rootTokenAddressToDeployTTW)
        );
    }   

    function onRootTokenWalletInfoPrint() public {
        MultitokenWallet(m_userWallet).walletDeployTonTokenWallet{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: m_userPubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onDeployTonTokenWallet),
            onErrorId: tvm.functionId(onError)
        }(m_rootTokenAddressToDeployTTW);
    }

    function onDeployTonTokenWallet() public {
        MultitokenWallet(m_userWallet).walletAddTonTokenWallet{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: m_userPubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onSuccess),
            onErrorId: tvm.functionId(onError)
        }(m_rootTokenAddressToDeployTTW, false, true, false);
    }





    /* Send TONS */

    function sendTonCrystal() public {
        AddressInput.get(tvm.functionId(onInputAddressForSend), "Enter the address for sending");
    }

    function onInputAddressForSend(address value) public {
        m_addressToSendCrystals = value;
        AmountInput.get(tvm.functionId(startSendingTons), "Enter amount of TONs:", 9, 0.1e9, 5000000000e9);
    }

    function startSendingTons(uint128 value) public {
        TvmCell payload;
        MultitokenWallet(m_userWallet).walletSendValue{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: m_userPubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onSuccess),
            onErrorId: tvm.functionId(onError)
        }(m_addressToSendCrystals, value, false, payload);
    }



    /* Subscriptions Management */

    function showActiveSubscriptions() public {
        updateActiveSubscriptionsInfo(tvm.functionId(onUpdateActiveSubscr));
    }

    function onUpdateActiveSubscr() public {
        MenuItem[] items;
        delete m_spendersList;
        for ((address key, SpendInfo value) : m_spendersMapping) {
            bytes status;
            if (m_subIsActive[key]) {
                status = "active";
            } else {
                status = "inactive";
            }
            items.push(MenuItem(format("{} ({})", value.terms.info, status), "", tvm.functionId(onSubscriptionSelect)));
            m_spendersList.push(key);
        }
        items.push(MenuItem("Back", "", tvm.functionId(showMainMenu)));
        Menu.select("Select", "", items);
    }

    function onSubscriptionSelect(uint32 index) public {
        m_spenderSelected = m_spendersList[index];
        SpendInfo info = m_spendersMapping.at(m_spendersList[index]);
        SpendTerms terms = info.terms;
        uint64 next_payment = info.time_of_next_payment;

        bytes tokenInfo;
        uint8 decimals;
        if (terms.root_token_wallet.value == 0) {
            tokenInfo = "TON Crystal (TON)";
            decimals = 9;
        } else {
            IRootTokenContract.IRootTokenContractDetails rtw_info 
                = m_rootTokensDetails[terms.root_token_wallet];
            
            tokenInfo = format("{} ({})", rtw_info.name, rtw_info.symbol);
            decimals = rtw_info.decimals;
        }

        Terminal.print(tvm.functionId(onPrintSpendTerms), 
            format("{}\n", terms.info) +
            format("  Currency: {}\n",          tokenInfo) + 
            format("  Amount of payment: {}\n", getTokensValue(terms.value, decimals)) +
            format("  Payment period: {}\n",    terms.period)
        );
    }

    function onPrintSpendTerms() public {       
        MenuItem[] actions;
        if (m_subIsActive[m_spenderSelected]) {
            actions.push(MenuItem("Unsubscribe", "", tvm.functionId(unsubscribeQuestion)));
        } else {
            actions.push(MenuItem("Resume", "", tvm.functionId(resumeSubscribtion)));
            actions.push(MenuItem("Unsubscribe", "", tvm.functionId(unsubscribeQuestion)));
        }

        actions.push(MenuItem("Back", "", tvm.functionId(showActiveSubscriptions)));

        Menu.select("Choose an action", "", actions);
    }

    function resumeSubscribtion() public {
        SpendInfo info = m_spendersMapping.at(m_spenderSelected);
        SpendTerms terms = info.terms;
        terms.start = uint64(now) - 2;

        MultitokenWallet(m_userWallet).approve{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: m_userPubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onSuccess),
            onErrorId: tvm.functionId(onError)
        }(m_spenderSelected, terms );
    }

    function unsubscribeQuestion() public {
        Terminal.print(0, format("{}", m_spenderSelected));
        ConfirmInput.get(tvm.functionId(onUnsubscribeByUser), "Are you sure you want to unsubscribe?");
    }

    function onUnsubscribeByUser(bool value) public {
        if (!value) {
            onPrintSpendTerms();
            return;
        }

        MultitokenWallet(m_userWallet).disapprove{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: m_userPubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onSuccess),
            onErrorId: tvm.functionId(onError)
        }(m_spenderSelected);
    }



    /* New subscription */

    // 1 - Check Terms address
    function newSubscription(uint32 index) public {
        AddressInput.get(tvm.functionId(onGetAddressOfNewSubscription), "Enter the address of the subscription terms.");
    }

    // 2 - Check Terms status
    function onGetAddressOfNewSubscription(address value) public {
        m_subscriptionTermsAddress = value;
        Sdk.getAccountType(tvm.functionId(onGetAddressSubscriptionTermsType), value);
    }


    // 3 - Check Terms Contract code
    function onGetAddressSubscriptionTermsType(int8 acc_type) public {
        if (!checkAddressActiveStatus(acc_type, "Terms")) {
            showMainMenu();
            return;
        }

        Sdk.getAccountCodeHash(tvm.functionId(onGetAddressSubscriptionTermsCodeHash), m_subscriptionTermsAddress);
    }


    // 4 - Get Terms info
    function onGetAddressSubscriptionTermsCodeHash(uint256 code_hash) public {
        if (!checkContractSubscriptionTermsCodeHash(code_hash)) {
            Terminal.print(0, "Terms contract has unverified code.");
            showMainMenu();
            return;
        }

        getSubscriptionTerms(tvm.functionId(onGetSubscriptionTerms));
    }


    // 5 - Get Terms Mediator code

    function onGetSubscriptionTerms(SubscriptionTerms terms) public {
        m_subscriptionTerms = terms;
        getSubscriptionMediator(tvm.functionId(onGetSubscriptionMediatorCode));
    }


    // 6 - Print Terms

    function onGetSubscriptionMediatorCode(TvmCell contract_code, uint256 code_hash) public {
        m_mediatorContractCode = contract_code;
        if (!checkContractMediatorCodeHash(code_hash)) {
            Terminal.print(0, "Mediator contract has unverified code.");
            showMainMenu();
            return;
        }

        bytes tokenInfo;
        uint8 decimals;
        if (m_subscriptionTerms.root_token_wallet.value == 0) {
            tokenInfo = "TON Crystal (TON)";
            decimals = 9;
        } else {
            if (m_rootTokensDetails.exists(m_subscriptionTerms.root_token_wallet)) {
                IRootTokenContract.IRootTokenContractDetails rtw_info 
                    = m_rootTokensDetails[m_subscriptionTerms.root_token_wallet];
                
                tokenInfo = format("{} ({})", rtw_info.name, rtw_info.symbol);
                decimals = rtw_info.decimals;
            } else {
                ConfirmInput.get(tvm.functionId(onConfirmNewWallerCreation), "The service requires payment in tokens that are not tied to your wallet. Create a new wallet?");
                return;
            }
        }

        Terminal.print(tvm.functionId(onPrintTerms), 
            format("{}\n", m_subscriptionTerms.name) +
            format("  Currency: {}\n", tokenInfo) + 
            format("  Amount of payment: {}\n", getTokensValue(m_subscriptionTerms.value, decimals)) +
            format("  Payment period: {}\n",    m_subscriptionTerms.period) +
            format("  Verifier key: {}\n",      m_subscriptionTerms.verifier_pubkey) + 
            format("  Infromation: {}\n",      m_subscriptionTerms.info) 
        );
    }  


    // 7 - Get Confirm

    function onPrintTerms() public {
        ConfirmInput.get(tvm.functionId(onTermsConfirmByUser), "Are you sure you want to accept the terms?");
    }


    // 8 - Print Contract Mediator Address

    function onTermsConfirmByUser(bool value) public {
        if (!value) {
            showMainMenu();
            return;
        }

        TvmCell stateInit = tvm.buildStateInit({
            contr: AbstractService,
            varInit: {
                terms_address: m_subscriptionTermsAddress
            },
            pubkey: m_userPubkey,
            code: m_mediatorContractCode
        });

        m_mediatorAddress = address(tvm.hash(stateInit));

        if (m_subscriptionTerms.root_token_wallet.value == 0) {
            Terminal.print(tvm.functionId(onMediatorAddressPrint), 
                format("Deploy the broker contract at {}. Confirm the transaction", m_mediatorAddress));
        } else {
            Terminal.print(tvm.functionId(deployTokenWalletForBroker), "Deploy a new token wallet");
        }
    }

    function deployTokenWalletForBroker() public {
        TvmCell body = tvm.encodeBody(IRootTokenContract.deployEmptyWallet, 
            50_000_000, 0, m_mediatorAddress, m_userWallet);
        
        MultitokenWallet(m_userWallet).walletSendValue{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: m_userPubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onDeployTokenWalletForBroker),
            onErrorId: tvm.functionId(onError)
        }(m_subscriptionTerms.root_token_wallet, 500_000_000, true, body);
    }

    function onDeployTokenWalletForBroker() public {
        optional(uint256) none;
        IRootTokenContract(m_subscriptionTerms.root_token_wallet).getWalletAddress{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onGetTonTokenWalletBroker),
            onErrorId: tvm.functionId(onError)
        }(0, m_mediatorAddress);
    }

    function onGetTonTokenWalletBroker(address ton_token_wallet) public {
        m_brokerTip3Address = ton_token_wallet;

        Terminal.print(0, format("Wallet contract at {}. Confirm the transaction", ton_token_wallet));
        Terminal.print(tvm.functionId(onMediatorAddressPrint), 
            format("Deploy the broker contract at {}. Confirm the transaction", m_mediatorAddress));
    }

    // 9 - Deploy Broker Contract

    function onMediatorAddressPrint() public view {
        address tokens_source = m_userWallet;
        if (m_subscriptionTerms.root_token_wallet.value != 0) {
            tokens_source = m_tonTokensMapping[m_subscriptionTerms.root_token_wallet].ton_token_wallet;
        }

        TvmCell body = tvm.encodeBody(SubscriptionTermsContract.deployMediatorContract, 
            m_userPubkey, UserWalletInformation(m_userWallet, tokens_source));
        
        MultitokenWallet(m_userWallet).walletSendValue{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: m_userPubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onMediatorDeploy),
            onErrorId: tvm.functionId(onError)
        }(m_subscriptionTermsAddress, 1_000_000_000, true, body);
    }


    // 10 - Grant permission

    function onMediatorDeploy() public {
        Terminal.print(tvm.functionId(requestPermissionBroker), "Give broker contract permission to spend under the terms of your subscription");
    }

    function requestPermissionBroker() public {
        address send_value_to;
        if (m_subscriptionTerms.root_token_wallet.value == 0) {
            send_value_to = m_mediatorAddress;
        } else {
            send_value_to = m_brokerTip3Address;
        }

        MultitokenWallet(m_userWallet).approve{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: m_userPubkey,
            time: uint64(now),
            expire: 0,
            callbackId: tvm.functionId(onSuccess),
            onErrorId: tvm.functionId(onError)
        }(m_mediatorAddress, SpendTerms(
            send_value_to,
            m_subscriptionTerms.root_token_wallet,
            m_subscriptionTerms.value,
            m_subscriptionTerms.gas_value,
            m_subscriptionTerms.period,
            uint64(now) - 60,
            m_subscriptionTerms.name
        ));
    }


    function onSuccess() public {
        Terminal.print(0, "Success");
        updateWalletInfo();
    }
 

    /* Utils */

    function getTokensValue(uint128 tokens, uint8 decimals) private returns (ufixed count)  {
        return (ufixed(tokens) / ufixed((uint256(10) ** decimals)));
    }
 
    function checkAddressActiveStatus(int8 accountType, string obj) private returns (bool)  {
        if (accountType == -1)  {
            Terminal.print(0, obj + " is inactive");
            return false;
        }
        if (accountType == 0) {
            Terminal.print(0, obj + " is uninitialized");
            return false;
        }
        if (accountType == 2) {
            Terminal.print(0, obj + " is frozen");
            return false;
        }
        return true;
    }

    function checkContractMediatorCodeHash(uint256 codeHash) private pure returns (bool) {
        return true; //codeHash == 0x6c0e1ad3a0d095ccd3893752217bb5b4a24c285b5352a24f55f029c732a11905;
    }

    function checkContractSubscriptionTermsCodeHash(uint256 codeHash) private pure returns (bool) {
        return true; //codeHash == 0xf05950778c226d6566154cf8420ad5832a980d8e241e13a5d8a0ae47dbb3061d;
    }

    function getSubscriptionTerms(uint32 answerId) private view {
        optional(uint256) none;
        tvm.hexdump(m_subscriptionTermsAddress.value);

        SubscriptionTermsContract(m_subscriptionTermsAddress).getTerms{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: tvm.functionId(onError)
        }();
    }

    function getSubscriptionMediator(uint32 answerId) private view {
        optional(uint256) none;
        tvm.hexdump(m_subscriptionTermsAddress.value);

        SubscriptionTermsContract(m_subscriptionTermsAddress).getMediatorContractCode{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: tvm.functionId(onError)
        }();
    }

    function getWalletActiveSpenders(uint32 answerId) private view {
        optional(uint256) none;
        tvm.hexdump(m_userWallet.value);

        MultitokenWallet(m_userWallet).getActiveSpenders{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: tvm.functionId(onError)
        }();
    }

    function getWalletServiceAviable(address service, uint32 answerId, uint32 errrorId) private view {
        optional(uint256) none;
        AbstractService(service).getAvailableUntil{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: errrorId
        }();
    }

    function getWalletTonTokenWallets(uint32 answerId, uint32 errrorId) private view {
        optional(uint256) none;
        tvm.hexdump(m_userWallet.value);

        MultitokenWallet(m_userWallet).getTonTokenWallets{
            abiVer: 2,
            extMsg: true,
            sign: false,
            pubkey: none,
            time: uint64(now),
            expire: 0,
            callbackId: answerId,
            onErrorId: errrorId
        }();
    }

    function onError(uint32 sdkError, uint32 exitCode) public {
        tvm.hexdump(sdkError);
        tvm.hexdump(exitCode);
        Terminal.print(0, "Fail. Restart DeBot");
        showMainMenu();
    }



    /* DeBot basic API */

    function start() public override {
        startDeBot();
    }
    
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string key, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "Subscriptions";
        version = "1.0.0";
        publisher = "Arsenicum12";
        key = "Universal debot for managing subscriptions";
        author = "Arsenicum12";
        support = address.makeAddrStd(0, 0);
        hello = "Hi, I will help you manage your subscriptions.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = m_icon;
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Terminal.ID, AddressInput.ID, ConfirmInput.ID, UserInfo.ID, Menu.ID, AmountInput.ID, QRCode.ID ];
    }


}