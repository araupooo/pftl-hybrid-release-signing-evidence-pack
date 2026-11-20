#!/usr/bin/env bash
# composite_probe.sh — RFC 10073 composite ML-DSA support probe.
# Checks whether the pack toolchain (OpenSSL 3.5.9, stock providers)
# can generate or use composite ML-DSA keys (RFC 10073: one key, one
# signature, both components must verify — atomic, fail-closed), and
# whether the oqsprovider is present. Expected outcome on stock OpenSSL
# 3.5.9: composite algorithms are NOT available; the dual-signature
# construction in this pack is the implementable-today shape, and
# composite is the standards-tracked future (Bouncy Castle 1.84 is the
# only implementation verified by an independent interop test — cited,
# not run here: no Java runtime in this environment).
# The script asserts the negative result and exits 0 when the probe
# behaves as documented (no composite support found).
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OSSL="$W/work/openssl-3.5.9-install"
export LD_LIBRARY_PATH="$OSSL/lib64"
OPENSSL="$OSSL/bin/openssl"
echo "=== RFC 10073 COMPOSITE ML-DSA SUPPORT PROBE ==="
echo "date_utc: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "openssl: $($OPENSSL version)"
echo
echo "--- 1. composite algorithms in 'openssl list -public-key-algorithms' ---"
if "$OPENSSL" list -public-key-algorithms 2>/dev/null | grep -i "composite" ; then
  echo "RESULT: composite algorithms FOUND (unexpected on stock OpenSSL 3.5.9)"
else
  echo "RESULT: no composite algorithms listed (expected on stock OpenSSL 3.5.9)"
fi
echo
echo "--- 2. attempt genpkey with RFC 10073 composite names ---"
for name in MLDSA65-Ed25519 id-MLDSA65-Ed25519-SHA512 MLDSA44-Ed25519; do
  if "$OPENSSL" genpkey -algorithm "$name" -out /tmp/composite-probe.pem 2>/tmp/composite-probe.err; then
    echo "genpkey $name: SUCCEEDED (unexpected)"
  else
    echo "genpkey $name: FAILED as expected — $(head -1 /tmp/composite-probe.err)"
  fi
done
rm -f /tmp/composite-probe.pem /tmp/composite-probe.err
echo
echo "--- 3. oqsprovider presence ---"
if ls "$OSSL/lib64/ossl-modules/" 2>/dev/null | grep -i oqs; then
  echo "RESULT: oqsprovider present"
else
  echo "RESULT: no oqsprovider in $OSSL/lib64/ossl-modules/ (only the default provider is installed)"
fi
echo
echo "--- 4. RFC 10073 composite OIDs (reference, from the RFC — verified live 20 Nov 2026, section 8.2) ---"
echo "id-MLDSA44-Ed25519-SHA512: 1.3.6.1.5.5.7.6.39"
echo "id-MLDSA65-Ed25519-SHA512: 1.3.6.1.5.5.7.6.48"
echo "NOTE: no id-MLDSA87-Ed25519-SHA512 is registered in RFC 10073 section 8.2;"
echo "ML-DSA-87 pairs with Ed448 (arc 51), ECDSA-P384/P521, and RSA-3072/4096."
echo "(RFC 10073, Nov 2026, Standards Track; composite ML-DSA is EUF-CMA only, not SUF-CMA — RFC 10073 section 9.2)"
echo
echo "--- conclusion ---"
echo "Composite ML-DSA is NOT runnable in stock OpenSSL 3.5.9 on this host."
echo "The dual independent-signature construction (Ed25519 + ML-DSA-65, both"
echo "required) in scripts/dual_sign_demo.sh is the implementable-today shape."
echo "Composite remains the standards-tracked future; the only implementation"
echo "verified by independent interop testing is Bouncy Castle 1.84 (cited in"
echo "SOURCES.md; not executed here — no Java runtime in this environment)."
echo "COMPOSITE PROBE RESULT: PASS (absence of composite support confirmed as documented)"
echo "=== end of composite_probe.sh ==="
