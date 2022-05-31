# Picniq Token and Migration

This repository has the Picniq token contract with final migration data from the QFinance token. The merkle root used for the migration can be checked and reverse engineered using the data and scripts in the [migration repository](https://github.com/picniq/token-migration).

## SNACK Token

At current, the Picniq SNACK token will have 20M supply (20:1 split on current QFI token). This may change prior to launch.

### Vesting

Migrated users will have the ability to vest their tokens for a significant bonus. Currently this is 15% for a 6-month vest and 35% for a 12-month vest. 50% of tokens owed to the user will be sent immediately, the other 50% will vest linearly for the period. So if a user is owed 1000 SNACK tokens and choses a 12 month lock, their total will be 1350, 675 of which will be sent immediately. The other 675 SNACK will be unlocked over the next 12 months.

### ERC777

The SNACK token is ERC777 compatible enabling token transfers with data.

### ERC20 Permit

The SNACK token allows for signature-based approvals (EIP2612), thus not requiring separate transactions to approve non-ERC777 compatible smart contract spending.

## Staking

SNACK holders will have the ability to stake their tokens. The staking contract will be funded first from the treasury and then through the profits of the Picniq protocol (fees from yield farms, staking as a service, DAO investment pools, and future products).

### Autocompounding

The xSNACK token is an autocompounding token that continuously grows in value relative to SNACK. Holders of xSNACK earn autocompounding rewards in SNACK.

### Voting rights

xSNACK holders have protocol-level voting rights, such as fees on services and treasury funds.