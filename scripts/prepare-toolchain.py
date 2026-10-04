#!/usr/bin/env python3
"""Fetch and pin the experimental OHOS tools when building the toolchain image."""
import subprocess
import json
import os
from pathlib import Path
import re
import tomllib

root = Path.cwd()
source = Path(os.environ["OHOS_TAURI_SOURCES"]).resolve()
pins = json.loads((root / "tauri-pins.json").read_text())
marker = source / "tauri-harmony-pins.json"

for name, pin in pins.items():
    checkout = source / name
    subprocess.run(["git", "init", str(checkout)], check=True)
    subprocess.run(["git", "-C", str(checkout), "remote", "add", "origin",
                    f"https://github.com/{pin['repository']}.git"], check=True)
    subprocess.run(["git", "-C", str(checkout), "fetch", "--depth", "1", "origin", pin["revision"]], check=True)
    subprocess.run(["git", "-C", str(checkout), "checkout", "--detach", "FETCH_HEAD"], check=True)
# Keep Rust Ability and the packaged HAR on the same application-neutral source.
for checkout in (source / "tauri", source / "wry", source / "tao"):
    for manifest in checkout.rglob("Cargo.toml"):
        text = manifest.read_text()
        for package, directory in (("openharmony-ability", "ability"), ("openharmony-ability-derive", "derive")):
            def replace_source(match):
                return re.sub(r'git = "[^"]+"(?:, (?:rev|branch|tag) = "[^"]+")?',
                              lambda _: 'path = ' + json.dumps(str(source / 'ability/crates' / directory)),
                              match.group(0))
            text = re.sub(rf'^{package} = .*$', replace_source, text, flags=re.MULTILINE)
        manifest.write_text(text)
upstream = source / "tauri/Cargo.toml"
text = upstream.read_text()
for name in ("wry", "tao", "cargo-mobile2"):
    text = re.sub(rf'^{name} = .*$', lambda _: f'{name} = {{ path = {json.dumps(str(source / name))} }}', text, flags=re.MULTILINE)
upstream.write_text(text)
marker.write_text(json.dumps(pins, indent=2) + "\n")
cli = tomllib.loads((source / "tauri/crates/tauri-cli/Cargo.toml").read_text())["package"]
runtime = tomllib.loads((source / "tauri/crates/tauri/Cargo.toml").read_text())["package"]
(source / "cargo-tauri-source.json").write_text(json.dumps({
    "repository": pins["tauri"]["repository"],
    "revision": pins["tauri"]["revision"],
    "cli_version": cli["version"],
    "tauri_version": runtime["version"],
    "dependencies": pins,
}, indent=2) + "\n")
