#!/usr/bin/env bash
# manifest_lib.sh — shared helpers for the hybrid manifest demo and the
# downgrade simulation. Sourced by dual_sign_demo.sh and downgrade_sim.sh.
# All paths are relative to the pack root ($W). Keys are ephemeral test-only
# keys, generated fresh on every run.
# Requires: OPENSSL (pack OpenSSL 3.5.9 binary) and LD_LIBRARY_PATH set by
# the caller.
set -u

# build_artifacts <dir> — write three fixed-content artifacts; digests are
# deterministic across runs because the content is fixed.
build_artifacts() {
  local dir="$1"; mkdir -p "$dir"
  python3 - "$dir" <<'PYEOF'
import sys
d = sys.argv[1]
# Fixed content: deterministic digests, reproducible across runs.
open(f"{d}/postfiatd-1.0.0-linux-amd64", "wb").write(
    b"POSTFIATD-DEMO-BINARY-v1.0.0\n" + bytes(range(256)) * 4)
open(f"{d}/postfiatd-firmware-1.0.0.bin", "wb").write(
    b"POSTFIATD-DEMO-FIRMWARE-v1.0.0\n" + b"\xaa\x55" * 512)
open(f"{d}/RELEASE-NOTES-1.0.0.txt", "w").write(
    "postfiatd 1.0.0 demo release notes\n"
    "This is a fixed-content demo artifact for the hybrid manifest demo.\n"
    "It is NOT a real postfiatd binary.\n")
PYEOF
}

# gen_keys <keysdir> — fresh Ed25519 + ML-DSA-65 test keypairs.
gen_keys() {
  local kd="$1"; mkdir -p "$kd"
  "$OPENSSL" genpkey -algorithm ED25519 -out "$kd/ed25519-priv.pem" 2>/dev/null
  "$OPENSSL" genpkey -algorithm ML-DSA-65 -out "$kd/mldsa65-priv.pem" 2>/dev/null
  "$OPENSSL" pkey -in "$kd/ed25519-priv.pem" -pubout -out "$kd/ed25519-pub.pem" 2>/dev/null
  "$OPENSSL" pkey -in "$kd/mldsa65-priv.pem" -pubout -out "$kd/mldsa65-pub.pem" 2>/dev/null
}

# write_manifest <dir> <version> <counter> — manifest.json for the artifacts
# in <dir>; pubkey fingerprints read from <dir>/keys/*.pub.pem.
write_manifest() {
  local dir="$1" version="$2" counter="$3"
  python3 - "$dir" "$version" "$counter" <<'PYEOF'
import sys, json, hashlib
d, version, counter = sys.argv[1], sys.argv[2], int(sys.argv[3])
def sha256(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()
arts = []
for name in ["postfiatd-1.0.0-linux-amd64", "postfiatd-firmware-1.0.0.bin", "RELEASE-NOTES-1.0.0.txt"]:
    import os
    arts.append({"name": name, "sha256": sha256(f"{d}/{name}"),
                 "size": os.path.getsize(f"{d}/{name}")})
ed_fp = hashlib.sha256(open(f"{d}/keys/ed25519-pub.pem", "rb").read()).hexdigest()
ml_fp = hashlib.sha256(open(f"{d}/keys/mldsa65-pub.pem", "rb").read()).hexdigest()
manifest = {
    "artifacts": arts,
    "hybrid": {
        "ed25519_oid": "1.3.101.112",
        "mldsa65_oid": "2.16.840.1.101.3.4.3.18",
        "scheme": "dual independent signatures (Ed25519 + ML-DSA-65); both must verify",
    },
    "issued_utc": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "monotonic_counter": counter,
    "release": "postfiatd",
    "signer": {
        "ed25519_pubkey_sha256": ed_fp,
        "mldsa65_pubkey_sha256": ml_fp,
    },
    "version": version,
}
open(f"{d}/manifest.json", "w").write(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
print(f"manifest written: version={version} counter={counter}")
for a in arts:
    print(f"  {a['name']}: size={a['size']} sha256={a['sha256']}")
PYEOF
}

# sign_manifest <dir> — sign manifest.json with both keys; writes signatures.json.
sign_manifest() {
  local dir="$1"
  "$OPENSSL" pkeyutl -sign -inkey "$dir/keys/ed25519-priv.pem" -in "$dir/manifest.json" -out "$dir/ed25519.sig" 2>/dev/null
  "$OPENSSL" pkeyutl -sign -inkey "$dir/keys/mldsa65-priv.pem" -in "$dir/manifest.json" -out "$dir/mldsa65.sig" 2>/dev/null
  python3 - "$dir" <<'PYEOF'
import sys, json, hashlib, base64
d = sys.argv[1]
sigs = {
    "ed25519": base64.b64encode(open(f"{d}/ed25519.sig", "rb").read()).decode(),
    "manifest_sha256": hashlib.sha256(open(f"{d}/manifest.json", "rb").read()).hexdigest(),
    "ml-dsa-65": base64.b64encode(open(f"{d}/mldsa65.sig", "rb").read()).decode(),
}
open(f"{d}/signatures.json", "w").write(json.dumps(sigs, indent=2, sort_keys=True) + "\n")
print(f"signatures written: ed25519={len(open(f'{d}/ed25519.sig','rb').read())} B, "
      f"ml-dsa-65={len(open(f'{d}/mldsa65.sig','rb').read())} B, "
      f"hybrid total={len(open(f'{d}/ed25519.sig','rb').read()) + len(open(f'{d}/mldsa65.sig','rb').read())} B")
PYEOF
}
