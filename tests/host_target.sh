#!/bin/sh
# Host-side target helpers (no iOS SDK required).
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "${root}/tools/host.sh"

fail() {
    echo "host_target: $*" >&2
    exit 1
}

expect_eq() {
    got=$1
    want=$2
    label=$3
    if [ "${got}" != "${want}" ]; then
        fail "${label}: got '${got}', want '${want}'"
    fi
}

host_os=$(fun_os)
host_triple=$(fun_triple)
case "${host_os}" in
    linux|macos|windows)
        expect_eq "${host_triple}" "$(fun_arch)-${host_os}" "default triple"
        ;;
    *)
        fail "unexpected host os '${host_os}'"
        ;;
esac

if fun_is_ios; then
    fail "default target must not be iOS"
fi

ios_triple=$(
    FUN_GRAPHICS_TARGET=ios
    export FUN_GRAPHICS_TARGET
    fun_triple
)
expect_eq "${ios_triple}" "aarch64-ios" "FUN_GRAPHICS_TARGET=ios triple"

if ! (
    FUN_GRAPHICS_TARGET=ios
    export FUN_GRAPHICS_TARGET
    fun_is_ios
); then
    fail "FUN_GRAPHICS_TARGET=ios should make fun_is_ios true"
fi

sim_triple=$(
    FUN_GRAPHICS_TARGET=ios-simulator
    export FUN_GRAPHICS_TARGET
    fun_triple
)
expect_eq "${sim_triple}" "$(fun_arch)-ios-simulator" "FUN_GRAPHICS_TARGET=ios-simulator triple"

ios_sdk=$(
    FUN_GRAPHICS_TARGET=ios
    export FUN_GRAPHICS_TARGET
    fun_ios_sdk_name
)
expect_eq "${ios_sdk}" "iphoneos" "iOS device SDK"

sim_sdk=$(
    FUN_GRAPHICS_TARGET=ios-simulator
    export FUN_GRAPHICS_TARGET
    fun_ios_sdk_name
)
expect_eq "${sim_sdk}" "iphonesimulator" "iOS simulator SDK"

ios_arch=$(
    FUN_GRAPHICS_TARGET=ios
    export FUN_GRAPHICS_TARGET
    fun_ios_arch
)
expect_eq "${ios_arch}" "arm64" "iOS device arch"

ios_fw=$(
    FUN_GRAPHICS_TARGET=ios
    export FUN_GRAPHICS_TARGET
    fun_ios_frameworks
)
echo "${ios_fw}" | grep -q UIKit || fail "iOS frameworks must include UIKit"
if echo "${ios_fw}" | grep -q Cocoa; then
    fail "iOS frameworks must not include Cocoa"
fi
if echo "${ios_fw}" | grep -q IOKit; then
    fail "iOS frameworks must not include IOKit"
fi
echo "${ios_fw}" | grep -q Metal || fail "iOS frameworks must include Metal"

mac_fw=$(fun_macos_frameworks)
echo "${mac_fw}" | grep -q Cocoa || fail "macOS frameworks must include Cocoa"
if echo "${mac_fw}" | grep -q UIKit; then
    fail "macOS frameworks must not include UIKit"
fi

echo "host_target: ok (${host_triple}; ios=${ios_triple})"
