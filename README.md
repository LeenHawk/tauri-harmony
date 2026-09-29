# tauri-harmony

[![Toolchain image](https://github.com/LeenHawk/tauri-harmony/actions/workflows/image.yml/badge.svg)](https://github.com/LeenHawk/tauri-harmony/actions/workflows/image.yml)

A shared **Linux AMD64** build image for experimental Tauri **OpenHarmony / HarmonyOS NEXT** applications.
This repository builds the toolchain only. Each application builds and tests in its own repository.

```sh
docker pull ghcr.io/leenhawk/tauri-harmony:latest
```

## What's included

| Component | Version / location |
| --- | --- |
| Rust | 1.98, with ARM64 and x86_64 OHOS targets |
| Host Node / pnpm | Node 24 / pnpm 11.22.0 |
| HarmonyOS command-line tools / SDK | 6.0.0.858, API 20, `/opt/harmony/command-line-tools` |
| Tauri CLI and source | Experimental `feat/open-harmony` revisions in [tauri-pins.json](tauri-pins.json) |
| ohrs | 1.5.0 |
| Experimental dependency source | `/opt/ohos-tauri/{tauri,wry,tao,cargo-mobile2,ability}` |
| Native build utilities | CMake, Ninja, Clang, libclang, OpenSSL headers, Java, Python, json5, zip |

This is not an official Tauri or Huawei image. Stable Tauri does not yet provide this
experimental integration. Applications must use compatible experimental dependencies
and adapt unsupported plugins themselves. The image contains no application secrets,
signing profiles, or device certificates.

## Daily publication

The image workflow runs at **19:23 UTC daily (03:23 China Standard Time the following day)**,
on toolchain changes to `main`, and on manual dispatch. GitHub scheduled jobs can be delayed.

1. Build a candidate using layer caches and refreshed base image tags.
2. Pull that exact digest into a separate job; check the tools and SDK runtime libraries,
   and compile/link small Rust and C++ programs for ARM64 and x86_64 OHOS.
3. Only after those checks pass, promote the digest to `latest` and `YYYY-MM-DD` (UTC).
4. Check that the registry manifest is available without login.

`build-<run-id>-<attempt>` identifies an individual candidate; check its workflow result
before using it. `latest` and date tags can move. For reproducible consumers, pin the
**digest** shown in the successful workflow summary. The source revision is recorded in
OCI image labels. A failed build or toolchain check does not replace `latest`.

Experimental source commits and SDK archive checksums are pinned. The daily job does
**not** silently follow upstream branches. Update [tauri-pins.json](tauri-pins.json) to
advance the experimental stack together, then let this workflow validate it.
The current Ability pin matches Tauri's lockfile. The source preparation also fixes
cargo-mobile2's SDK-directory lookup for the vendor command-line-tools layout.

## Use from another repository

```yaml
jobs:
  harmony:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/leenhawk/tauri-harmony:latest # Prefer @sha256:... in releases.
    defaults:
      run:
        shell: bash
    steps:
      - uses: actions/checkout@v7.0.1
      - run: git config --global --add safe.directory "$PWD"
      - run: pnpm install --frozen-lockfile
      # Apply your application's experimental Tauri dependency overlay here.
      # Build the frontend with host Node 24 before selecting the SDK's Node.
      - run: pnpm run build:frontend
      - run: |
          export TARGET_TRIPLE=aarch64-unknown-linux-ohos
          source /opt/tauri-harmony/env.sh
          export PATH="$HARMONY_TOOLS_DIR/command-line-tools/tool/node/bin:$PATH"
          cd src-tauri
          cargo tauri ohos build --ci --target aarch64 --ignore-version-mismatches
```

Adapt the frontend command, Tauri directory, and generated HAP configuration to your
application. Initialize its OHOS project with `cargo tauri ohos init` first if necessary.
The experimental Hvigor template may require an explicit `--release` in its native
build callback; application packaging owns that configuration.

Host Node 24 stays the default for frontend tools. Hvigor may require the SDK's bundled
Node; select it only for HAP commands, as shown above. Use `pnpm` at the version your
application requires. `env.sh` supports `aarch64-unknown-linux-ohos` and
`x86_64-unknown-linux-ohos`, setting target-specific C/C++ compilers, linker and CMake
variables without replacing the compiler for host build scripts.

These checks prove tool availability and cross-linking, not device execution, HAP
signing, or application compatibility. Sign and test your application on its target
HarmonyOS/OpenHarmony device separately.

## First publication setup

The repository is public. GitHub initially creates GHCR packages as private; after the
first push, the owner must open the [package settings](https://github.com/users/LeenHawk/packages/container/tauri-harmony/settings)
and set visibility to **Public**. Then rerun the failed anonymous-access check. Consumers
need no credentials once that check passes. `org.opencontainers.image.source` links the
package to this repository; Actions publishes using its own `GITHUB_TOKEN`.

## Sources and licensing

Repository-authored scripts are MIT licensed. Bundled third-party software retains its
own licenses and terms; the repository license does not relicense the SDK or its tools.
The SDK is fetched from the [6.0.0.858 archive mirror](https://github.com/ErBWs/ohos-sdk/releases/tag/6.0.0.858),
with both archive part checksums verified in [install-sdk.sh](scripts/install-sdk.sh).
Tauri and its dependencies are fetched from the repositories and commits listed in
[tauri-pins.json](tauri-pins.json).
