#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/badrpk/nifdu.git"
REF="${NIFDU_REF:-master}"
INSTALL_PREFIX="${NIFDU_PREFIX:-$HOME/.local}"
SRC_DIR="${NIFDU_SRC_DIR:-$HOME/.cache/nifdu-src}"
BUILD_DIR="$SRC_DIR/build"
JOBS="${NIFDU_JOBS:-}"
IS_TERMUX=0
TERMUX_SYS_PREFIX="/data/data/com.termux/files/usr"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

if [ -n "${TERMUX_VERSION:-}" ] || [ -d "$TERMUX_SYS_PREFIX" ]; then
  IS_TERMUX=1
fi

if [ -z "$JOBS" ]; then
  if command -v nproc >/dev/null 2>&1; then JOBS="$(nproc)";
  elif command -v sysctl >/dev/null 2>&1; then JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 2)";
  else JOBS=2; fi
fi

install_deps() {
  if [ "$IS_TERMUX" -eq 1 ]; then
    log "Installing Termux build dependencies"
    pkg update -y
    pkg install -y git cmake ninja clang pkg-config libcurl nlohmann-json
  elif command -v apt-get >/dev/null 2>&1; then
    log "Installing Debian/Ubuntu build dependencies"
    local SUDO=""
    [ "$(id -u)" -eq 0 ] || SUDO="sudo"
    command -v sudo >/dev/null 2>&1 || [ "$(id -u)" -eq 0 ] || die "Install sudo or run as root."
    $SUDO apt-get update
    $SUDO apt-get install -y git cmake ninja-build g++ pkg-config libcurl4-openssl-dev nlohmann-json3-dev ca-certificates
  elif command -v dnf >/dev/null 2>&1; then
    log "Installing Fedora/RHEL build dependencies"
    local SUDO=""
    [ "$(id -u)" -eq 0 ] || SUDO="sudo"
    $SUDO dnf install -y git cmake ninja-build gcc-c++ libcurl-devel json-devel ca-certificates
  elif command -v pacman >/dev/null 2>&1; then
    log "Installing Arch Linux build dependencies"
    local SUDO=""
    [ "$(id -u)" -eq 0 ] || SUDO="sudo"
    $SUDO pacman -Syu --needed --noconfirm git cmake ninja gcc curl nlohmann-json ca-certificates
  elif [ "$(uname -s)" = "Darwin" ]; then
    command -v brew >/dev/null 2>&1 || die "Homebrew is required on macOS: https://brew.sh"
    log "Installing macOS build dependencies"
    brew install git cmake ninja curl nlohmann-json
  else
    die "Unsupported platform. Install git, CMake, Ninja, a C++20 compiler, libcurl and nlohmann-json, then rerun."
  fi
}

install_deps

log "Downloading NIFDU source"
rm -rf "$SRC_DIR"
git clone --depth 1 --branch "$REF" "$REPO_URL" "$SRC_DIR"

log "Configuring NIFDU"
if [ "$IS_TERMUX" -eq 1 ]; then
  # CMake's Android detection reads $PREFIX/include/android/api-level.h.
  # Force Termux's system prefix even if the caller has PREFIX=~/.local exported.
  env PREFIX="$TERMUX_SYS_PREFIX" \
      CMAKE_PREFIX_PATH="$TERMUX_SYS_PREFIX" \
      cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_COMPILER="$TERMUX_SYS_PREFIX/bin/clang" \
      -DCMAKE_CXX_COMPILER="$TERMUX_SYS_PREFIX/bin/clang++"
else
  cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release
fi

log "Building NIFDU"
cmake --build "$BUILD_DIR" --parallel "$JOBS"

BIN=""
for candidate in "$BUILD_DIR/nifdu" "$BUILD_DIR/bin/nifdu" "$SRC_DIR/bin/nifdu"; do
  if [ -x "$candidate" ]; then BIN="$candidate"; break; fi
done
[ -n "$BIN" ] || die "Build completed but the nifdu executable was not found."

log "Installing to $INSTALL_PREFIX/bin/nifdu"
mkdir -p "$INSTALL_PREFIX/bin"
install -m 0755 "$BIN" "$INSTALL_PREFIX/bin/nifdu"

case ":$PATH:" in
  *":$INSTALL_PREFIX/bin:"*) ;;
  *)
    printf '\nAdd this line to your shell profile, then restart the terminal:\n'
    printf '  export PATH="%s/bin:$PATH"\n' "$INSTALL_PREFIX"
    ;;
esac

log "Verifying installation"
"$INSTALL_PREFIX/bin/nifdu" --help >/dev/null 2>&1 || true

printf '\nNIFDU installed successfully.\n'
printf 'Executable: %s/bin/nifdu\n' "$INSTALL_PREFIX"
printf 'Run: %s/bin/nifdu --help\n' "$INSTALL_PREFIX"
