# postfiatd Release-Process Gap Analysis

**Checked against:** `postfiatorg/postfiatd`, `main` at commit
`0085a1ff885d6a446369cf73a4430f75af22be55` (2026-10-10, "Merge pull
request #50 from postfiatorg/hotfix/upstream-hardening-1.0.9"), cloned
20 Nov 2026. All file/line references below are to that commit.

## What the release process is today

`docs/RELEASE.md` (100 lines) describes the whole process:

1. Bump the version string in `src/libxrpl/protocol/BuildInfo.cpp`
   (single source of truth; CMake extracts it at build time).
2. Commit to `main`; merge to the target network branch (`devnet`,
   `testnet`, `mainnet`, `ai-devnet`).
3. Push triggers the build workflow, which extracts the version,
   checks Docker Hub for existing versioned tags (fails if the version
   already exists), and builds/pushes images with rolling and versioned
   tags (`agtipft/postfiatd:{network}-{size}-latest` and
   `agtipft/postfiatd:{network}-{size}-{version}`; 3 sizes x 2 tags).
4. The testnet build publishes the GitHub Release `v{version}` at the
   built commit; release notes are generated from merged PRs plus
   operator upgrade instructions. The release is the public
   announcement feed (operators subscribe via GitHub Watch / Releases;
   tooling can poll `https://github.com/postfiatorg/postfiatd/releases.atom`).

Rollback today is manual: run the update workflow with a previous
version (`gh workflow run update.yml -f version=3.0.0`). The versioned
tag is immutable and always available on Docker Hub.

## What is missing (verified by reading the tree)

| Gap | Evidence at 0085a1ff |
|---|---|
| **No release-artifact signing at all.** No signature, digest, checksum, or verification step anywhere in the release path. | `docs/RELEASE.md` contains zero occurrences of "sign"; the word "signature" does not appear. A repo-wide grep for `gpg\|cosign\|sigstore\|signing` over `*.md` finds only git commit signing (`CONTRIBUTING.md`, lines 438–441, 568) and validator-key manifests (`docs/ValidatorKeyUpdate.md`) — neither is release-artifact signing. |
| **No artifact digests published.** Operators have no hash to check a downloaded image or binary against. | `docs/RELEASE.md` publishes no SHA-256 (or any) digest for images or the GitHub Release assets. The Docker Hub tag check (`curl .../tags/testnet-light-1.0.0`, 200 = exists) is an existence check, not an integrity check. |
| **No rollback protection.** Rollback is a manual operator action with no monotonic counter and no version check in any verifier. | `docs/RELEASE.md` "Rollback" section: run the update workflow with a previous version. Nothing in the tree enforces that an installed version cannot be replaced by an older one, and nothing records which counter/version an operator last installed. A stale but correctly-built image is indistinguishable from a current one to the deployment tooling. |
| **No key-compromise story.** No signing keys exist to compromise, so there is also no revocation record, no key rotation procedure, and no incident runbook for the release channel. | `docs/ValidatorKeyUpdate.md` covers validator signing-key rotation (ephemeral signing key, validator token, master-key signatures) — that is consensus identity, not release signing. No equivalent document exists for releases. |

## What the hybrid scheme in this pack would add (mapping)

| Pack artifact | Fills which gap | How it maps to postfiatd |
|---|---|---|
| `scripts/dual_sign_demo.sh` + `scripts/verify_manifest.sh` | Release-artifact signing + digests | Manifest with artifact SHA-256 digests, signed Ed25519 + ML-DSA-65; verifier checks digests, fingerprints, and both signatures before accepting. The manifest is the missing integrity layer for the GitHub Release / Docker image pair. |
| Monotonic counter in the manifest (`monotonic_counter`, checked `>= installed`) | Rollback protection | The counter is the missing enforcement behind the manual "run the update workflow with a previous version" step: a verifier holding the installed counter rejects any manifest with a lower one, even if its signatures are valid (`scripts/downgrade_sim.sh`, case B). |
| `scripts/downgrade_sim.sh` (6 cases) | Downgrade / stripping attacks | Proves the verifier rejects a stale manifest, a classical-only manifest (missing ML-DSA signature), a PQ-only manifest, a tampered artifact, and swapped signatures — the attack classes the current process cannot detect at all. |
| `docs/key-compromise-playbook.md` + `scripts/compromise_drill.sh` | Key-compromise story | Six-step runbook (freeze, revoke, rotate, verify rejection, notify with fingerprints, post-mortem) with a scripted 5-step drill proving revocation works and rotation is real. |
| `scripts/composite_probe.sh` + RFC 10073 OIDs | Standards-tracked future | Composite ML-DSA (RFC 10073, Nov 2026) is not runnable in stock OpenSSL 3.5.9; dual signatures are the implementable-today shape. When a composite-capable toolchain ships, the manifest's `hybrid` metadata block is where the composite OID (e.g. `1.3.6.1.5.5.7.6.48` for MLDSA65-Ed25519-SHA512) would be recorded. |

## What this pack does not claim

- This pack does **not** change postfiatd. It is an evidence pack and a
  runnable demo against fixed-content demo artifacts, not a patch to
  the release workflow.
- The demo artifacts (`postfiatd-1.0.0-linux-amd64`,
  `postfiatd-firmware-1.0.0.bin`, `RELEASE-NOTES-1.0.0.txt`) are
  fixed-content placeholders. They are **not** real postfiatd binaries.
- The recommendation (hybrid Ed25519 + ML-DSA-65 now; SLH-DSA-128s as
  a commercial-only hash-based fallback, scoped out of NSS firmware
  where CNSA 2.0 requires LMS/XMSS per SP 800-208) is in
  `docs/scheme-comparison.md` and `docs/findings.md`.
