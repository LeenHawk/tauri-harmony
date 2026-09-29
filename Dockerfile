FROM node:24-trixie AS node
FROM rust:1.98-trixie
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
ENV PATH="/opt/ohos-tools/bin:/opt/harmony/command-line-tools/bin:${PATH}" \
    OHOS_TAURI_SOURCES=/opt/ohos-tauri \
    HARMONY_TOOLS_DIR=/opt/harmony \
    DEVECO_SDK_HOME=/opt/harmony/command-line-tools/sdk \
    OHOS_HOME=/opt/harmony/command-line-tools/sdk/default/openharmony
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && npm install -g pnpm@11.22.0 \
    && apt-get update \
    && apt-get install -y --no-install-recommends cmake ninja-build clang libclang-dev \
       pkg-config libssl-dev python3 python3-json5 jq zip unzip openssl default-jdk-headless \
       libgl1 \
    && rm -rf /var/lib/apt/lists/* \
    && rustup target add aarch64-unknown-linux-ohos x86_64-unknown-linux-ohos
WORKDIR /opt/tauri-harmony
COPY scripts/install-sdk.sh ./
RUN bash install-sdk.sh
COPY scripts/prepare-toolchain.py tauri-pins.json ./
RUN python3 prepare-toolchain.py \
    && CARGO_PROFILE_RELEASE_LTO=thin CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8 \
       cargo install tauri-cli --path /opt/ohos-tauri/tauri/crates/tauri-cli --root /opt/ohos-tools \
    && cargo install ohrs --version 1.5.0 --locked --root /opt/ohos-tools \
    && rm -rf /opt/ohos-tauri/tauri/target /usr/local/cargo/registry /usr/local/cargo/git
COPY scripts/env.sh scripts/ohos.cmake scripts/smoke.sh ./
WORKDIR /workspace
