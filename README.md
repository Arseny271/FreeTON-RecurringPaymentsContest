### Recurring Payments contest submission

repository structure:
- **free ton** - smart contract code
- **keys** - folder with keys from contracts
- **scripts** - js scripts
- **terms** - folder with descriptions of subscription terms
- **tokens** - information about TIP-3 tokens

### Node version
it is recommended to use the latest version of npm and node js

### Initialization
```
npm i
```

### Scripts
#### Compilation
```
npm run build
```

#### TermsContract 
This contract contains information about the service and payment data.
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

#### Multitoken Wallet
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

#### RootTokenWallet
These teams are responsible for working with TPI tokens.
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
