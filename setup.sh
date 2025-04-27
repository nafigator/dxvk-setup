#!/usr/bin/env bash

# shellcheck source=https://raw.githubusercontent.com/nafigator/bash-helpers/1.1.4/src/bash-helpers.sh
if [[ -x /usr/local/lib/bash/includes/bash-helpers.sh ]]; then
  . /usr/local/lib/bash/includes/bash-helpers.sh
else
  source <(curl -s https://raw.githubusercontent.com/nafigator/bash-helpers/1.1.4/src/bash-helpers.sh)
fi

# Function for handling version flags
function print_version() {
	# shellcheck disable=SC2059
	printf "setup.sh $(bold)${VERSION}$(clr)\n"
	# shellcheck disable=SC2059
	printf "bash-helpers.sh $(bold)${BASH_HELPERS_VERSION}$(clr)\n\n"
}

function usage_help() {
	# shellcheck disable=SC2059
  printf "$(bold)Usage:$(clr)
  setup.sh [OPTIONS...]

$(bold)DESCRIPTION$(clr)
  Bash script for latest DXVK libs installation into wine prefixes.

  As dependencies it uses curl, grep, jq, cut and bash-helpers lib. See https://github.com/nafigator/bash-helpers.
  If bash-helpers not exists in bash includes than script sources it from github.

$(bold)OPTIONS$(clr)
  -v, --version              Show script version
  -h, --help                 Show this help message
  -d, --debug                Run script in debug mode

$(bold)ENVIRONMENT$(clr)
  WINEPREFIX                 Defines wine prefix to install DXVK libs. By default installs into current dir.
  WINE                       Defines path to wine binary. By default wine will be used from \$PATH.

$(bold)EXAMPLES$(clr)
  Installation into current dir:

    cd /home/user/.wine && setup.sh

  Installation into defined prefix with specific wine build:

    WINE=/home/user/.local/share/wine/bin/wine WINEPREFIX=/home/user/.wine setup.sh
"

	return 0
}

# shellcheck disable=SC2034
INTERACTIVE=1
# shellcheck disable=SC2034
VERSION=0.3.3

parse_options "${@}"
PARSE_RESULT=$?

export WINEDEBUG=-all

[[ ${PARSE_RESULT} = 1 ]] && exit 1
[[ ${PARSE_RESULT} = 2 ]] && usage_help && exit 2

check_dependencies grep jq cut || exit 1

# Check environment variable for wine prefix
function check_env() {
  if [[ -z "$WINEPREFIX" ]]; then
    WINEPREFIX="$(pwd)"
    export WINEPREFIX
  fi

  if [[ -z "$WINE" ]]; then
    WINE="$(which wine)"
    export WINE
  fi

  debug "Variable WINEPREFIX: $WINEPREFIX"
  debug "Variable WINE: $WINE"
}

# Check .reg file
function check_reg_file() {
  if [[ -z "$1" ]]; then
    error 'check_reg_file(): not found required parameters!'
    exit 1
  fi

  if [[ ! -s "$1" ]]; then
    error "Not found or empty file $1"
    exit 1
  fi

  if [[ ! -r "$1" ]]; then
    error "Unable to read file $1"
    exit 1
  fi
}

# Find prefix system bits info
function find_prefix_bits() {
  if [[ -z "$1" ]]; then
    error 'find_prefix_bits(): not found required parameters!'
    exit 1
  fi

  # Find out prefix bits
  if grep -q '#arch=win32' "$1"; then
    readonly SYSTEM_BITS=32
  elif grep -q '#arch=win64' "$1"; then
    readonly SYSTEM_BITS=64
  else
    error "Unable to detect system bits version"
    exit 1
  fi
}

# Receive info about latest release
function check_latest_release() {
  readonly release_api_url=https://api.github.com/repos/doitsujin/dxvk/releases/latest

  if RELEASE_LATEST_RESP="$(curl -sS -f --fail-early "$release_api_url" 2>&1)"; then
    debug "Variable RELEASE_LATEST_RESP: $RELEASE_LATEST_RESP"
  else
    error "Unable to receive latest release response: $RELEASE_LATEST_RESP"
    exit 1
  fi
}

# Download and prepare latest release
function prepare_release() {
  readonly jq_name_select='.assets[0].name'
  readonly jq_download_url='.assets[0].browser_download_url'
  readonly release_file_name="$(echo "$RELEASE_LATEST_RESP" | jq -r "$jq_name_select")"

  debug "Variable release_file_name: $release_file_name"
  debug "Variable jq_download_url: $jq_download_url"

  if [[ -z "$release_file_name" ]]; then
    error "Unable to parse latest release file name"
    exit 1
  fi

  readonly archive_path="/tmp/$release_file_name"

  debug "Variable archive_path: $archive_path"

  if [[ ! -r "$archive_path" ]]; then
    readonly download_url="$(echo "$RELEASE_LATEST_RESP" | jq -r "$jq_download_url")"

    debug "Variable download_url: $download_url"

    if ! download_resp="$(curl -s --fail-early --output-dir /tmp -LO "$download_url" 2>&1)"; then
      error "Download release failure: $download_resp"
      exit 1
    fi
  fi

  status "Release archive: $archive_path" OK

  if ! archive_root_dir="$(tar tf "$archive_path" 2>&1 | head -n1 | cut -d'/' -f1)"; then
    error "Unable to read archive: $archive_root_dir"
    exit 1
  fi

  debug "Variable archive_root_dir: $archive_root_dir"

  readonly RELEASE_PATH=/tmp/$archive_root_dir

  if [[ ! -d "$RELEASE_PATH" ]]; then
    if ! tar_res="$(tar zxf "$archive_path" -C /tmp 2>&1)"; then
      error "Tar failure: $tar_res"
      exit 1
    fi
  fi
}

# Registry overrides set up
function setup_overrides() {
  local url=https://raw.githubusercontent.com/nafigator/dxvk-setup/refs/heads/reg-file/overrides.reg
  local tmp_path=/tmp/dxvk-overrides.reg

  if [[ ! -r "$tmp_path" ]]; then
    if overrides_resp="$(curl -sS -f --fail-early -o "$tmp_path" "$url" 2>&1)"; then
      debug "Variable overrides_resp: $overrides_resp"
    else
      error "Overrides reg-file download error: $overrides_resp"
      exit 1
    fi
  fi

  if ! res=$("$WINE" regedit "$tmp_path" 2>&1); then
    error "DLL overrides: $res"
    exit 1
  fi
}

# Copy files into 32-bits prefix
function copy_pfx_32() {
  if ! res=$(cp "$RELEASE_PATH"/x32/*.dll "$SYS_PATH" 2>&1); then
    error "Copy failure: $res"
    exit 1
  fi
}

# Copy files into 64-bits prefix
function copy_pfx_64() {
  if ! res64=$(cp "$RELEASE_PATH"/x64/*.dll "$SYS_PATH" 2>&1); then
    error "Copy x64 files failure: $res64"
    exit 1
  fi

  if ! res32=$(cp "$RELEASE_PATH"/x32/*.dll "$WOW_PATH" 2>&1); then
    error "Copy x32 files failure: $res32"
    exit 1
  fi
}

function main() {
  check_env

  readonly reg_file="$WINEPREFIX/system.reg"
  readonly SYS_PATH="$WINEPREFIX/drive_c/windows/system32"
  readonly WOW_PATH="$WINEPREFIX/drive_c/windows/syswow64"

  debug "Variable reg_file: $reg_file"
  debug "Variable SYS_PATH: $SYS_PATH"
  debug "Variable WOW_PATH: $WOW_PATH"

  check_reg_file "$reg_file"
  find_prefix_bits "$reg_file"

  status "$SYSTEM_BITS-bits prefix" OK

  check_latest_release

  status "Checkout latest release" OK

  prepare_release

  status "Prepare release" OK

  # Copy files
  if [[ "$SYSTEM_BITS" -eq 32 ]]; then
    copy_pfx_32
  else
    copy_pfx_64
  fi

  status "Copy files" OK

  setup_overrides

  status "DLL overrides" OK

  return 0
}

main "$@"
