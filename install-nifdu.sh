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

stage() { printf '\n[%s/8] %s\n' "$1" "$2"; }
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

find_chromium() {
  local candidate=""
  for candidate in \
    "${NIFDU_CHROMIUM:-}" \
    "$(command -v chromium 2>/dev/null || true)" \
    "$(command -v chromium-browser 2>/dev/null || true)" \
    "$(command -v google-chrome 2>/dev/null || true)" \
    "$TERMUX_SYS_PREFIX/bin/chromium" \
    "$TERMUX_SYS_PREFIX/bin/chromium-browser" \
    "$TERMUX_SYS_PREFIX/lib/chromium/chromium" \
    "$TERMUX_SYS_PREFIX/lib/chromium-browser/chromium-browser" \
    "/usr/bin/chromium" \
    "/usr/bin/chromium-browser" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium"
  do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if command -v dpkg >/dev/null 2>&1; then
    candidate="$(dpkg -L chromium 2>/dev/null | awk '/\/(chromium|chromium-browser)$/ {print; exit}')"
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  return 1
}

install_deps() {
  stage 1 "Checking and installing dependencies"
  if [ "$IS_TERMUX" -eq 1 ]; then
    pkg update -y
    pkg install -y git cmake ninja clang pkg-config libcurl nlohmann-json
    hash -r 2>/dev/null || true

    if ! find_chromium >/dev/null 2>&1; then
      printf '\nInstalling Chromium visual-validation engine...\n'
      pkg install -y x11-repo
      pkg update -y
      pkg install -y chromium
      hash -r 2>/dev/null || true
    fi

    CHROMIUM_BIN="$(find_chromium || true)"
    [ -n "$CHROMIUM_BIN" ] || {
      printf '\nChromium package files:\n' >&2
      dpkg -L chromium 2>/dev/null | grep -E '/(chromium|chrome)(-browser)?$' >&2 || true
      die "Chromium is installed but NIFDU could not locate an executable."
    }
    printf 'Chromium detected: %s\n' "$CHROMIUM_BIN"
  elif command -v apt-get >/dev/null 2>&1; then
    local SUDO=""
    [ "$(id -u)" -eq 0 ] || SUDO="sudo"
    command -v sudo >/dev/null 2>&1 || [ "$(id -u)" -eq 0 ] || die "Install sudo or run as root."
    $SUDO apt-get update
    $SUDO apt-get install -y git cmake ninja-build g++ pkg-config libcurl4-openssl-dev nlohmann-json3-dev ca-certificates chromium
  elif command -v dnf >/dev/null 2>&1; then
    local SUDO=""
    [ "$(id -u)" -eq 0 ] || SUDO="sudo"
    $SUDO dnf install -y git cmake ninja-build gcc-c++ libcurl-devel json-devel ca-certificates chromium
  elif command -v pacman >/dev/null 2>&1; then
    local SUDO=""
    [ "$(id -u)" -eq 0 ] || SUDO="sudo"
    $SUDO pacman -Syu --needed --noconfirm git cmake ninja gcc curl nlohmann-json ca-certificates chromium
  elif [ "$(uname -s)" = "Darwin" ]; then
    command -v brew >/dev/null 2>&1 || die "Homebrew is required on macOS."
    brew install git cmake ninja curl nlohmann-json
    brew install --cask chromium
  else
    die "Unsupported platform."
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
  stage 6 "Configuring Gemini API"
  [ -s "$API_KEY_FILE" ] && { printf 'Existing API key retained.\n'; return 0; }
  [ -n "${GEMINI_API_KEY:-}" ] && { save_api_key "$GEMINI_API_KEY"; printf 'API key imported from environment.\n'; return 0; }

  if [ -r /dev/tty ]; then
    printf 'Enter your Gemini API key (input hidden): ' > /dev/tty
    local key=""
    IFS= read -r -s key < /dev/tty || true
    printf '\n' > /dev/tty
    if [ -n "$key" ]; then
      save_api_key "$key"
      printf 'API key saved securely in %s\n' "$API_KEY_FILE"
    else
      printf 'No key entered. NIFDU will ask on first run.\n'
    fi
  fi
}

install_deps

stage 2 "Downloading the latest NIFDU source"
rm -rf "$SRC_DIR"
git clone --depth 1 --branch "$REF" "$REPO_URL" "$SRC_DIR"

stage 3 "Configuring the C++ build"
if [ "$IS_TERMUX" -eq 1 ]; then
  printf 'Termux prefix: %s\n' "$PREFIX"
  [ -f "$PREFIX/include/android/api-level.h" ] || die "Missing Android header: $PREFIX/include/android/api-level.h"
  cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF \
    -DCMAKE_CXX_COMPILER="$PREFIX/bin/clang++"
else
  cmake -S "$SRC_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
fi

stage 4 "Building NIFDU"
cmake --build "$BUILD_DIR" --target nifdu --parallel "$JOBS"

BIN="$BUILD_DIR/nifdu"
[ -x "$BIN" ] || die "Build completed but $BIN was not created."

stage 5 "Installing NIFDU command"
mkdir -p "$INSTALL_PREFIX/bin"
install -m 0755 "$BIN" "$INSTALL_PREFIX/bin/nifdu-bin"

cat > "$INSTALL_PREFIX/bin/nifdu" <<'LAUNCHER'
#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nifdu"
API_KEY_FILE="$CONFIG_DIR/gemini_api_key"
REAL_BIN="$(cd "$(dirname "$0")" && pwd)/nifdu-bin"
TERMUX_PREFIX="/data/data/com.termux/files/usr"

progress() { printf '\n[NIFDU] %s\n' "$*"; }

find_chromium() {
  local candidate=""
  for candidate in \
    "${NIFDU_CHROMIUM:-}" \
    "$(command -v chromium 2>/dev/null || true)" \
    "$(command -v chromium-browser 2>/dev/null || true)" \
    "$(command -v google-chrome 2>/dev/null || true)" \
    "$TERMUX_PREFIX/bin/chromium" \
    "$TERMUX_PREFIX/bin/chromium-browser" \
    "$TERMUX_PREFIX/lib/chromium/chromium" \
    "$TERMUX_PREFIX/lib/chromium-browser/chromium-browser" \
    "/usr/bin/chromium" \
    "/usr/bin/chromium-browser" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium"
  do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if command -v dpkg >/dev/null 2>&1; then
    candidate="$(dpkg -L chromium 2>/dev/null | awk '/\/(chromium|chromium-browser)$/ {print; exit}')"
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  return 1
}

[ -x "$REAL_BIN" ] || { printf 'NIFDU executable is missing: %s\n' "$REAL_BIN" >&2; exit 1; }

progress "Stage 1/5: Checking runtime dependencies"
hash -r 2>/dev/null || true

CHROMIUM_BIN="$(find_chromium || true)"
if [ -z "$CHROMIUM_BIN" ] && [ -d "$TERMUX_PREFIX" ]; then
  progress "Chromium is missing; installing it automatically"
  pkg install -y x11-repo
  pkg update -y
  pkg install -y chromium
  hash -r 2>/dev/null || true
  CHROMIUM_BIN="$(find_chromium || true)"
fi

[ -n "$CHROMIUM_BIN" ] || { printf 'Chromium could not be located after automatic installation.\n' >&2; exit 1; }
export NIFDU_CHROMIUM="$CHROMIUM_BIN"
printf 'Browser: %s\n' "$NIFDU_CHROMIUM"

progress "Stage 2/5: Loading API credentials"
if [ -z "${GEMINI_API_KEY:-}" ] && [ -s "$API_KEY_FILE" ]; then
  IFS= read -r GEMINI_API_KEY < "$API_KEY_FILE"
  export GEMINI_API_KEY
fi

if [ -z "${GEMINI_API_KEY:-}" ]; then
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  printf 'Enter your Gemini API key (input hidden): '
  key=""
  IFS= read -r -s key
  printf '\n'
  [ -n "$key" ] || { printf 'No API key entered.\n' >&2; exit 1; }
  printf '%s\n' "$key" > "$API_KEY_FILE"
  chmod 600 "$API_KEY_FILE"
  export GEMINI_API_KEY="$key"
fi

progress "Stage 3/5: Selecting Gemini 3.6 Flash"
export NIFDU_BUILDER_MODEL="${NIFDU_BUILDER_MODEL:-gemini-3.6-flash}"
export NIFDU_JUDGE_MODEL="${NIFDU_JUDGE_MODEL:-$NIFDU_BUILDER_MODEL}"
printf 'Builder model: %s\nJudge model  : %s\n' "$NIFDU_BUILDER_MODEL" "$NIFDU_JUDGE_MODEL"

progress "Stage 4/5: Preparing request"
if [ "$#" -eq 0 ]; then
  printf '\nNIFDU is ready. What should I build?\n> '
  request=""
  IFS= read -r request
  [ -n "$request" ] || { printf 'No request entered.\n' >&2; exit 1; }
  set -- "$request"
fi

progress "Stage 5/5: Starting autonomous build and validation loop"
exec "$REAL_BIN" "$@"
LAUNCHER
chmod 0755 "$INSTALL_PREFIX/bin/nifdu"

prompt_for_api_key

stage 7 "Verifying installation"
"$INSTALL_PREFIX/bin/nifdu-bin" --help >/dev/null 2>&1 || true
[ -x "$INSTALL_PREFIX/bin/nifdu" ] || die "Launcher installation failed."

stage 8 "Installation complete"
printf 'Launcher  : %s/bin/nifdu\n' "$INSTALL_PREFIX"
printf 'Executable: %s/bin/nifdu-bin\n' "$INSTALL_PREFIX"
printf 'Model     : gemini-3.6-flash\n'
printf 'Browser   : %s\n' "$(find_chromium || true)"
printf 'Run now   : nifdu\n'