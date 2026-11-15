#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="${GAME:-/data/Gaming/Steam/steamapps/common/ProjectZomboid/projectzomboid}"
ZB="${ZB:-/data/Gaming/Steam/steamapps/workshop/content/108600/3619862853/mods/ZombieBuddy/libs/ZombieBuddy.jar}"
MOD="$HERE/Contents/mods/ViewDoctor"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
javac --release 17 -d "$OUT" -cp "$GAME/projectzomboid.jar:$ZB" "$MOD"/source/viewdoctor/*.java
mkdir -p "$MOD/42/media/java/client"
jar --create --file "$MOD/42/media/java/client/ViewDoctor.jar" -C "$OUT" viewdoctor
JAR="$MOD/42/media/java/client/ViewDoctor.jar"
STEAMID="${STEAMID:-76561198805477797}"
KEY="${KEY:-$HOME/.signing/ed25519-private.der}"
printf 'ZBS:%s:%s' "$STEAMID" "$(sha256sum "$JAR" | cut -d' ' -f1)" > "$OUT/payload"
SIG="$(openssl pkeyutl -sign -inkey "$KEY" -keyform DER -rawin -in "$OUT/payload" | od -An -tx1 | tr -d ' \n')"
printf 'ZBS\nSteamID64:%s\nSignature:%s\n' "$STEAMID" "$SIG" > "$JAR.zbs"
CP="$OUT:$GAME/projectzomboid.jar"
javac --release 17 -d "$OUT" -cp "$CP" "$HERE/tests/ReachTest.java"
java -cp "$CP" ReachTest
