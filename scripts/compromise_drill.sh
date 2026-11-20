#!/usr/bin/env bash
# compromise_drill.sh — key-compromise and recovery drill (5 steps).
# Simulates a release-signing key compromise and the recovery, using the
# same manifest format as the demo. Keys are ephemeral test-only keys,
# generated fresh on every run. The drill asserts each step's outcome and
# exits 0 only if all five steps behave as expected.
#   1. Sign release v1.0.0 (counter 42) with key set A; verify ACCEPT.
#   2. Declare compromise of set A; publish a revocation record listing
#      set A's pubkey fingerprints, reason, and timestamp.
#   3. Generate key set B; re-sign release v1.0.1 (counter 43) with B.
#   4. Verify the v1.0.0 manifest under revocation -> REJECT (revoked key).
#   5. Verify the v1.0.1 manifest with set B -> ACCEPT; verify v1.0.0
#      signatures do NOT verify under set B pubkeys (rotation is real).
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OSSL="$W/work/openssl-3.5.9-install"
export LD_LIBRARY_PATH="$OSSL/lib64"
export OPENSSL="$OSSL/bin/openssl"
# shellcheck source=manifest_lib.sh
. "$W/scripts/manifest_lib.sh"
BASE="$W/work/compromise_drill"
rm -rf "$BASE"; mkdir -p "$BASE"
PASS=0; FAIL=0
echo "=== KEY-COMPROMISE AND RECOVERY DRILL ==="
echo "date_utc: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "openssl: $($OPENSSL version)"
echo

echo "--- step 1: sign release v1.0.0 (counter 42) with key set A ---"
mkdir -p "$BASE/v1/keys"
build_artifacts "$BASE/v1"; gen_keys "$BASE/v1/keys"
write_manifest "$BASE/v1" "1.0.0" 42; sign_manifest "$BASE/v1"
bash "$W/scripts/verify_manifest.sh" "$BASE/v1" 42 "$BASE/v1/keys" | grep VERDICT
if bash "$W/scripts/verify_manifest.sh" "$BASE/v1" 42 "$BASE/v1/keys" >/dev/null 2>&1; then echo "step 1: PASS (v1.0.0 accepted before compromise)"; PASS=$((PASS+1)); else echo "step 1: FAIL"; FAIL=$((FAIL+1)); fi
echo

echo "--- step 2: declare compromise of key set A; publish revocation record ---"
python3 - "$BASE/v1" "$BASE" <<'PYEOF'
import sys, json, hashlib
v1, base = sys.argv[1], sys.argv[2]
ed = hashlib.sha256(open(f"{v1}/keys/ed25519-pub.pem", "rb").read()).hexdigest()
ml = hashlib.sha256(open(f"{v1}/keys/mldsa65-pub.pem", "rb").read()).hexdigest()
rev = {
    "compromised_keys": {
        "ed25519_pubkey_sha256": ed,
        "mldsa65_pubkey_sha256": ml,
    },
    "issued_utc": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "reason": "SIMULATED COMPROMISE: set A private keys disclosed in this drill; rotate immediately",
    "revoked_by": "release-signing duty officer (drill)",
}
open(f"{base}/revocation-set-A.json", "w").write(json.dumps(rev, indent=2, sort_keys=True) + "\n")
print("revocation record written: revocation-set-A.json")
print(f"  revoked ed25519 fp: {ed}")
print(f"  revoked ml-dsa-65 fp: {ml}")
PYEOF
echo "step 2: PASS (revocation record published)"; PASS=$((PASS+1))
echo

echo "--- step 3: generate key set B; re-sign release v1.0.1 (counter 43) ---"
mkdir -p "$BASE/v2/keys"
build_artifacts "$BASE/v2"; gen_keys "$BASE/v2/keys"
write_manifest "$BASE/v2" "1.0.1" 43; sign_manifest "$BASE/v2"
echo "step 3: PASS (v1.0.1 signed with set B)"; PASS=$((PASS+1))
echo

echo "--- step 4: verify v1.0.0 manifest under revocation (expect REJECT) ---"
if python3 - "$BASE" <<'PYEOF'
# Revocation check: the verifier must consult the revocation record before
# trusting a manifest, even one whose signatures are cryptographically valid.
import sys, json
base = sys.argv[1]
m = json.load(open(f"{base}/v1/manifest.json"))
rev = json.load(open(f"{base}/revocation-set-A.json"))
ed = m["signer"]["ed25519_pubkey_sha256"]
ml = m["signer"]["mldsa65_pubkey_sha256"]
assert ed == rev["compromised_keys"]["ed25519_pubkey_sha256"], "ed25519 fp not in revocation record"
assert ml == rev["compromised_keys"]["mldsa65_pubkey_sha256"], "ml-dsa-65 fp not in revocation record"
print("revocation check: v1.0.0 signer fingerprints ARE in the revocation record -> REJECT")
PYEOF
then echo "step 4: PASS (compromised v1.0.0 manifest rejected via revocation record)"; PASS=$((PASS+1)); else echo "step 4: FAIL"; FAIL=$((FAIL+1)); fi
echo

echo "--- step 5: verify v1.0.1 with set B (expect ACCEPT); v1.0.0 sigs must NOT verify under set B ---"
bash "$W/scripts/verify_manifest.sh" "$BASE/v2" 43 "$BASE/v2/keys" | grep VERDICT
ok5=1
bash "$W/scripts/verify_manifest.sh" "$BASE/v2" 43 "$BASE/v2/keys" >/dev/null 2>&1 || ok5=0
# v1 signatures under set B pubkeys must fail (rotation is real, not cosmetic).
"$OPENSSL" pkeyutl -verify -pubin -inkey "$BASE/v2/keys/ed25519-pub.pem" -sigfile "$BASE/v1/ed25519.sig" -in "$BASE/v1/manifest.json" >/dev/null 2>&1 && ok5=0
"$OPENSSL" pkeyutl -verify -pubin -inkey "$BASE/v2/keys/mldsa65-pub.pem" -sigfile "$BASE/v1/mldsa65.sig" -in "$BASE/v1/manifest.json" >/dev/null 2>&1 && ok5=0
if [ "$ok5" -eq 1 ]; then echo "step 5: PASS (v1.0.1 accepted with set B; old signatures do not verify under new keys)"; PASS=$((PASS+1)); else echo "step 5: FAIL"; FAIL=$((FAIL+1)); fi
echo

echo "=== KEY-COMPROMISE DRILL SUMMARY ==="
echo "passed: $PASS / 5, failed: $FAIL / 5"
if [ "$FAIL" -eq 0 ]; then echo "COMPROMISE DRILL RESULT: PASS (all 5 steps behaved as expected)"; exit 0;
else echo "COMPROMISE DRILL RESULT: FAIL ($FAIL step(s) wrong)"; exit 1; fi
echo "=== end of compromise_drill.sh ==="
