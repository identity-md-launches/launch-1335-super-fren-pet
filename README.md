# Super Fren Pet (SFP)

A fixed-supply ERC-20 for Ethereum. `src/SuperFrenPet.sol:SuperFrenPet` is the only production contract.

| Property | Value |
| --- | --- |
| Name | Super Fren Pet |
| Symbol | SFP |
| Decimals | 18 |
| Whole-token supply | 1,000,000,000 |
| Supply in smallest units | `1000000000000000000000000000` (10^27) |
| Constructor arguments | None (`[]`) |
| Initial recipient | Immediate deployer (`msg.sender`) |
| Launch chain | Ethereum, chain ID 1 |

The constructor mints the entire supply once and emits one `Transfer` from the zero address to the deployer. A factory deployment credits the factory, not the transaction sender. There is no subsequent initialization step or deployment setting to fill in.

## Behavior and assumptions

The request specifies a name, symbol, and fixed supply; ordinary ERC-20 behavior is assumed for transfers and approvals. The implementation inherits the vendored OpenZeppelin ERC-20 without changing its transfer or approval logic.

- Transfers deliver the exact amount and leave total supply unchanged. There are no fees, burns, rebases, transfer limits, or exemptions.
- Holders can transfer their balances; spenders can use `transferFrom` within the holder's allowance. The deployer has no special spending rights.
- Zero-value transfers between valid addresses succeed and emit `Transfer`. Self-transfers preserve balances and still require sufficient balance; delegated self-transfers consume finite allowance.
- Transfers involving the zero address, approvals to the zero address, insufficient balances, and insufficient allowances revert with ERC-6093 custom errors. Failed operations roll back balances and allowances.
- `approve` replaces the spender's existing allowance. `type(uint256).max` is an unlimited allowance and is not decremented by `transferFrom`. Approval spending does not emit an additional `Approval` event in this OpenZeppelin version; explicit approvals do.
- There is no owner, mint/burn endpoint, pause, blacklist, seizure, upgrade, proxy, or recovery function. The token makes no external calls, including recipient callbacks. It does not accept ordinary ETH transfers.

## Build and test

Install Foundry and make Solidity **0.8.26** available in its compiler cache. The verifier supplies this compiler. All Solidity dependencies are included as ordinary files in `lib/`; no network, package installation, environment variables, RPC, or fork is needed for these checks:

```sh
forge build
forge test
forge fmt --check
```

`foundry.toml` pins Solidity 0.8.26, targets Cancun, enables the optimizer with 200 runs, and sets `bytecode_hash = "none"`. FFI and filesystem cheatcode permissions are not enabled. Dependency versions, archive checksums, licenses, and source checksums are recorded in [DEPENDENCIES.md](DEPENDENCIES.md).

The unit and fuzz tests cover metadata, exact supply, one mint event, direct and CREATE2 factory deployment, exact transfers and events, zero/self/full-balance transfers, allowance replacement/revocation/exhaustion, unlimited approvals, unauthorized spending, rollback on failure, absent administrative endpoints, and runtime size/opcodes. Stateful invariants exercise repeated transfers, approvals, and delegated transfers across four holders while checking conservation and the fixed supply. Defaults are 1,024 cases per fuzz test and 256 invariant runs of up to 64 calls each.

The launch-flow unit test models the factory's 10% distributor, 75% pool, and 15% remainder transfers, a distributor claim, and token transfers in both directions with a pool account. It verifies exact token accounting; it does not deploy Uniswap or simulate its price/liquidity logic. The supplied protected suite depends on the launch system's contracts and environment and is run separately by that system.

## Deployment and operational responsibilities

Deploy the creation bytecode built for `SuperFrenPet` directly, with **no constructor arguments and zero ETH value**. Its artifact is `out/SuperFrenPet.sol/SuperFrenPet.json`. There are no linked libraries, external constructor calls, or network-specific contract dependencies. Use the pinned build settings for source verification and bytecode comparison. This project includes no broadcasting script or private key handling.

For the specified launch, the network's factory must execute the deployment so it receives all 10^27 units. The token performs no allocation itself. The factory and launch infrastructure are responsible for forwarding the swarm share, seeding the pool, and forwarding the remainder under the supplied launch policy. The separate manifest step supplies the policy and economics; this repository does not create `launch.json` or duplicate those mechanisms in token code.

Before release, the launch operator should confirm the artifact, constructor arguments, factory recipient, metadata, total supply, and matching deployed bytecode, run the full launch integration checks, and arrange independent adversarial review. Foundry tests are local verification, not an independent security audit; Slither and Mythril are not part of the recorded checks. No on-chain transactions have been submitted by this project.

### After launch

No owner settings, keepers, or maintenance transactions are required. The operator should verify the source on the explorer and confirm the factory's distributions. Wallet operators remain responsible for key custody, recipient addresses, and spending approvals. Prefer bounded approvals, revoke them when finished, and account for the standard ERC-20 allowance-change race: a spender may consume an existing approval before a replacement transaction lands. Interfaces can require revocation to be confirmed before granting a new amount.

Tokens sent to the token contract itself, or to a contract unable to transfer them out, cannot be rescued. Likewise, accidentally sent third-party tokens or forcibly received ETH have no recovery path. There is no administrator who can reverse transfers, freeze accounts, or repair the deployed code.
