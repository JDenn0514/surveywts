# CI Failure Handoff Block

Produce this block when CI fails. Show it to the user verbatim.

```
## CI Failure — Handoff to r-implement

Run:    #<run-id>
PR:     #<pr-number> (<pr-url>)
Job:    <job-name> (e.g., R CMD Check / ubuntu-latest / release)
Step:   <step-name>
Type:   <test failure | R CMD check error | platform-specific>

Error:
<last 40 lines of --log-failed output>

Local repro:
  Rscript -e "devtools::check()"
  Rscript -e "devtools::test()"
```

After showing the block, tell the user:

> "Invoke `/r-implement` and share the block above. After r-implement reports
> the fix is done, re-invoke `/commit-and-pr` — it will detect the existing PR
> and resume from CI monitoring."
