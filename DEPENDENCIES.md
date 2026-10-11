# Vendored dependencies

Dependencies are regular files, not submodules. Only the files needed by the token and local Foundry tests are included; no package manager or dependency download is needed to build.

| Dependency | Pinned tag | Included files | License |
| --- | --- | --- | --- |
| [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v5.1.0) | `v5.1.0` | `ERC20.sol`, `IERC20.sol`, `IERC20Metadata.sol`, `Context.sol`, `draft-IERC6093.sol`, and `LICENSE` | MIT |
| [Forge Standard Library](https://github.com/foundry-rs/forge-std/tree/v1.9.7) | `v1.9.7` | Upstream `src/**/*.sol` plus both license files | MIT or Apache-2.0 |

The OpenZeppelin subset is sufficient for all production imports. Forge Standard Library is used only by tests. Vendored source files are unmodified. Their licenses are under the corresponding directories in `lib/`.

Downloaded release archives:

- `https://codeload.github.com/OpenZeppelin/openzeppelin-contracts/tar.gz/refs/tags/v5.1.0` — SHA-256 `8a3b08cfc756437ba3343901565b18182adb42ec1e621960240a19da5d738686`.
- `https://codeload.github.com/foundry-rs/forge-std/tar.gz/refs/tags/v1.9.7` — SHA-256 `45157353ab49eab01d294565866731e599b32401757229689ee459aa26b7ee94`.

Verify every vendored source and license from the repository root:

```sh
sha256sum --check lib/SHA256SUMS
```

The Solidity compiler and Foundry executables are toolchain prerequisites supplied by the execution environment, not vendored application dependencies. No compiler binary is included or referenced by path in `foundry.toml`.
