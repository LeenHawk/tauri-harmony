#!/usr/bin/env bash
# Toolchain checks only; no downstream application's CI belongs in this repository.
set -euo pipefail
rustc --version
node --version
pnpm --version
java -version
cargo tauri --version
cargo tauri ohos build --help >/dev/null
ohrs --version
"$HARMONY_TOOLS_DIR/command-line-tools/tool/node/bin/node" --version
libdirs="$DEVECO_SDK_HOME/default/hms/toolchains/lib:$OHOS_HOME/toolchains/lib:$OHOS_HOME/previewer/common/bin"
dependencies="$(LD_LIBRARY_PATH="$libdirs" ldd "$DEVECO_SDK_HOME/default/hms/toolchains/lib/libimage_transcoder_shared.so")"
printf '%s\n' "$dependencies"
if [[ "$dependencies" == *"not found"* ]]; then exit 1; fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
printf 'fn main() { println!("tauri-harmony"); }\n' > "$work/main.rs"
printf '#include <iostream>\nint main() { std::cout << "tauri-harmony"; }\n' > "$work/main.cpp"
for arch in aarch64 x86_64; do
  (
    export TARGET_TRIPLE="$arch-unknown-linux-ohos"
    source /opt/tauri-harmony/env.sh
    target_key="${TARGET_TRIPLE//-/_}"
    linker_key="CARGO_TARGET_${target_key^^}_LINKER"
    cxx_key="CXX_$target_key"
    rustc --target "$TARGET_TRIPLE" -C "linker=${!linker_key}" "$work/main.rs" -o "$work/rust-$arch"
    "${!cxx_key}" "$work/main.cpp" -o "$work/cpp-$arch"
    for binary in "$work/rust-$arch" "$work/cpp-$arch"; do
      readelf -h "$binary"
      if [[ "$arch" == aarch64 ]]; then
        readelf -h "$binary" | grep -q 'Machine:.*AArch64'
      else
        readelf -h "$binary" | grep -q 'Machine:.*Advanced Micro Devices X86-64'
      fi
    done
  )
done
# These are OHOS executables, not Linux-host runtime tests.
