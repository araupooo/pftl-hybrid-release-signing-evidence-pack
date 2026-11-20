#!/usr/bin/env bash
# dual_sign_demo.sh — hybrid manifest signing demo (positive path).
# Builds a fixed-content demo release bundle, writes a manifest with
# version, monotonic counter, artifact digests, hybrid metadata and
# signer fingerprints, signs it with Ed25519 AND ML-DSA-65 (dual
# independent signatures; both must verify), then verifies it.
# Keys are ephemeral test-only keys, generated fresh on every run.
# Output bundle is left in work/dual_sign/ and copied to
# outputs/dual_sign_demo/ (manifest.json, signatures.json, pubkeys).
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OSSL="$W/work/openssl-3.5.9-install"
export LD_LIBRARY_PATH="$OSSL/lib64"
export OPENSSL="$OSSL/bin/openssl"
# shellcheck source=manifest_lib.sh
. "$W/scripts/manifest_lib.sh"
D="$W/work/dual_sign"
rm -rf "$D"; mkdir -p "$D/keys" "$W/outputs/dual_sign_demo"
echo "=== HYBRID MANIFEST SIGNING DEMO ==="
echo "date_utc: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "openssl: $($OPENSSL version)"
echo "scheme: dual independent signatures — Ed25519 (classical) + ML-DSA-65 (FIPS 204); both must verify (fail-closed)"
echo
build_artifacts "$D"
gen_keys "$D/keys"
write_manifest "$D" "1.0.0" 42
sign_manifest "$D"
echo
echo "--- manifest.json ---"
cat "$D/manifest.json"
echo "--- signatures.json (base64 truncated to 64 chars) ---"
python3 - "$D" <<'PYEOF'
import sys, json
d = sys.argv[1]
s = json.load(open(f"{d}/signatures.json"))
print(f"manifest_sha256: {s['manifest_sha256']}")
print(f"ed25519:  {s['ed25519'][:64]}... (len {len(s['ed25519'])} b64 chars)")
print(f"ml-dsa-65: {s['ml-dsa-65'][:64]}... (len {len(s['ml-dsa-65'])} b64 chars)")
PYEOF
echo
echo "--- verification (installed counter 42, i.e. this is the current release) ---"
bash "$W/scripts/verify_manifest.sh" "$D" 42 "$D/keys"
rc=$?
echo "verify exit code: $rc"
echo
echo "--- size accounting ---"
python3 - "$D" <<'PYEOF'
import sys, os
d = sys.argv[1]
man = os.path.getsize(f"{d}/manifest.json")
ed = os.path.getsize(f"{d}/ed25519.sig")
ml = os.path.getsize(f"{d}/mldsa65.sig")
print(f"manifest.json bytes: {man}")
print(f"Ed25519 signature bytes: {ed}")
print(f"ML-DSA-65 signature bytes: {ml}")
print(f"hybrid signature total bytes: {ed + ml}")
print(f"manifest + hybrid signatures bytes: {man + ed + ml}")
PYEOF
cp "$D/manifest.json" "$D/signatures.json" "$D/keys/ed25519-pub.pem" "$D/keys/mldsa65-pub.pem" "$W/outputs/dual_sign_demo/"
[ "$rc" -eq 0 ] && echo "DEMO RESULT: PASS (valid hybrid manifest accepted)" || { echo "DEMO RESULT: FAIL (valid manifest rejected)"; exit 1; }
echo "=== end of dual_sign_demo.sh ==="
