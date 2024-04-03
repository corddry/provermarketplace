# Prover Marketplace
On-chain marketplace for zk-snark proofs

Users can make a request for proof generation by submitting some ether, along with a circuit's program hash and an input, to the contract.

The request will be emitted as an event which can be indexed by a network of provers (See example typescript implementation here: https://github.com/corddry/provernode)

Prover nodes submit outputs and proofs to the contract and trigger callback functions if requested, allowing smart contract functions to trigger automatically upon proof submission.

```src/``` contains the ProverMarketplace contract as well asbmock contracts needed for testing and demonstration

```test``` contains a full test suite for the marketplace

A working deployment of this repository has been made on Sepolia testnet at the following addresses:

**ProverMarketplaceNode:** [0x05CC789E47E69a5896C8798c4C85238F4Ca5A732](https://sepolia.etherscan.io/address/0x05CC789E47E69a5896C8798c4C85238F4Ca5A732)

**ProverMarketplaceNode:** [0xe3b3b4c856dbff24800967be4330f5ad4661a11c](https://sepolia.etherscan.io/address/0xe3b3b4c856dbff24800967be4330f5ad4661a11c)


## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
