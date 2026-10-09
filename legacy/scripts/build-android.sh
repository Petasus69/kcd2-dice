#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ANDROID_HOME:?Set ANDROID_HOME to the Android SDK directory}"
BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-35.0.0}"
SDK_API="${ANDROID_SDK_API:-35}"
BT="$ANDROID_HOME/build-tools/$BUILD_TOOLS"
ANDROID_JAR="$ANDROID_HOME/platforms/android-$SDK_API/android.jar"
JAVA_BIN="${JAVA_HOME:+$JAVA_HOME/bin/}"
mkdir -p build/classes build/dex build/assets/web
rm -rf build/classes/* build/dex/* build/assets/web/*
cp -R web/. build/assets/web/
"${JAVA_BIN}javac" -source 8 -target 8 -encoding UTF-8 -classpath "$ANDROID_JAR" -d build/classes android/src/cz/petasus/dice/MainActivity.java
"$BT/aapt" package -f -M android/AndroidManifest.xml -S android/res -A build/assets -I "$ANDROID_JAR" -F build/unsigned.apk
"$BT/d8" --min-api 26 --lib "$ANDROID_JAR" --output build/dex $(find build/classes -name '*.class')
(cd build/dex && zip -q ../unsigned.apk classes.dex)
"$BT/zipalign" -f -p 4 build/unsigned.apk build/aligned.apk
KEYSTORE="${DICE_KEYSTORE:-build/development.jks}"
KEY_ALIAS="${DICE_KEY_ALIAS:-dice}"
if [ ! -f "$KEYSTORE" ]; then
 "${JAVA_BIN}keytool" -genkeypair -keystore "$KEYSTORE" -alias "$KEY_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 -storepass "${DICE_STORE_PASSWORD:-android}" -keypass "${DICE_KEY_PASSWORD:-android}" -dname 'CN=Kosti u trakta, O=Petasus, C=CZ'
fi
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-key-alias "$KEY_ALIAS" --ks-pass "pass:${DICE_STORE_PASSWORD:-android}" --key-pass "pass:${DICE_KEY_PASSWORD:-android}" --out build/Kosti-u-trakta.apk build/aligned.apk
"$BT/apksigner" verify --verbose build/Kosti-u-trakta.apk
printf 'APK: %s/build/Kosti-u-trakta.apk\n' "$PWD"
