# r-universe Setup

Publish `surveywts` to `https://jdenn0514.r-universe.dev`.

The universe already exists and serves `surveycore` and `surveytidy`, but
`surveywts` is not yet registered.

---

## Step 1 — Create the registry repository

The registry repo `github.com/JDenn0514/jdenn0514.r-universe.dev` does not
exist. Create it:

1. Go to https://github.com/new
2. Repository name: `jdenn0514.r-universe.dev` (lowercase, exact)
3. Owner: `JDenn0514`
4. Visibility: **Public**
5. Initialize with a README (optional)

Then create `packages.json` in the repo root listing every package you want
in your universe. Based on current state (`surveycore` and `surveytidy` are
already being served), the file should include at minimum:

```json
[
  {
    "package": "surveycore",
    "url": "https://github.com/JDenn0514/surveycore"
  },
  {
    "package": "surveytidy",
    "url": "https://github.com/JDenn0514/surveytidy"
  },
  {
    "package": "surveywts",
    "url": "https://github.com/JDenn0514/surveywts"
  }
]
```

> **Note:** The current universe state (serving `surveycore` and `surveytidy`)
> is from an auto-generated registry because the r-universe GitHub app is
> already installed on your account. Creating a proper `packages.json` takes
> precedence over the auto-generated one once pushed.

---

## Step 2 — Install the r-universe GitHub app (if not already)

The app appears to already be installed (packages are being served). Confirm
at https://github.com/settings/installations — you should see "r-universe"
listed. If not, install it at https://github.com/apps/r-universe and select
the `JDenn0514` account.

---

## Step 3 — Update DESCRIPTION

Add the r-universe URL to the `URL` field so it appears in package metadata
and SEO:

```
URL: https://github.com/JDenn0514/surveywts,
    https://jdenn0514.github.io/surveywts/,
    https://jdenn0514.r-universe.dev/surveywts
```

---

## Step 4 — Add GitHub repository topics

The `JDenn0514/surveywts` repo currently has **zero topics**, which hurts
search ranking on r-universe. Add these on the repo's main page (gear icon
next to "About"):

`r-package`, `survey`, `statistics`, `weights`, `calibration`, `tidyverse`

---

## Step 5 — Verify maintainer email

DESCRIPTION has `jdenn0514@gmail.com`. For your profile picture and
contributor stats to appear on r-universe, this email must be a **verified**
email on your GitHub account.

Check at: https://github.com/settings/emails

---

## Step 6 — Wait for the build

After pushing `packages.json`, r-universe will detect the change within
minutes and queue a build. The first build takes ~20–30 minutes.

Monitor progress at: `https://jdenn0514.r-universe.dev/builds`

The package will appear at `https://jdenn0514.r-universe.dev/surveywts` once
the build succeeds.

---

## Already good — no action needed

- README has r-universe badge and installation instructions
- `X-schema.org-keywords` in DESCRIPTION (SEO keywords)
- Logo at `man/figures/logo.png` (r-universe detects this automatically)
- `surveycore` will be in the universe as a dependency — the
  `Remotes: JDenn0514/surveycore` field will resolve correctly
- pkgdown site configured
- R CMD check CI already running

---

## Potential build issue to watch

If the first build fails, check the log at
`https://jdenn0514.r-universe.dev/surveywts`. The most likely cause is the
`Remotes: JDenn0514/surveycore` field — r-universe should resolve this
because surveycore is in the same universe, but if it can't, the fix is to
ensure surveycore's entry in `packages.json` appears before surveywts's
entry.
