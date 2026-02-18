# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

########################################
# Dependencies
########################################
remove:
	rm -rf dependencies

install:
	forge soldeer install

update: remove install

########################################
# Format & Lint
########################################
fmt:
	forge fmt

analyze:
	uv run slither .

install_commit_hookds:
	uv run pre-commit install

########################################
# Build
########################################
clean:
	forge fmt && forge clean

build:
	forge build --sizes

clean_build: clean build

build_init_code:
	@echo see README!

########################################
# Test
########################################
test-quick: build
	forge test --fuzz-runs 256

test-std: build
	forge test

test-gas: build
	forge test --gas-report

test-cov: build
	forge coverage --no-match-coverage "(script|test|Foo|Bar)"

test-fuzz: build
	forge test --fuzz-runs 10000

########################################
# SendAndReceiveERC1155TL Deployments
########################################
deploy_SendAndReceiveERC1155TL_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "SendAndReceiveERC1155TL.sol:SendAndReceiveERC1155TL" true
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TL.sol:SendAndReceiveERC1155TL --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TL.sol:SendAndReceiveERC1155TL --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TL.sol:SendAndReceiveERC1155TL --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TL.sol:SendAndReceiveERC1155TL --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_SendAndReceiveERC1155TL_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "SendAndReceiveERC1155TL.sol:SendAndReceiveERC1155TL" false
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TL.sol:SendAndReceiveERC1155TL --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TL.sol:SendAndReceiveERC1155TL --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TL.sol:SendAndReceiveERC1155TL --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TL.sol:SendAndReceiveERC1155TL --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# SendAndReceiveERC721TL Deployments
########################################
deploy_SendAndReceiveERC721TL_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "SendAndReceiveERC721TL.sol:SendAndReceiveERC721TL" true
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721TL.sol:SendAndReceiveERC721TL --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721TL.sol:SendAndReceiveERC721TL --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721TL.sol:SendAndReceiveERC721TL --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721TL.sol:SendAndReceiveERC721TL --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_SendAndReceiveERC721TL_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "SendAndReceiveERC721TL.sol:SendAndReceiveERC721TL" false
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721TL.sol:SendAndReceiveERC721TL --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721TL.sol:SendAndReceiveERC721TL --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721TL.sol:SendAndReceiveERC721TL --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721TL.sol:SendAndReceiveERC721TL --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# SendAndReceiveERC1155TLRaffle Deployments
########################################
deploy_SendAndReceiveERC1155TLRaffle_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "SendAndReceiveERC1155TLRaffle.sol:SendAndReceiveERC1155TLRaffle" true
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TLRaffle.sol:SendAndReceiveERC1155TLRaffle --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TLRaffle.sol:SendAndReceiveERC1155TLRaffle --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TLRaffle.sol:SendAndReceiveERC1155TLRaffle --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TLRaffle.sol:SendAndReceiveERC1155TLRaffle --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_SendAndReceiveERC1155TLRaffle_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "SendAndReceiveERC1155TLRaffle.sol:SendAndReceiveERC1155TLRaffle" false
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TLRaffle.sol:SendAndReceiveERC1155TLRaffle --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TLRaffle.sol:SendAndReceiveERC1155TLRaffle --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TLRaffle.sol:SendAndReceiveERC1155TLRaffle --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC1155TLRaffle.sol:SendAndReceiveERC1155TLRaffle --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# SendAndReceiveERC721 Deployments
########################################
deploy_SendAndReceiveERC721_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "SendAndReceiveERC721.sol:SendAndReceiveERC721" true
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721.sol:SendAndReceiveERC721 --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721.sol:SendAndReceiveERC721 --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721.sol:SendAndReceiveERC721 --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721.sol:SendAndReceiveERC721 --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_SendAndReceiveERC721_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "SendAndReceiveERC721.sol:SendAndReceiveERC721" false
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721.sol:SendAndReceiveERC721 --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721.sol:SendAndReceiveERC721 --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721.sol:SendAndReceiveERC721 --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveERC721.sol:SendAndReceiveERC721 --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# SendAndReceiveCurrency Deployments
########################################
deploy_SendAndReceiveCurrency_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "SendAndReceiveCurrency.sol:SendAndReceiveCurrency" true
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveCurrency.sol:SendAndReceiveCurrency --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveCurrency.sol:SendAndReceiveCurrency --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveCurrency.sol:SendAndReceiveCurrency --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveCurrency.sol:SendAndReceiveCurrency --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_SendAndReceiveCurrency_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "SendAndReceiveCurrency.sol:SendAndReceiveCurrency" false
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveCurrency.sol:SendAndReceiveCurrency --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveCurrency.sol:SendAndReceiveCurrency --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveCurrency.sol:SendAndReceiveCurrency --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat ./.temp/out.txt) src/SendAndReceiveCurrency.sol:SendAndReceiveCurrency --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# Add to TLUniversalDeployer (testnet only)
########################################
add_to_universal_deployer:
	cast send --rpc-url sepolia --ledger 0x7c24805454F7972d36BEE9D139BD93423AA29f3f "addDeployableContract(string,(string,address))" 