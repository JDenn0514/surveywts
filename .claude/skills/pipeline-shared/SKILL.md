---
name: pipeline-shared
description: >
  Shared reference infrastructure for the surveywts pipeline skills. Not invoked
  directly — loaded by pipeline-spec, pipeline-implement, pipeline-ship, and
  pipeline-simplified as needed.
---

# Pipeline Shared References

This skill is a reference library, not a workflow. Pipeline orchestrating skills
load specific reference files from here as needed.

## Reference files

| File | Used by |
|------|---------|
| `references/state-model.md` | all pipeline skills |
| `references/artifact-schemas.md` | planner, reviewer, pipeline-spec, pipeline-implement |
| `references/pipeline-isolation.md` | pipeline-ship, builder, tester, reviewer |
| `references/signals.md` | all agents, pipeline-ship |
| `references/workspace-layout.md` | all pipeline skills |
| `references/r-package-profile.md` | builder, tester, reviewer |
