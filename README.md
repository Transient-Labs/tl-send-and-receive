# Send and Receive
Smart contracts where you send ERC-1155 tokens and in return receive something else.

## System Explanation
The system is meant to be quite simple. It takes in ERC-1155 tokens, confirms the token + quantity of that token is available to be redeemed for something else.

![Redeem a ERC1155TL Mint](./public/SendAndReceiveERC1155TL.png)
![Raffle for ERC1155TL Mint](./public/SendAndReceiveERC1155TLRaffle.png)
![Redeem an ERC721 token](./public/SendAndReceiveERC721.png)
![Redeem ETH or ERC-20](./public/SendAndReceiveCurrency.png)


### Attack Vectors
![Attack Vectors](./public/AttackVectors.png)


## Getting Started
1. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
2. Install [uv](https://docs.astral.sh/uv/getting-started/installation/)
3. Ensure you have python 3.13.1 installed on your machine, either using pyenv, uv, or something else.
4. Run `forge soldeer install`
5. Run `uv sync`
6. You are now ready to go!

## Running Tests
- Run `forge test` for the regular test suite
- Run `forge coverage` for coverage tests
- Run `forge test --gas-report` for a gas report

## Deploying
1. Run `source .env`
2. Run `forge script script/Deploy.s.sol:Deploy --rpc-url mainnet --sender $SENDER --ledger --broadcast`
3. Manually verify contract on etherscan through vyper json

## Disclaimer
This codebase is provided on an "as is" and "as available" basis.

We do not give any warranties and will not be liable for any loss incurred through any use of this codebase.

## License
Copright (c) 2025 - Transient Labs, Inc.

Licensed under the GNU Affero General Public License v3.0 only (AGPL-3.0-only). See the `LICENSE` file for more details.