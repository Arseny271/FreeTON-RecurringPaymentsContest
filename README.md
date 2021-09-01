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
