# Local validation

Checked on 2026-10-11 with Forge 1.8.5 (`51a52c59cffd940f76eddd0b4bb1791aa4b5ac7f`) and Solidity `0.8.26+commit.8a97fa7a`.

| Check | Result |
| --- | --- |
| `forge build` | Pass |
| `forge test` | Pass: 33 reported tests, zero failures or skips |
| `forge fmt --check` | Pass |
| `sha256sum --check lib/SHA256SUMS` | All 36 vendored files match |
| Clean copy: `forge build --offline` | Pass |
| Clean copy: `forge test --offline --threads 4` | Pass |
| Clean copy: `forge fmt --check` | Pass |

The clean copy contained only `src/`, `test/`, `lib/`, `foundry.toml`, and `remappings.txt`. It had no prior build cache or supplied `.imd` inputs. Each Forge subprocess ran with an empty environment. Compiler availability came from the worker's existing compiler installation.

The suite contains 32 unit/fuzz test functions, including six fuzz tests with 1,024 cases each, plus two invariant assertions. This Forge version groups both invariants into one reported test: 256 runs, 16,384 handler calls, and zero reverts. The handler exercises approvals, transfers, and delegated transfers, including repeated allowance spending and self-transfers.

Artifact inspection confirmed a nonpayable, parameterless constructor; creation bytecode of 2,642 bytes; runtime bytecode of 1,752 bytes; no linked-library placeholders; and `bytecodeHash: none`. The public function ABI consists of the nine ERC-20/metadata methods plus `INITIAL_SUPPLY`. Runtime inspection passes the supplied check's disassembly rule excluding `DELEGATECALL`, `CALLCODE`, and `SELFDESTRUCT`.

The local review checked the sole mint in the constructor, immediate-deployer allocation, lack of public supply-changing or administrative functions, zero-address validation, allowance authorization, atomic failure behavior, and the absence of external calls. No issues remain from those checks. Slither, Mythril, the launch system's protected integration suite, and an independent adversarial review were not run. The pool-account fixture checks transfer accounting only; it does not validate actual pool initialization or swaps. Deployment and the full launch review remain the launch operator's responsibilities.
