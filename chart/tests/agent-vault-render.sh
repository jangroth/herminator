#!/bin/bash
# Render checks for the agentVault block. Needs helm, yq, git.
set -euo pipefail

cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

base=(--set image.tag=test --set stateExport.betterleaks.tag=test --set tailscale.tag=test)
render() { helm template "$1" "${base[@]}" "${@:2}" | yq -o=json -I=0 '.'; }
fail() { echo "FAIL: $*" >&2; exit 1; }

git -C .. archive "${BASE_REF:-origin/main}" . | tar -x -C "$tmp"
[ "$(render "$tmp")" = "$(render ..)" ] || fail "render without agentVault differs from ${BASE_REF:-origin/main}"

on=(--set agentVault.encryptedHttpsProxy=cipher1 --set-string agentVault.caCert=ca1)
render .. "${on[@]}" | yq -p=json -o=json 'select(.kind == "SealedSecret" and .metadata.name == "hermes-agent-vault")' >"$tmp/ss.json"
render .. "${on[@]}" | yq -p=json -o=json 'select(.kind == "Deployment")' >"$tmp/deploy.json"
with_env() { yq -p=json -o=yaml "[.spec.template.spec | (.containers[], .initContainers[]) | select(.env // [] | any_c(.name == \"$1\")) | .name] | join(\",\")" "$tmp/deploy.json"; }

[ "$(yq -p=json -o=yaml '.metadata.namespace' "$tmp/ss.json")" = hermes ] || fail "SealedSecret hermes-agent-vault missing or not in hermes"
for var in HTTPS_PROXY NO_PROXY CURL_CA_BUNDLE; do
  [ "$(with_env $var)" = hermes ] || fail "$var must be set on the hermes container only"
done

checksum() { render .. "$@" | yq -p=json -o=yaml 'select(.kind == "Deployment") | .spec.template.metadata.annotations["checksum/agent-vault"]'; }
c1=$(checksum "${on[@]}")
[ "$c1" != null ] || fail "checksum/agent-vault missing"
[ "$c1" != "$(checksum --set agentVault.encryptedHttpsProxy=cipher2 --set-string agentVault.caCert=ca1)" ] ||
  fail "checksum unchanged when the ciphertext changes"
[ "$c1" != "$(checksum --set agentVault.encryptedHttpsProxy=cipher1 --set-string agentVault.caCert=ca2)" ] ||
  fail "checksum unchanged when the CA changes"

! helm template .. "${base[@]}" --set agentVault.encryptedHttpsProxy=cipher1 >/dev/null 2>&1 ||
  fail "render must fail without agentVault.caCert"

echo PASS
