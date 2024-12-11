# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
test   :; forge test -vvv --no-match-contract DeploymentsGasLimits
test-contract :; forge test --match-contract ${filter} -vvv
test-watch   :; forge test --watch -vvv --no-match-contract DeploymentsGasLimits

# Coverage
coverage-base :; forge coverage --report lcov --no-match-coverage "(scripts|tests|deployments|mocks)"
coverage-clean :; lcov --rc derive_function_end_line=0 --remove ./lcov.info -o ./lcov.info.p \
	'src/contracts/extensions/v3-config-engine/*' \
	'src/contracts/treasury/*' \
	'src/contracts/dependencies/openzeppelin/ReentrancyGuard.sol' \
	'src/contracts/helpers/UiIncentiveDataProviderV3.sol' \
	'src/contracts/helpers/UiPoolDataProviderV3.sol' \
	'src/contracts/helpers/WalletBalanceProvider.sol' \
	'src/contracts/dependencies/*' \
	'src/contracts/helpers/AaveProtocolDataProvider.sol' \
	'src/contracts/protocol/libraries/configuration/*' \
	'src/contracts/protocol/libraries/logic/GenericLogic.sol' \
	'src/contracts/protocol/libraries/logic/ReserveLogic.sol'
coverage-report :; genhtml ./lcov.info.p -o report --branch-coverage --rc derive_function_end_line=0 --parallel
coverage-badge :; coverage=$$(awk -F '[<>]' '/headerCovTableEntryHi/{print $3}' ./report/index.html | sed 's/[^0-9.]//g' | head -n 1); \
	wget -O ./report/coverage.svg "https://img.shields.io/badge/coverage-$${coverage}%25-brightgreen"
coverage :
	make coverage-base
	make coverage-clean
	make coverage-report
	make coverage-badge

# Utilities
download :; cast etherscan-source --chain ${chain} -d src/etherscan/${chain}_${address} ${address}
git-diff :
	@mkdir -p diffs
	@npx prettier ${before} ${after} --write
	@printf '%s\n%s\n%s\n' "\`\`\`diff" "$$(git diff --no-index --ignore-space-at-eol ${before} ${after})" "\`\`\`" > diffs/${out}.md

# Deploy
deploy-libs-one	:;
	forge script scripts/misc/LibraryPreCompileOne.sol --rpc-url ${chain}  --private-keys ${PRIVATE_KEY} --verify --slow --broadcast --legacy --etherscan-api-key ${ETHERSCAN_API_KEY_WORLD}
deploy-libs-two	:;
	forge script scripts/misc/LibraryPreCompileTwo.sol --rpc-url ${chain}  --private-keys ${PRIVATE_KEY} --verify --slow --broadcast --legacy --etherscan-api-key ${ETHERSCAN_API_KEY_WORLD}

deploy-libs :
	make deploy-libs-one chain=${chain}
	make deploy-libs-two chain=${chain}
# npx catapulta-verify -b broadcast/LibraryPreCompileOne.sol/${chainId}/run-latest.json
# npx catapulta-verify -b broadcast/LibraryPreCompileTwo.sol/${chainId}/run-latest.json


# Deploy
deploy-world-libs-one	:;
	forge script scripts/misc/LibraryPreCompileOne.sol --rpc-url $(if $(isMainnet),${RPC_WORLD},${RPC_WORLD_SEPOLIA})  --private-keys ${BETA_DEPLOYER_PRIVATE_KEY} --verify --slow --broadcast --legacy --etherscan-api-key ${ETHERSCAN_API_KEY_WORLD}
deploy-world-libs-two	:;
	forge script scripts/misc/LibraryPreCompileTwo.sol --rpc-url $(if $(isMainnet),${RPC_WORLD},${RPC_WORLD_SEPOLIA})  --private-keys ${BETA_DEPLOYER_PRIVATE_KEY} --verify --slow --broadcast --legacy --etherscan-api-key ${ETHERSCAN_API_KEY_WORLD}

deploy-world-libs :
	make deploy-libs-one isMainnet=${isMainnet}
	make deploy-libs-two isMainnet=${isMainnet}

deploy-world :
	forge script scripts/DeployWorldSepolia.sol:Deploy \
    --rpc-url $(if $(isMainnet),${RPC_WORLD},${RPC_WORLD_SEPOLIA}) \
    --private-keys ${BETA_DEPLOYER_PRIVATE_KEY} \
	--etherscan-api-key ${ETHERSCAN_API_KEY_WORLD} \
    --broadcast \
    --verify \
	--legacy \
    -vvvv

deploy-world-mainnet :
	forge script scripts/DeployWorld.sol:Deploy \
    --rpc-url ${RPC_WORLD} \
    --private-keys ${BETA_DEPLOYER_PRIVATE_KEY} \
	--etherscan-api-key ${ETHERSCAN_API_KEY_WORLD} \
    --broadcast \
    --verify \
	--legacy \
    -vvvv

verify-all-world:
	forge script scripts/DeployWorldSepolia.sol:Deploy \
    --rpc-url $(if $(isMainnet),${RPC_WORLD},${RPC_WORLD_SEPOLIA}) \
    --private-keys ${BETA_DEPLOYER_PRIVATE_KEY} \
	--etherscan-api-key ${ETHERSCAN_API_KEY_WORLD} \
	--resume \
    --verify \
	--legacy \
    -vvvv 

deploy-witnet-adapter :
	forge script scripts/DeployWitnetAdapter.sol:Deploy \
	--rpc-url $(if $(isMainnet),${RPC_WORLD},${RPC_WORLD_SEPOLIA}) \
	--private-keys ${BETA_DEPLOYER_PRIVATE_KEY} \
	--etherscan-api-key ${ETHERSCAN_API_KEY_WORLD} \
    --broadcast \
    --verify \
	--legacy \
    -vvvv