#!/usr/bin/env bash
# Check whether the checkout is ready for P0 real-device AlarmKit validation.
set -euo pipefail

cd "$(dirname "$0")/.."

failures=0
warnings=0

pass() {
  printf '[PASS] %s\n' "$1"
}

warn() {
  warnings=$((warnings + 1))
  printf '[WARN] %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf '[FAIL] %s\n' "$1"
}

xcconfig_value() {
  local key="$1"
  local value=""
  local file line current_key current_value

  for file in Config/SigningDefaults.xcconfig Config/LocalSigning.xcconfig; do
    [[ -f "$file" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%//*}"
      [[ "$line" == *"="* ]] || continue
      current_key="${line%%=*}"
      current_value="${line#*=}"
      current_key="$(printf '%s' "$current_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      current_value="$(printf '%s' "$current_value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      if [[ "$current_key" == "$key" ]]; then
        value="$current_value"
      fi
    done < "$file"
  done

  printf '%s' "$value"
}

is_placeholder() {
  local value="$1"
  [[ -z "$value" || "$value" == *'$('* || "$value" == com.example.* || "$value" == group.com.example.* || "$value" == *yourcompany* || "$value" == YOURTEAMID ]]
}

require_real_value() {
  local key="$1"
  local value="$2"
  if is_placeholder "$value"; then
    fail "$key is still a placeholder: ${value:-<empty>}"
  else
    pass "$key = $value"
  fi
}

printf 'P0 readiness check\n'
printf '==================\n'

xcode_version="$(xcodebuild -version | tr '\n' ' ')"
if [[ "$xcode_version" == Xcode\ 26* ]]; then
  pass "$xcode_version"
else
  fail "Xcode 26.x is required for this iOS 26 / AlarmKit validation."
fi

if [[ -f Config/LocalSigning.xcconfig ]]; then
  pass "Config/LocalSigning.xcconfig exists"
else
  fail "Config/LocalSigning.xcconfig is missing. Copy Config/LocalSigning.xcconfig.example and fill real Developer Portal values."
fi

if [[ -f ShiftAlarm.xcodeproj/project.pbxproj ]] &&
   grep -q 'SigningDefaults.xcconfig' ShiftAlarm.xcodeproj/project.pbxproj; then
  pass "ShiftAlarm.xcodeproj uses Config/SigningDefaults.xcconfig"
else
  fail "ShiftAlarm.xcodeproj is not regenerated with Config/SigningDefaults.xcconfig. Run: bash scripts/regen.sh"
fi

development_team="$(xcconfig_value DEVELOPMENT_TEAM)"
app_bundle_id="$(xcconfig_value SHIFTALARM_APP_BUNDLE_ID)"
widget_bundle_id="$(xcconfig_value SHIFTALARM_WIDGET_BUNDLE_ID)"
tests_bundle_id="$(xcconfig_value SHIFTALARM_TESTS_BUNDLE_ID)"
app_group_id="$(xcconfig_value SHIFTALARM_APP_GROUP_ID)"
refresh_task_id="$(xcconfig_value SHIFTALARM_BG_REFRESH_TASK_ID)"
url_type_name="$(xcconfig_value SHIFTALARM_URL_TYPE_NAME)"
bundle_uti="$(xcconfig_value SHIFTALARM_BUNDLE_UTI)"

require_real_value DEVELOPMENT_TEAM "$development_team"
require_real_value SHIFTALARM_APP_BUNDLE_ID "$app_bundle_id"
require_real_value SHIFTALARM_WIDGET_BUNDLE_ID "$widget_bundle_id"
require_real_value SHIFTALARM_TESTS_BUNDLE_ID "$tests_bundle_id"
require_real_value SHIFTALARM_APP_GROUP_ID "$app_group_id"
require_real_value SHIFTALARM_BG_REFRESH_TASK_ID "$refresh_task_id"
require_real_value SHIFTALARM_URL_TYPE_NAME "$url_type_name"
require_real_value SHIFTALARM_BUNDLE_UTI "$bundle_uti"

if [[ "$app_group_id" == group.* ]]; then
  pass "App Group identifier has group.* prefix"
else
  fail "SHIFTALARM_APP_GROUP_ID must start with group."
fi

app_entitlements="$(plutil -p App/ShiftAlarm.entitlements)"
if grep -q '"com.apple.developer.alarmkit"' <<< "$app_entitlements"; then
  pass "App entitlement declares com.apple.developer.alarmkit"
else
  fail "App/ShiftAlarm.entitlements is missing com.apple.developer.alarmkit"
fi

if grep -q '"com.apple.developer.healthkit"' <<< "$app_entitlements"; then
  pass "App entitlement declares HealthKit"
else
  warn "App/ShiftAlarm.entitlements does not declare HealthKit"
fi

if grep -q '$(SHIFTALARM_APP_GROUP_ID)' App/ShiftAlarm.entitlements &&
   grep -q '$(SHIFTALARM_APP_GROUP_ID)' Widget/ShiftAlarmWidget.entitlements; then
  pass "App and Widget entitlements share SHIFTALARM_APP_GROUP_ID"
else
  fail 'App and Widget entitlements must both use $(SHIFTALARM_APP_GROUP_ID)'
fi

if grep -q 'NSAlarmKitUsageDescription' App/Info.plist; then
  pass "App Info.plist declares NSAlarmKitUsageDescription"
else
  fail "App/Info.plist is missing NSAlarmKitUsageDescription"
fi

if grep -q 'ShiftAlarmAppGroupIdentifier' App/Info.plist &&
   grep -q 'ShiftAlarmAppGroupIdentifier' Widget/Info.plist; then
  pass "App and Widget Info.plist expose ShiftAlarmAppGroupIdentifier"
else
  fail "App and Widget Info.plist must expose ShiftAlarmAppGroupIdentifier"
fi

if grep -q 'ShiftAlarmBGRefreshTaskIdentifier' App/Info.plist; then
  pass "App Info.plist exposes ShiftAlarmBGRefreshTaskIdentifier"
else
  fail "App/Info.plist must expose ShiftAlarmBGRefreshTaskIdentifier"
fi

printf '\n'
if (( failures > 0 )); then
  printf 'P0 readiness failed with %d failure(s) and %d warning(s).\n' "$failures" "$warnings"
  printf 'Fill Config/LocalSigning.xcconfig with real Developer Portal values, run bash scripts/regen.sh, then retry.\n'
  exit 1
fi

printf 'P0 readiness passed with %d warning(s). You can proceed to real-device golden path validation.\n' "$warnings"
