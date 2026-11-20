# Sources

All sources are public. Accessed 20 Nov 2026 unless noted. Primary
sources (standards, advisories, project docs) are listed first; the
research report that synthesised them is listed last.

## Standards (primary)

- RFC 10073, Composite ML-DSA for X.509, Standards Track, Nov 2026 —
  https://www.rfc-editor.org/rfc/rfc10073.txt
  (verified live 20 Nov 2026: composite OIDs §8.2, e.g.
  id-MLDSA65-Ed25519-SHA512 = 1.3.6.1.5.5.7.6.48; EUF-CMA only,
  not SUF-CMA, §9.2; Appendix A sizes: MLDSA65-Ed25519 pk 1,984 B,
  sig 3,373 B)
- RFC 10082, Composite ML-DSA in CMS, Nov 2026 —
  https://datatracker.ietf.org/doc/rfc10082/
- RFC 9881, ML-DSA in X.509, Oct 2025 —
  https://www.rfc-editor.org/info/rfc9881/
  (pure ML-DSA only in X.509; HashML-DSA banned; ML-DSA-65 pk 1,952 B,
  sk 4,032 B expanded / 32 B seed, sig 3,309 B)
- RFC 9909, SLH-DSA in X.509, Dec 2025 —
  https://www.rfc-editor.org/info/rfc9909/
  (Pure and HashSLH-DSA both specified)
- FIPS 204, Module-Lattice-Based Digital Signature Standard (ML-DSA),
  Aug 2024 — https://doi.org/10.6028/NIST.FIPS.204
- FIPS 205, Stateless Hash-Based Digital Signature Standard (SLH-DSA),
  Aug 2024 — https://doi.org/10.6028/NIST.FIPS.205
  (12 parameter sets; 128s sig 7,856 B, 128f sig 17,088 B,
  192f sig 35,664 B, 256f sig 49,856 B)
- NIST IR 8547 final, 27 Oct 2026 —
  https://csrc.nist.gov/pubs/ir/8547/final
  (quantum-vulnerable public-key algorithms deprecated after 2030 and
  disallowed after 2035 at every key size; federal high-value assets:
  PQC key exchange by 31 Dec 2030, PQC signatures by 31 Dec 2031;
  EO 14412 / OMB M-26-15, June 2026)
- NIST SP 800-208, Recommendation for Stateful Hash-Based Signature
  Schemes, Oct 2020 — LMS/XMSS, single-tree only, no HSS/XMSS-MT
  (CNSA 2.0 firmware choice)
- NIST SP 800-230 (initial public draft, Apr 2026) —
  https://csrc.nist.gov/pubs/sp/800/230/ipd
  (future SLH-DSA firmware set: 3,856 B signatures, 2^24-signature cap)
- RFC 8554 (LMS), RFC 8391 (XMSS)
- NSA CNSA 2.0 v2.1, Dec 2024 — ML-DSA-87 for general signatures;
  LMS/XMSS (SP 800-208) for software/firmware signing; SLH-DSA is
  NOT in CNSA 2.0. See https://210security.com/blog/what-cnsa-2-0-does-not-approve/
- RFC 9794 (PQ/T hybrid terminology), RFC 9958, RFC 9955 (non-separability)

## Implementations and tooling (primary)

- OpenSSL 3.5.9 (29 Sep 2026) — the measurement toolchain of this pack;
  tarball SHA-256
  `603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a`
  (https://www.openssl.org/source/openssl-3.5.9.tar.gz)
- OpenSSL security advisory, 13 Mar 2026 (CVE-2026-2673) —
  https://openssl-library.org/news/secadv/20260313.txt
  (TLS 1.3 group-negotiation downgrade; affected 3.5.0–3.5.5, fixed
  3.5.6; 3.6.0–3.6.1, fixed 3.6.2; severity Low; no FIPS module
  affected. OpenSSL 3.6 EOL 1 Nov 2026.)
- liboqs 0.16.0 (9 Jul 2026) — RELEASE.md,
  https://raw.githubusercontent.com/open-quantum-safe/liboqs/main/RELEASE.md
  (mldsa-native default ML-DSA backend; Dilithium removed 0.15.0;
  SPHINCS+ removed 0.16.0; no FIPS 140-3 validation)
- PQClean retirement — https://groups.google.com/a/list.nist.gov/g/pqc-forum/c/Z30-l8mTNRU
- Bouncy Castle 1.85 — https://www.bouncycastle.org/resources/new-release-bouncy-castle-java-1-85/
  (1.84 is the implementation verified by the independent interop test
  in Kim et al., arXiv:2607.20800 — cited, not run here: no Java
  runtime in this environment)
- Go 1.27 release notes (go.dev) — stdlib `crypto/mldsa`
- Android APK Signature Scheme v3.2 —
  https://source.android.com/docs/security/features/apksigning/v3-2
  (dual independent signatures: classical + ML-DSA-65/87, both required,
  anti-stripping — the model for this pack's manifest demo)

## Ecosystem plans (primary)

- Sigstore, "Post-Quantum Cryptography for Sigstore" (blog, 2 Oct 2026) —
  https://blog.sigstore.dev/pqc-sigstore/
  (separate ML-DSA stack, own ML-DSA-signed TUF root; production public
  instance targeted mid-2027, opt-in at first; classical instance
  supported until turndown tentatively 2029–2030; no hybrid
  certificates, no dual signatures)
- Sigstore 2025 PQC blog — https://blog.sigstore.dev/post-quantum-2025/
- TUF specification — https://theupdateframework.github.io/specification/latest/
- in-toto attestation framework v1.2.0 (18 Mar 2026); SLSA v1.2

## Vulnerabilities and incidents (primary)

- CVE-2020-10713, BootHole (Eclypsium, 29 Jul 2020; NSA advisory
  30 Jul 2020; CVSS 8.2) —
  https://media.defense.gov/2020/Jul/30/2002467902/-1/-1/0/CSA_MITIGATE_THE_GRUB2_BOOTHOLE_VULNERABILITY_20200730_NSA_GOV
- CVE-2022-21894, Baton Drop / BlackLotus (published 11 Jan 2022;
  BlackLotus confirmed Mar 2023 by ESET); BlackX disclosed 22 Oct 2026
  by Kaspersky —
  https://windowsforum.com/news/blackx-bootkit-bypasses-secure-boot-on-patched-windows-pcs-why-dbx-revocation-matters.450881/
- CVE-2024-7344, Howyar `reloader.efi` (ESET disclosure 16 Jan 2025;
  Microsoft DBX revocation 14 Jan 2025; CVSS 8.2)
- CVE-2026-22705 (RustCrypto ML-DSA `Decompose` timing side channel,
  NVD 10 Jan 2026, CVSS 6.4) —
  https://blog.projecteleven.com/posts/pq-implementation-vulnerabilities-volume-1-a-rustcrypto-side-channel-cve
- CVE-2026-46344 / CVE-2026-44518 (liboqs XMSS OOB read, fixed 0.16.0)
- GHSA-r7wm-4vf2-h44w / RUSTSEC-2026-0426 (orion, LLVM reintroduces a
  secret-dependent branch, 30 Oct 2026) —
  https://intel.fencer.dev/GHSA-r7wm-4vf2-h44w
- Zhao et al., "Rejection Matters", ePrint 2026/056, IACR News 14 Jan 2026 —
  https://eprint.iacr.org/2026/056.pdf
- GHSA-764m-3ppc-5m73, Microsoft `agent-framework` 1.26.1/1.26.2
  credential stealer via compromised publishing path (17–18 Nov 2026)
- Android OEM platform-key leak (Dec 2022) —
  https://candid.technology/lg-samsung-mediatek-revoview-certificate-used-to-sign-malicious-android-apps/?amp=1
- NVIDIA leaked code-signing certificates (2022) —
  https://www.bleepingcomputer.com/news/security/malware-now-using-nvidias-stolen-code-signing-certificates/
- HashiCorp HCSEC-2021-12 (Codecov) —
  https://discuss.hashicorp.com/t/hcsec-2021-12-codecov-security-event-and-hashicorp-gpg-key-exposure/23512/2

## postfiatd (primary, local checkout)

- `postfiatorg/postfiatd`, `main` at
  `0085a1ff885d6a446369cf73a4430f75af22be55` (2026-10-10) —
  https://github.com/postfiatorg/postfiatd
  (`docs/RELEASE.md`, 100 lines: no release-artifact signing, no
  digests, manual rollback; `docs/ValidatorKeyUpdate.md`: validator
  signing-key rotation; `CONTRIBUTING.md`: git commit signing only)

## Prior work (this program)

- Prior release-signing evidence pack (14 Nov 2026) —
  https://github.com/araupooo/postfiat-release-signing-pqc-assessment
  (liboqs 0.16.0 + PQClean drivers; hybrid Ed25519 + ML-DSA-65 verify
  190.366 us median, hybrid signature 3,373 B, SLH-DSA-SHA2-128s
  7,856 B / 128f 17,088 B; 12/12 negative tests; 5/5 rotation drill.
  This pack re-measures with OpenSSL 3.5.9 native tooling across all
  12 SLH-DSA sets and adds the manifest demo, downgrade simulation,
  compromise drill, and the post-14-Nov standards/CVE layer.)
- Research report this pack is built on (20 Nov 2026) —
  `~/workspace/research_notes/pq-release-signing-nov-2026-20261120/report.md`
  (99 KB; RFC 10073/10082, IR 8547 final, Sigstore plan, CNSA 2.0
  correction, 4 rollback CVEs, 2026 CVE layer, downgrade-simulation
  harness design, incident case studies; research only, no
  re-measurement — the measurements in this pack are new)

## Secondary / cross-check sources

- Size tables cross-check — https://guptadeepak.com/post-quantum-key-and-signature-sizes/
- SLH-DSA parameter sets — https://fieldguide.lamarrlabs.com/SLH-DSA-parameter-sets
- ML-DSA vs SLH-DSA compared — https://hadamard.com/c/ml-dsa-vs-slh-dsa-signatures-compared/
  (Cloudflare normalised ratios: SLH-DSA signing ~14,000x slower than
  ML-DSA-44; verification only ~40x)
- liboqs 0.16.0 benchmarks —
  https://quantum-safe-py.readthedocs.io/en/latest/guides/benchmarks.html
- Firmware-vendor guidance (AppViewX Oct 2026; Encryptorium Book of
  PQC ch. 29, Oct 2026): pilot ML-DSA internally; LMS or ML-DSA-87 for
  new firmware (NSS); SLH-DSA for commercial non-NSS software signing
- Chrome ML-DSA / Merkle Tree Certificates —
  https://googlechrome.github.io/chromerootprogram/cqrp/testing/
- Cloudflare 1.1.1.1: ML-DSA-44 for post-quantum DNSSEC validation
  (Sep 2026); IANA DNSSEC registry (updated 10 Aug 2026): ML-DSA-44
  is the only PQC algorithm in the registry
