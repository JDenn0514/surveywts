# Stage 0: Deep Comprehension

## When to run

Run Stage 0 before Stage 1 when ANY of the following is true:

- The user has attached a paper, PDF, or markdown file of a journal article
- The feature involves a new statistical estimator or variance formulation
- The feature modifies numerical behavior (not just interface)
- The design references another package's implementation (`survey`, `srvyr`,
  `anesrake`, `calibrate`, `MASS`, `mice`)
- The feature is in the `propensity`, `diagnostics`, or `nonresponse` families

Skip Stage 0 when:
- The request is a docstring fix, parameter default, or test addition
- The request is a rename or DESCRIPTION bump
- No formulas or algorithms are involved

If unsure, run Stage 0. A brief comprehension.md costs much less than a
spec that gets the formula wrong.

---

## Your role

You are extracting what is known from the literature before the spec is
written. The goal is not to produce the spec — it is to ensure that whoever
writes the spec has the right formulas, gotchas, and reference mappings in
hand. A spec written without this is a spec that guesses at the math.

---

## Input: what to read

If the user has attached material, read it in full before writing anything.
Attachments override any prior knowledge you have about the topic — the user
is telling you which version of the method they want implemented.

Also read:
- Existing `R/` code for related functions (see how the package currently
  handles similar problems)
- `plans/error-messages.md` (understand what error conditions are already
  defined)
- The referenced package's source if relevant (e.g., `survey::calibrate`,
  `anesrake::anesrake`)

---

## Six comprehension sub-steps

Work through ALL of these before writing `comprehension.md`:

### 1. Restate the problem

In one paragraph, in your own words: what is the user trying to accomplish
and what statistical challenge does the method solve? Do not quote the paper.
Restating it forces you to actually understand it, not just paraphrase it.

### 2. Reproduce the key formulas

For each formula relevant to the feature:
- Write it out in LaTeX or precise pseudocode
- Bind every symbol to a function argument or data column
- Note the normalization convention (e.g., does the sum of weights equal N
  or the population total?)
- If there are multiple algebraically equivalent forms, note which one the
  paper or reference package uses — they may differ numerically

**Example binding table:**

| Symbol | Meaning | Bound to |
|--------|---------|----------|
| wᵢ | weight for unit i | `data[[wt_name]]` |
| N | population total | `sum(data[[wt_name]])` |
| n | sample size | `nrow(data)` |

### 3. List gotchas

For each formula or algorithm, enumerate the failure modes and boundary
conditions. Think like someone who has debugged this in production:

- **Zero-weight rows** — what happens to the formula when wᵢ = 0?
- **All-NA outcome** — does the estimator blow up? Return NA? Error?
- **Single-cell or single-PSU groups** — does the denominator go to 0?
- **Non-convergence** — for iterative methods, what if it never converges?
- **Negative outputs** — can the formula produce negative values? Are they
  valid or a sign of a bug?
- **Near-zero denominators** — what precision issues arise?

### 4. Map references to design decisions

For each citation, package function, or equation number, record which design
decision it justifies. This is what allows the methodology reviewer (Stage 2)
to check whether the spec matches the source.

Format:

```
{paper} §{section/equation} → {design decision}
```

Example:
```
Kish (1965) eq. 2.13 → effective_sample_size() uses n/(1+CV²(w))
survey::calibrate source → when GREG produces negative weights, issue warning
  not error (function still converges)
```

### 5. Extract assumptions

What does the method assume that the user's request did not state? These are
the things that will surprise implementers or users if not made explicit:

- Population model assumptions (SRS, stratified, clustered?)
- Missing data mechanism (MCAR, MAR, MNAR?)
- What does a "correct" calibrated weight mean? (Margins satisfied exactly?
  Within tolerance? In expectation?)
- Finite population correction — required or optional?
- Weight normalization — required for the formula to hold?

### 6. Flag open questions

Things you cannot resolve from the available material. These will become HOLDs
or spec decisions. List them so Stage 1 (drafting) knows where to be careful:

- "The paper doesn't specify behavior for zero-weight rows — likely error, but
  not stated."
- "Two equivalent formulas exist for ESS; the paper uses both interchangeably."

---

## Output: `comprehension.md`

Write to `plans/comprehension-{id}.md` (for the durable record) AND to the
workspace run directory.

Use this structure:

```markdown
# Comprehension — {id}

## Problem
{one paragraph in your own words}

## Formulas
{LaTeX or pseudocode for each formula; include symbol binding table}

## Gotchas
- {zero-weight rows} — {what the formula does}
- {non-convergence} — {what to watch for}
[enumerate all]

## Reference mapping
- {paper/package} §{section/equation} → {design decision}
[one entry per citation or source function]

## Assumptions
- {assumption} — {why it matters}
[one entry per implicit constraint]

## Open questions
- {question} — {why it can't be resolved from available material}
[if any]
```

---

## After Stage 0

Tell the user:

> "comprehension.md is written. Next: Stage 1 will use it to draft both
> spec-{id}.md and test-spec-{id}.md. The Literature Lens in Stage 2 will
> cross-check the spec's formulas against this comprehension document."

Do NOT draft the spec in the same session as Stage 0 unless the user explicitly
asks to continue. Stage 0 is a research pass; Stage 1 is a writing pass. Keep
them separate so the drafting process starts with a clear head.
