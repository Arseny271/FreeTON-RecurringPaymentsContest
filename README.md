### Recurring Payments contest submission

repository structure:
- **free ton** - smart contract code
- **keys** - folder with keys from contracts
- **scripts** - js scripts
- **terms** - folder with descriptions of subscription terms
- **tokens** - information about TIP-3 tokens

#### Node version
it is recommended to use the latest version of npm and node js

#### Initialization
```
npm i
```
#### Compilation
```
npm run build
```

### Timer-contracts (OffchainTimer.sol)
Timer contract is a smart contract that can periodically call other smart contracts. This contracts is responsible for calling another contract at a specific time. When the contract wants to be called at the right time, it sends a message to the address `:4242424242424242` with the time at which it should be called and also with the size of the reward for the caller. A special off-chain program should track external incoming messages and call timer contracts when required, receiving a reward for this. Thus, there is an additional opportunity to earn money in the TON network and a universal cheap way of periodically calling the contract.
```
npm run timer-handle <address_to_send_reward>
```
Utility-handler of incoming requests from timer contracts.  `<address_to_send_reward>` - address for work remuneration.

**RootTimerContract (RootOffchainTimer.sol) ** - Ancillary contract. Helps to on-chain deploy timer contracts.


### TermsContract (SubscriptionTermsV2.sol)
This contract stores the terms of the subscription, as well as the code of the intermediary contract. The user must trust the intermediary's code, but even if the intermediary's code turns out to be malicious, the wallet will not allow you to write off funds at a time for more than one period of using the subscription.
```
npm run terms deploy <terms_info_filename>
```
Deploys a new terms contract  `<terms_info_filename>` - filename without extension in `terms` folder

**Description of subscription terms**
- `address` debot_address - debot address, currently not used
- `uint256` verifier_pubkey - public key of the verifier, currently not used. It is assumed that the owner of this key can have access to any intermediary contract and resolve disputes between the user and the supplier.
- `address` send_value_to - service provider address for sending funds there
- ` address` root_token_wallet - root TIP-3 token wallet address. Can be 0 if TIP-3 is not used.
- `uint128` value - payment amount.
- `uint128` gas_value - The amount of gas attached to the payment when spending funds, as well as when calling a callback. Recommended value 350_000_000 nanotokens.
- `uint64` period - payment period in seconds
- `uint32` max_payment_delay - the time that the service can be provided without receiving payment
- `string` name - Service name.
- `string` info - More detailed description

### Multitoken Wallet (MultitokenWallet.sol)
This is the main user wallet that will be used to pay for subscriptions.
```
npm run wallet deploy 
```
Deploy a new wallet. Before running the command, you should edit the keys/MultitokenWallet.keypair.json file and set the same key pair as in your surf wallet, or delete this file to generate a new key pair.
Further actions with the wallet are recommended to be carried out in surf using debot at the address `0:3eee93d82002c1e2e44a208fdbc6430241cda93fc43e91b35891e1fd96e029ec`

```
npm run wallet new <root_token_address>
```
Deploy a new TON Token Wallet with the specified `<root_token_address>`

```
npm run wallet add <root_token_address>
```
Binds the TON Token Wallet to the MultitokenWallet, after a successful call of this command, you can fully use the TTW

### Intermediary contract (AccessController.sol)
This is a simple example of a subscription service. Mediator between the user and the service provider. When a user wants to subscribe to a service, he must independently or with the help of debot deploy this contract and provide him with access to the funds of his wallet using the approve() method.

**Algorithm.**
- When creating a contract, it checks for the presence of an associated TIP-3 wallet (if necessary), creates a timer contract and waits for access to the user's funds.
- Once the previous conditions are met. The contract creates a request for spending funds and starts a timer for future calls.
- If the request for spending is fulfilled, the time for using the service is extended. Part of the funds is spent on maintaining the timer, the rest of the funds are kept by the intermediary until the next timer is triggered (one subscription period).
- When the timer is triggered (the first time timer is triggered after one subscription period), the reserved funds are sent to the service provider and a new request is created to spend user funds.
- If the user unsubscribes, the contract will find out about this through acallback and part of the reserved funds will be returned to the user, the remainder will go to the supplier, the timer is stopped.

### RootTokenWallet
These commands are responsible for working with TPI tokens.
```
npm run rtw deploy <token_info_filename>
```
Deploys a new RootTokenWallet  `<token_info_filename>` - filename without extension in `token` folder
```
npm run rtw give <token_info_filename> <token_wallet_address> <amount>
```
sends `<amount>` tokens to address `<token_wallet_address>`
```
npm run rtw deploy-wallet <token_info_filename> <amount>
```
deploys new TTW with `<amount>` tokens.
