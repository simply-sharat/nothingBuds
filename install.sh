#!/usr/bin/env bash
# Build and install the nothingctl backend used by the Nothing Buds plugin.
set -euo pipefail

VERSION="v0.2.0"
BIN_DIR="${HOME}/.local/bin"

if ! command -v cargo >/dev/null 2>&1; then
    echo "cargo not found. Install Rust first: https://rustup.rs" >&2
    exit 1
fi

if command -v nothingctl >/dev/null 2>&1; then
    current="$(nothingctl --version 2>/dev/null | awk '{print $2}')"
    echo "nothingctl ${current} found at $(command -v nothingctl)"
    if [[ "${current}" == "0.2.0" || "${current}" > "0.2.0" ]]; then
        echo "Nothing to do."
        exit 0
    fi
fi

echo "Building nothingctl ${VERSION}..."
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
git clone --depth 1 --branch "${VERSION}" \
    https://github.com/FormalSnake/nothingctl "${tmp}/nothingctl"
cargo build --release --locked --manifest-path "${tmp}/nothingctl/Cargo.toml"

mkdir -p "${BIN_DIR}"
install -m 755 "${tmp}/nothingctl/target/release/nothingctl" "${BIN_DIR}/nothingctl"
echo "Installed ${BIN_DIR}/nothingctl"
echo
echo "Next: DMS Settings -> Plugins -> enable \"Nothing Buds\", then add it to the bar."
