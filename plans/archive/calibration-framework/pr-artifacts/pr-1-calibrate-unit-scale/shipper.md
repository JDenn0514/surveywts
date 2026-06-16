# Shipper Record — PR 1: calibrate-unit-scale

**Date:** 2026-06-09
**Agent:** shipper
**Verdict gate:** review2.md = PASS

---

## Ship Summary

| Field | Value |
|-------|-------|
| Branch | `feature/calibrate-unit-scale` |
| Base | `develop` |
| GitHub PR | N/A — branch already merged locally before push |
| Merge commits on develop | `56bdb39` (feat commit), `842f8a9` (tolerance fix) |
| develop HEAD after ship | `842f8a9c5d1e9acb09b4a822460ff6c3e811f103` |
| Feature branch pushed to origin | Yes (`bfad47d`) |
| develop pushed to origin | Yes (`842f8a9`) |

## What Happened

The feature branch (`feature/calibrate-unit-scale`) had already been merged
into local `develop` before this shipper ran. The two relevant commits were:

- `56bdb39` — `feat(calibration): wire q_weights through NR engine and fix per-unit absolute bounds (#66)`
- `842f8a9` — `test(calibration): restore 1e-8 tolerance on absolute-bounds oracle tests (HL-8, HL-11, HG-7, HG-10)`

Both commits were pushed to `origin/develop`. A GitHub PR could not be created
because `feature/calibrate-unit-scale` on origin (`bfad47d`) is an ancestor of
`develop` — GitHub rejects PRs with zero unique commits against the base.

The work is fully shipped: all spec items (D1–D3, D6) are live on
`origin/develop`.

## Artifacts

- Audit: `plans/calibration-framework/pr-1-calibrate-unit-scale/audit2.md`
- Review: `plans/calibration-framework/pr-1-calibrate-unit-scale/review2.md`
- impl-plan: `plans/impl-calibrate-unit-scale.md` (PR 1 marked `[x]`)

## HOLDs

None.
