# QA-03 — Hostile CMS UI Graph

Target:

CMS / App Builder visual document
→ Flutter brixta_stac_v1 renderer

Threats tested:

- ordinary valid UI
- dangling child references
- unknown block types
- self cycles
- multi-node cycles
- excessive layout nesting

Required property:

No remotely-authored or CMS-generated UI document should be able
to crash, hang, or recursively exhaust the employee application.

This QA test intentionally does NOT patch production code.
