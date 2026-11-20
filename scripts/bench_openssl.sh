#!/usr/bin/env bash
# bench_openssl.sh — OpenSSL 3.5.9 benchmark for release signing.
# Algorithms: ML-DSA-44/65/87, all 12 SLH-DSA sets (SHA2 + SHAKE),
# Ed25519, RSA-2048 (classical reference). Fixed 32-byte message.
# Method: explicit keygen/sign/verify loops timed with the nanosecond
# clock (date +%s%N), plus `openssl speed -elapsed -seconds 2` as a
# cross-check for the algorithms speed(1) supports.
# Raw per-iteration timings (microseconds, one per line) are saved to
# outputs/timings_<ALG>_<OP>.txt and echoed into this log.
# Iteration counts: fast algorithms N=200; SLH-DSA "s" (small-signature)
# signing is slow (~0.5 s/op for 128s), so N_SIGN=20 for s-variants and
# N_SIGN=50 for f-variants; verify/keygen stay fast, N_VERIFY=100 for
# SLH-DSA, N_KEYGEN=50. RSA-2048 keygen is slow, N_KEYGEN=10.
# No network calls. Keys are random per run (by design); the message,
# counts, and expected signature sizes are fixed.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OSSL="$W/work/openssl-3.5.9-install"  # provisioned by scripts/run_all.sh (pinned OpenSSL 3.5.9 build)
export LD_LIBRARY_PATH="$OSSL/lib64"
OPENSSL="$OSSL/bin/openssl"
MSG_HEX="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
TMP="$W/work/bench_openssl"
mkdir -p "$TMP" "$W/outputs"
python3 -c "open('$TMP/msg.bin','wb').write(bytes.fromhex('$MSG_HEX'))"
echo "=== OPENSSL BENCHMARK ==="
echo "date_utc: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "openssl: $($OPENSSL version)"
echo "fixed message (32 bytes, hex): $MSG_HEX"
echo "message sha256: $(sha256sum "$TMP/msg.bin" | awk '{print $1}')"
echo "timing method: date +%s%N around each openssl invocation; microseconds"
echo "note: each invocation includes ~7-12 ms process-spawn overhead; compare minima and orders of magnitude, not exact us"
echo

stats() { # stats <timings-file>
python3 - "$1" <<'PYEOF'
import sys, statistics
vals=[int(l.strip()) for l in open(sys.argv[1]) if l.strip()]
vals.sort()
n=len(vals)
def pct(p):
    import math
    k=(n-1)*p/100.0; f=int(k); c=min(f+1,n-1)
    return vals[f] if f==c else vals[f]+(vals[c]-vals[f])*(k-f)
print(f"  n={n} mean={statistics.mean(vals):.1f} us median={statistics.median(vals):.1f} us p95={pct(95):.1f} us min={vals[0]} us max={vals[-1]} us")
PYEOF
}

run_alg() { # run_alg <label> <n_keygen> <n_sign> <n_verify> <genpkey-args...>
  local label="$1"; local n_keygen="$2"; local n_sign="$3"; local n_verify="$4"; shift 4
  local genargs=("$@")
  local dir="$TMP/$label"; mkdir -p "$dir"
  echo "--- $label (N keygen=$n_keygen sign=$n_sign verify=$n_verify) ---"
  "$OPENSSL" genpkey "${genargs[@]}" -out "$dir/priv.pem" 2>"$dir/genpkey.err" || { echo "GENPKEY FAILED"; cat "$dir/genpkey.err"; return 1; }
  "$OPENSSL" pkey -in "$dir/priv.pem" -pubout -out "$dir/pub.pem" 2>/dev/null
  local priv_der pub_der
  priv_der=$("$OPENSSL" pkey -in "$dir/priv.pem" -outform DER 2>/dev/null | wc -c)
  pub_der=$("$OPENSSL" pkey -in "$dir/priv.pem" -pubout -outform DER 2>/dev/null | wc -c)
  echo "privkey PEM bytes: $(stat -c%s "$dir/priv.pem")  DER bytes: $priv_der"
  echo "pubkey  PEM bytes: $(stat -c%s "$dir/pub.pem")  DER bytes: $pub_der"
  # one sign + verify to produce a valid signature and confirm the path works
  if [ "$label" = "RSA-2048" ]; then
    "$OPENSSL" dgst -sha256 -sign "$dir/priv.pem" -out "$dir/sig.bin" "$TMP/msg.bin" 2>"$dir/sign.err" || { echo "SIGN FAILED"; cat "$dir/sign.err"; return 1; }
    "$OPENSSL" dgst -sha256 -verify "$dir/pub.pem" -signature "$dir/sig.bin" "$TMP/msg.bin" 2>"$dir/verify.err" || { echo "VERIFY FAILED"; cat "$dir/verify.err"; return 1; }
  else
    "$OPENSSL" pkeyutl -sign -inkey "$dir/priv.pem" -in "$TMP/msg.bin" -out "$dir/sig.bin" 2>"$dir/sign.err" || { echo "SIGN FAILED"; cat "$dir/sign.err"; return 1; }
    "$OPENSSL" pkeyutl -verify -pubin -inkey "$dir/pub.pem" -sigfile "$dir/sig.bin" -in "$TMP/msg.bin" 2>"$dir/verify.err" || { echo "VERIFY FAILED"; cat "$dir/verify.err"; return 1; }
  fi
  echo "signature bytes: $(stat -c%s "$dir/sig.bin")"
  echo "signature sha256: $(sha256sum "$dir/sig.bin" | awk '{print $1}')"
  echo "single sign+verify round-trip: OK"
  # timing loops
  for op in keygen sign verify; do
    local N
    case "$op" in keygen) N="$n_keygen";; sign) N="$n_sign";; verify) N="$n_verify";; esac
    local tf="$W/outputs/timings_${label}_${op}.txt"
    : > "$tf"
    local fails=0
    local i t0 t1
    for i in $(seq 1 "$N"); do
      t0=$(date +%s%N)
      case "$op" in
        keygen) "$OPENSSL" genpkey "${genargs[@]}" -out "$dir/tmpkey.pem" 2>/dev/null || fails=$((fails+1));;
        sign)
          if [ "$label" = "RSA-2048" ]; then "$OPENSSL" dgst -sha256 -sign "$dir/priv.pem" -out "$dir/tmpsig.bin" "$TMP/msg.bin" 2>/dev/null || fails=$((fails+1));
          else "$OPENSSL" pkeyutl -sign -inkey "$dir/priv.pem" -in "$TMP/msg.bin" -out "$dir/tmpsig.bin" 2>/dev/null || fails=$((fails+1)); fi;;
        verify)
          if [ "$label" = "RSA-2048" ]; then "$OPENSSL" dgst -sha256 -verify "$dir/pub.pem" -signature "$dir/sig.bin" "$TMP/msg.bin" >/dev/null 2>&1 || fails=$((fails+1));
          else "$OPENSSL" pkeyutl -verify -pubin -inkey "$dir/pub.pem" -sigfile "$dir/sig.bin" -in "$TMP/msg.bin" >/dev/null 2>&1 || fails=$((fails+1)); fi;;
      esac
      t1=$(date +%s%N)
      echo $(( (t1 - t0) / 1000 )) >> "$tf"
    done
    echo "  $op: failures=$fails / $N"
    echo "$fails" > "$W/outputs/failures_${label}_${op}.txt"
    stats "$tf"
    echo "  raw timings (us, $N values, in order): $(paste -sd, "$tf")"
  done
  echo
}

# Fast algorithms: N keygen/sign/verify = 50/200/200 (RSA keygen slow: 10)
run_alg "ML-DSA-44" 50 200 200 -algorithm ML-DSA-44
run_alg "ML-DSA-65" 50 200 200 -algorithm ML-DSA-65
run_alg "ML-DSA-87" 50 200 200 -algorithm ML-DSA-87
run_alg "Ed25519" 50 200 200 -algorithm ED25519
run_alg "RSA-2048" 10 200 200 -algorithm RSA -pkeyopt rsa_keygen_bits:2048
# SLH-DSA SHA2 family: s-variants sign N=20, f-variants sign N=50
run_alg "SLH-DSA-SHA2-128s" 50 20 100 -algorithm SLH-DSA-SHA2-128s
run_alg "SLH-DSA-SHA2-128f" 50 50 100 -algorithm SLH-DSA-SHA2-128f
run_alg "SLH-DSA-SHA2-192s" 50 20 100 -algorithm SLH-DSA-SHA2-192s
run_alg "SLH-DSA-SHA2-192f" 50 50 100 -algorithm SLH-DSA-SHA2-192f
run_alg "SLH-DSA-SHA2-256s" 50 20 100 -algorithm SLH-DSA-SHA2-256s
run_alg "SLH-DSA-SHA2-256f" 50 50 100 -algorithm SLH-DSA-SHA2-256f
# SLH-DSA SHAKE family
run_alg "SLH-DSA-SHAKE-128s" 50 20 100 -algorithm SLH-DSA-SHAKE-128s
run_alg "SLH-DSA-SHAKE-128f" 50 50 100 -algorithm SLH-DSA-SHAKE-128f
run_alg "SLH-DSA-SHAKE-192s" 50 20 100 -algorithm SLH-DSA-SHAKE-192s
run_alg "SLH-DSA-SHAKE-192f" 50 50 100 -algorithm SLH-DSA-SHAKE-192f
run_alg "SLH-DSA-SHAKE-256s" 50 20 100 -algorithm SLH-DSA-SHAKE-256s
run_alg "SLH-DSA-SHAKE-256f" 50 50 100 -algorithm SLH-DSA-SHAKE-256f

echo "=== openssl speed cross-check (2s each, elapsed time) ==="
for a in ML-DSA-44 ML-DSA-65 ML-DSA-87 ed25519 rsa2048; do
  echo "--- speed $a ---"
  timeout 60 "$OPENSSL" speed -elapsed -seconds 2 "$a" 2>&1 | grep -v "^$" | tail -n 6
done
for a in SLH-DSA-SHA2-128s SLH-DSA-SHA2-128f; do
  echo "--- speed $a (may be unsupported by speed(1)) ---"
  timeout 120 "$OPENSSL" speed -elapsed -seconds 2 "$a" 2>&1 | grep -v "^$" | tail -n 6 || echo "  speed does not support $a"
done
echo "=== SUMMARY TABLE (explicit-loop timings, microseconds) ==="
printf "%-22s %-8s %12s %12s %12s %10s %10s\\n" "Algorithm" "Op" "mean_us" "median_us" "p95_us" "failures" "sig_bytes"
for label in ML-DSA-44 ML-DSA-65 ML-DSA-87 Ed25519 RSA-2048 SLH-DSA-SHA2-128s SLH-DSA-SHA2-128f SLH-DSA-SHA2-192s SLH-DSA-SHA2-192f SLH-DSA-SHA2-256s SLH-DSA-SHA2-256f SLH-DSA-SHAKE-128s SLH-DSA-SHAKE-128f SLH-DSA-SHAKE-192s SLH-DSA-SHAKE-192f SLH-DSA-SHAKE-256s SLH-DSA-SHAKE-256f; do
  sigb=$(stat -c%s "$TMP/$label/sig.bin" 2>/dev/null || echo "?")
  for op in keygen sign verify; do
    tf="$W/outputs/timings_${label}_${op}.txt"
    [ -f "$tf" ] || continue
    read -r mean median p95 <<< $(python3 - "$tf" <<'PYEOF'
import sys, statistics
vals=sorted(int(l.strip()) for l in open(sys.argv[1]) if l.strip())
n=len(vals)
def pct(p):
    k=(n-1)*p/100.0; f=int(k); c=min(f+1,n-1)
    return vals[f] if f==c else vals[f]+(vals[c]-vals[f])*(k-f)
print(f"{statistics.mean(vals):.1f} {statistics.median(vals):.1f} {pct(95):.1f}")
PYEOF
)
    fails=$(cat "$W/outputs/failures_${label}_${op}.txt" 2>/dev/null || echo "?")
    printf "%-22s %-8s %12s %12s %12s %10s %10s\\n" "$label" "$op" "$mean" "$median" "$p95" "$fails" "$sigb"
  done
done
echo "=== end of bench_openssl.sh ==="
