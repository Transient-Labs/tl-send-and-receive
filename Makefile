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
test_quick: build
	forge test --fuzz-runs 256

test_std: build
	forge test

test_gas: build
	forge test --gas-report

test_cov: build
	forge coverage --no-match-coverage "(script|test|Foo|Bar)"

test_fuzz: build
	forge test --fuzz-runs 10000
