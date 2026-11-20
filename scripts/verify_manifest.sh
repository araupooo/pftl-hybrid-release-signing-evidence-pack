#!/usr/bin/env bash
# verify_manifest.sh — verify a hybrid-signed release manifest.
# Usage: verify_manifest.sh <manifest-dir> <installed-counter> <keys-dir>
# Checks, in order (fail-closed: first failure rejects):
#   1. manifest.json parses and has the required fields
#   2. monotonic_counter >= installed counter (rollback protection)
#   3. every artifact digest in the manifest matches the file on disk
#   4. signer pubkey fingerprints match the trusted keys
#   5. Ed25519 signature verifies over manifest.json
#   6. ML-DSA-65 signature verifies over manifest.json
# Prints one line per check plus "VERDICT: ACCEPT" or
# "VERDICT: REJECT (<reason>)". Exit 0 on ACCEPT, 1 on REJECT.
# Requires: OPENSSL (pack OpenSSL 3.5.9 binary) and LD_LIBRARY_PATH set by
# the caller.
set -u
DIR="$1"; INSTALLED="$2"; KEYS="$3"
echo "--- verify_manifest.sh: dir=$DIR installed_counter=$INSTALLED ---"
python3 - "$DIR" <<'PYEOF'
import sys, json
d = sys.argv[1]
m = json.load(open(f"{d}/manifest.json"))
for f in ["artifacts", "hybrid", "monotonic_counter", "release", "signer", "version"]:
    assert f in m, f"missing field {f}"
print(f"check 1 manifest parses: OK (release={m['release']} version={m['version']} counter={m['monotonic_counter']})")
PYEOF
[ $? -ne 0 ] && { echo "VERDICT: REJECT (manifest unparsable or missing fields)"; exit 1; }
COUNTER=$(python3 -c "import json; print(json.load(open('$DIR/manifest.json'))['monotonic_counter'])")
if [ "$COUNTER" -lt "$INSTALLED" ]; then
  echo "check 2 rollback: FAIL (manifest counter $COUNTER < installed $INSTALLED)"
  echo "VERDICT: REJECT (rollback: stale manifest)"
  exit 1
fi
echo "check 2 rollback: OK (manifest counter $COUNTER >= installed $INSTALLED)"
python3 - "$DIR" <<'PYEOF'
import sys, json, hashlib
d = sys.argv[1]
m = json.load(open(f"{d}/manifest.json"))
for a in m["artifacts"]:
    got = hashlib.sha256(open(f"{d}/{a['name']}", "rb").read()).hexdigest()
    assert got == a["sha256"], f"digest mismatch for {a['name']}"
    print(f"check 3 digest {a['name']}: OK ({a['sha256'][:16]}...)")
PYEOF
[ $? -ne 0 ] && { echo "VERDICT: REJECT (artifact digest mismatch)"; exit 1; }
python3 - "$DIR" "$KEYS" <<'PYEOF'
import sys, json, hashlib
d, k = sys.argv[1], sys.argv[2]
m = json.load(open(f"{d}/manifest.json"))
ed = hashlib.sha256(open(f"{k}/ed25519-pub.pem", "rb").read()).hexdigest()
ml = hashlib.sha256(open(f"{k}/mldsa65-pub.pem", "rb").read()).hexdigest()
assert m["signer"]["ed25519_pubkey_sha256"] == ed, "ed25519 fingerprint mismatch"
assert m["signer"]["mldsa65_pubkey_sha256"] == ml, "ml-dsa-65 fingerprint mismatch"
print("check 4 signer fingerprints: OK (both match trusted keys)")
PYEOF
[ $? -ne 0 ] && { echo "VERDICT: REJECT (signer fingerprint mismatch)"; exit 1; }
python3 - "$DIR" <<'PYEOF'
import sys, json, base64
d = sys.argv[1]
s = json.load(open(f"{d}/signatures.json"))
for f in ["ed25519", "ml-dsa-65", "manifest_sha256"]:
    assert f in s, f"missing signature field {f}"
open(f"{d}/ed25519.sig.check", "wb").write(base64.b64decode(s["ed25519"]))
open(f"{d}/mldsa65.sig.check", "wb").write(base64.b64decode(s["ml-dsa-65"]))
import hashlib
assert s["manifest_sha256"] == hashlib.sha256(open(f"{d}/manifest.json", "rb").read()).hexdigest(), "manifest_sha256 mismatch"
print("check 5a signatures file: OK (both signatures present, manifest hash matches)")
PYEOF
[ $? -ne 0 ] && { echo "VERDICT: REJECT (missing signature or manifest hash mismatch)"; exit 1; }
"$OPENSSL" pkeyutl -verify -pubin -inkey "$KEYS/ed25519-pub.pem" -sigfile "$DIR/ed25519.sig.check" -in "$DIR/manifest.json" >/dev/null 2>&1 \
  || { echo "check 5 Ed25519 signature: FAIL"; echo "VERDICT: REJECT (Ed25519 signature invalid)"; exit 1; }
echo "check 5 Ed25519 signature: OK"
"$OPENSSL" pkeyutl -verify -pubin -inkey "$KEYS/mldsa65-pub.pem" -sigfile "$DIR/mldsa65.sig.check" -in "$DIR/manifest.json" >/dev/null 2>&1 \
  || { echo "check 6 ML-DSA-65 signature: FAIL"; echo "VERDICT: REJECT (ML-DSA-65 signature invalid)"; exit 1; }
echo "check 6 ML-DSA-65 signature: OK"
echo "VERDICT: ACCEPT"
exit 0
