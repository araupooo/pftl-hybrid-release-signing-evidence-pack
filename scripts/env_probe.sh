#!/usr/bin/env bash
# env_probe.sh — environment fingerprint for the release-signing pack.
# Prints machine, CPU, memory, tool versions, and the pinned postfiatd
# commit this pack was checked against. No network calls.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OSSL_INSTALL="$W/work/openssl-3.5.9-install"
echo "=== ENVIRONMENT PROBE ==="
echo "date_utc: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "hostname: $(hostname)"
echo "os: $(uname -srmo) / $(cat /etc/os-release 2>/dev/null | grep '^PRETTY_NAME=' | cut -d= -f2- | tr -d '"')"
echo "cpu_model: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ //')"
echo "cpu_count: $(nproc)"
echo "mem_total_kb: $(grep MemTotal /proc/meminfo | awk '{print $2}')"
echo "disk_free_root: $(df -h / | tail -1 | awk '{print $4}')"
echo "python3: $(python3 --version 2>&1)"
echo "git: $(git --version 2>&1)"
echo "curl: $(curl --version 2>/dev/null | head -1)"
echo "cmake: $(cmake --version 2>/dev/null | head -1)"
echo "gcc: $(gcc --version 2>/dev/null | head -1)"
echo "system openssl: $(openssl version 2>&1)"
if [ -x "$OSSL_INSTALL/bin/openssl" ]; then
  echo "pack openssl: $(LD_LIBRARY_PATH="$OSSL_INSTALL/lib64" "$OSSL_INSTALL/bin/openssl" version 2>&1)"
  echo "pack openssl providers:"
  LD_LIBRARY_PATH="$OSSL_INSTALL/lib64" "$OSSL_INSTALL/bin/openssl" list -providers 2>&1 | sed 's/^/  /'
  echo "pack openssl ML-DSA/SLH-DSA/ML-KEM algorithms present:"
  LD_LIBRARY_PATH="$OSSL_INSTALL/lib64" "$OSSL_INSTALL/bin/openssl" list -public-key-algorithms 2>/dev/null | grep -o -E "ML-DSA-[0-9]+|SLH-DSA-[A-Z]+-[0-9]+[sf]|ML-KEM-[0-9]+" | sort -u | sed 's/^/  /'
else
  echo "pack openssl: NOT BUILT YET (run_all.sh provisions it)"
fi
if [ -d "$W/src/postfiatd" ]; then
  echo "postfiatd HEAD: $(cd "$W/src/postfiatd" && git rev-parse HEAD) ($(cd "$W/src/postfiatd" && git log -1 --format='%ci %s'))"
else
  echo "postfiatd checkout: absent (src/postfiatd not present in this copy)"
fi
echo "=== end of env_probe.sh ==="
