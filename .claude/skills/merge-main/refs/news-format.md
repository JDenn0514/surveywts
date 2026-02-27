# NEWS.md Format

New section goes at the **very top** of `NEWS.md`, above any existing header.

## Template

```markdown
# surveyweights X.Y.Z

## New features

* `new_function()` does X based on [changelog bullet].

## Bug fixes

* `existing_function()` now correctly handles [edge case].
```

## Rules

- Group `feat:` entries under `## New features`
- Group `fix:` entries under `## Bug fixes`
- Omit `docs:`, `test:`, `chore:`, `refactor:` — users don't need them
- Each bullet is one sentence; use backtick-quoted function names
- Omit a section entirely if it has no entries
- Add `## Internal infrastructure` only for significant architectural changes
  the user explicitly wants documented
