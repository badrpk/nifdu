#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/badrpk/nifdu.git"
REF="${NIFDU_REF:-master}"
SRC_DIR="${NIFDU_SRC_DIR:-$HOME/.cache/nifdu-src}"
BUILD_DIR="$SRC_DIR/build"
JOBS="${NIFDU_JOBS:-}"
IS_TERMUX=0
TERMUX_SYS_PREFIX="/data/data/com.termux/files/usr"
INSTALL_PREFIX="${NIFDU_PREFIX:-$HOME/.local}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nifdu"
API_KEY_FILE="$CONFIG_DIR/gemini_api_key"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

if [ -n "${TERMUX_VERSION:-}" ] || [ -d "$TERMUX_SYS_PREFIX" ]; then
  IS_TERMUX=1
  export PREFIX="$TERMUX_SYS_PREFIX"
  export CMAKE_PREFIX_PATH="$TERMUX_SYS_PREFIX"
  INSTALL_PREFIX="${NIFDU_PREFIX:-$TERMUX_SYS_PREFIX}"
fi

if [ -z "$JOBS" ]; then
  if command -v nproc >/dev/null 2>&1; then JOBS="$(nproc)";
  elif command -v sysctl >/dev/null 2>&1; then JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 2)";
  else JOBS=2; fi
fi

install_deps() {
  if [ "$IS_TERMUX" -eq 1 ]; then
    log "Installing Termux build and browser dependencies"
    pkg update -y
    pkg install -y git cmake ninja clang pkg-config libcurl nlohmann-json

    if ! command -v chromium >/dev/null 2>&1; then
      log "Enabling Termux X11 repository"
      pkg install -y x11-repo
      pkg update -y
      log "Installing Chromium for headless visual validation"
      pkg install -y chromium
    fi

    command -v chromium >/dev/null 2>&1 || die "Chromium installation failed. Run: pkg install x11-repo && pkg install chromium"
  elif command -v apt-get >/dev/null 2>&1; then
    log "Installing Debian/Ubuntu build dependencies"
    local SUDO=""
    [ "$(id -u)" -eq 0 ] || SUDO="sudo"
    command -v sudo >/dev/null 2>&1 || [ "$(id -u)" -eq 0 ] || die "Install sudo or run as root."
    $SUDO apt-get update
    $SUDO apt-get install -y git cmake ninja-build g++ pkg-config libcurl4-openssl-dev nlohmann-json3-dev ca-certificates chromium
  elif command -v dnf >/dev/null 2>&1; then
    log "Installing Fedora/RHEL build dependencies"
    local SUDO=""
    [ "$(id -u)" -eq 0 ] || SUDO="sudo"
    $SUDO dnf install -y git cmake ninja-build gcc-c++ libcurl-devel json-devel ca-certificates chromium
  elif command -v pacman >/dev/null 2>&1; then
    log "Installing Arch Linux build dependencies"
    local SUDO=""
    [ "$(id -u)" -eq 0 ] || SUDO="sudo"
    $SUDO pacman -Syu --needed --noconfirm git cmake ninja gcc curl nlohmann-json ca-certificates chromium
  elif [ "$(uname -s)" = "Darwin" ]; then
    command -v brew >/dev/null 2>&1 || die "Homebrew is required on macOS: https://brew.sh"
    log "Installing macOS build dependencies"
    brew install git cmake ninja curl nlohmann-json
  else
    die "Unsupported platform. Install git, CMake, Ninja, a C++20 compiler, libcurl, nlohmann-json and Chromium, then rerun."
  fi
}

save_api_key() {
  [ -n "$1" ] || return 0
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  printf '%s\n' "$1" > "$API_KEY_FILE"
  chmod 600 "$API_KEY_FILE"
}

prompt_for_api_key() {
  [ -s "$API_KEY_FILE" ] && return 0
  [ -n "${GEMINI_API_KEY:-}" ] && { save_api_key "$GEMINI_API_KEY"; return 0; }

  if [ -r /dev/tty ]; then
    log "Gemini API configuration"
    printf 'Enter your Gemini API key (input hidden): ' > /dev/tty
    local key=""
    IFS= read -r -s key < /dev/tty || true
    printf '\n' > /dev/tty
    if [ -n "$key" ]; then
      save_api_key "$key"
      printf 'API key saved securely in %s\n' "$API_KEY_FILE"
    else
      printf 'No key entered. NIFDU will ask again when you run nifdu.\n'
    fi
  fi
}

install_deps

log "Downloading NIFDU source"
rm -rf "$SRC_DIR"
git clone --depth 1 --branch "$REF" "$REPO_URL" "$SRC_DIR"

log "Configuring NIFDU"
if [ "$IS_TERMUX" -eq 1 ]; then
  printf 'Termux PREFIX: %s\n' "$PREFIX"
  [ -f "$PREFIX/include/android/api-level.h" ] || die "Missing Termux Android header: $PREFIX/include/android/api-level.h"
  cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF \
    -DCMAKE_CXX_COMPILER="$PREFIX/bin/clang++"
else
  cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
fi

log "Building NIFDU"
cmake --build "$BUILD_DIR" --target nifdu --parallel "$JOBS"

BIN="$BUILD_DIR/nifdu"
[ -x "$BIN" ] || die "Build completed but $BIN was not created."

log "Installing NIFDU"
mkdir -p "$INSTALL_PREFIX/bin"
install -m 0755 "$BIN" "$INSTALL_PREFIX/bin/nifdu-bin"

cat > "$INSTALL_PREFIX/bin/nifdu" <<'LAUNCHER'
#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nifdu"
API_KEY_FILE="$CONFIG_DIR/gemini_api_key"
REAL_BIN="$(cd "$(dirname "$0")" && pwd)/nifdu-bin"

if [ ! -x "$REAL_BIN" ]; then
  printf 'NIFDU executable is missing: %s\n' "$REAL_BIN" >&2
  exit 1
fi

if [ -z "${GEMINI_API_KEY:-}" ] && [ -s "$API_KEY_FILE" ]; then
  IFS= read -r GEMINI_API_KEY < "$API_KEY_FILE"
  export GEMINI_API_KEY
fi

if [ -z "${GEMINI_API_KEY:-}" ]; then
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  printf 'Gemini API key is required.\n'
  printf 'Enter your Gemini API key (input hidden): '
  key=""
  IFS= read -r -s key
  printf '\n'
  [ -n "$key" ] || { printf 'No API key entered.\n' >&2; exit 1; }
  printf '%s\n' "$key" > "$API_KEY_FILE"
  chmod 600 "$API_KEY_FILE"
  export GEMINI_API_KEY="$key"
fi

if command -v chromium >/dev/null 2>&1; then
  export NIFDU_CHROMIUM="${NIFDU_CHROMIUM:-chromium}"
elif command -v chromium-browser >/dev/null 2>&1; then
  export NIFDU_CHROMIUM="${NIFDU_CHROMIUM:-chromium-browser}"
else
  printf 'Chromium is required for visual validation.\n' >&2
  if [ -d /data/data/com.termux/files/usr ]; then
    printf 'Install it with: pkg install x11-repo && pkg install chromium\n' >&2
  else
    printf 'Install Chromium using your system package manager.\n' >&2
  fi
  exit 1
fi

if [ "$#" -eq 0 ]; then
  printf '\nNIFDU is ready. What should I build?\n> '
  request=""
  IFS= read -r request
  [ -n "$request" ] || { printf 'No request entered.\n' >&2; exit 1; }
  exec "$REAL_BIN" "$request"
fi

exec "$REAL_BIN" "$@"
LAUNCHER
chmod 0755 "$INSTALL_PREFIX/bin/nifdu"

prompt_for_api_key

log "Verifying installation"
"$INSTALL_PREFIX/bin/nifdu-bin" --help >/dev/null 2>&1 || true

printf '\nNIFDU installed successfully.\n'
printf 'Launcher  : %s/bin/nifdu\n' "$INSTALL_PREFIX"
printf 'Executable: %s/bin/nifdu-bin\n' "$INSTALL_PREFIX"
printf 'Browser   : %s\n' "$(command -v chromium || command -v chromium-browser)"
printf 'Run now   : nifdu\n'