# Google Play Console — Hugrún Setup Runbook

**Audience:** A Claude instance running in a browser-driving context (Claude Chrome / browser-use / Skyvern / similar) that can click, type, and read web pages on behalf of the developer (Jon).

**Goal:** Set up the Hugrún app in Google Play Console end-to-end so it's ready for the first internal-testing-track upload via the GitHub Actions `deploy-android.yml` workflow.

**Scope:** This document covers the FULL initial Play Console setup including the kids'-app-specific Designed for Families requirements. Subsequent uploads (after this runbook completes) happen automatically via the CI workflow.

---

## 0. Pre-flight — what must be true before starting

### 0.1 Identity & access

The browsing agent must be running in a Chrome profile that's already signed into the Google account that:
- Owns (or has Admin permission on) the Hugrún Google Play Console developer account
- Is the same account that owns (or has Editor on) the Google Cloud project where the service account JSON for CI will be created

If the agent is NOT signed in: STOP. Ask Jon to sign in to https://accounts.google.com first. Don't attempt to log in on Jon's behalf — credentials must not flow through the agent.

### 0.2 Google Play Developer account

A registered Google Play Developer account is required. If Jon doesn't have one:
1. Navigate to https://play.google.com/console/signup
2. Pay the **one-time $25 USD registration fee**
3. Verify identity (Google requires government-issued ID for Play Console accounts since 2024)
4. Wait for approval (usually <24h, can be up to 14 days)

**This step CANNOT be done by an agent** — it requires personal ID upload and a payment. STOP and surface to Jon if the account doesn't exist yet. The rest of this runbook assumes the account exists and is approved.

### 0.3 Project facts (from PROJECT.md)

- **App name:** Hugrún
- **Package name:** `is.hugrun.app`
- **Default language:** Icelandic (is)
- **Target audience:** Children ages 4–6 (Designed for Families)
- **Privacy posture:** Fully local — no network calls during play, no analytics, no ads, no IAP
- **Developer:** Jon Björnsson (or as registered on the Google Play account)
- **Support email:** Jon's email (use whatever Jon entered when registering — the agent can read it from Play Console settings)

### 0.4 Privacy policy — REQUIRED before any kids' app can go live

Hugrún does NOT have a privacy policy yet. Google Play requires a publicly-accessible privacy policy URL for any app in the Designed for Families program.

**Recommended path before starting:**
1. Create a simple privacy policy at `https://hugrun.is/privacy` (or similar) — a static HTML page that says:
   - "Hugrún does not collect, store, or transmit any personal data"
   - "Photos uploaded by parents stay on the device and are never sent anywhere"
   - "There are no ads, no analytics, no in-app purchases"
   - "If you have questions, contact: [email]"
2. Or use a free hosting service: GitHub Pages, Netlify, Vercel — all work
3. Or generate via a free privacy policy template (e.g., https://app-privacy-policy-generator.firebaseapp.com/)

Save the URL — the agent will need to enter it in Play Console.

If the URL doesn't exist: the agent can SKIP the privacy-policy field for now (Play Console allows leaving it empty during setup but will require it before publishing). Document this gap in the run summary.

### 0.5 Assets to have ready

The agent will need these assets to upload during setup. Check `.planning/deployment/play-store-assets/` for:

| Asset | Spec | Status |
|-------|------|--------|
| App icon | 512×512 PNG, ≤1MB | NEEDS CREATING — currently default Flutter icon |
| Feature graphic | 1024×500 PNG/JPG | NEEDS CREATING |
| Phone screenshots | 2-8 images, 16:9 or 9:16, min 320px short edge | Available at `screenshots-v2/` (re-export at correct sizes) |
| Tablet screenshots | 2-8 images, 16:10 or 10:16 | Available at `screenshots-v2/` |
| Short description | ≤80 chars, Icelandic + English |  Draft below |
| Full description | ≤4000 chars, Icelandic + English | Draft below |

**If these assets don't exist:** agent should create the listing with placeholder text/screenshots, mark as "DRAFT — assets pending" in run summary, and stop before submitting for review. Jon can fill in real assets later.

**Suggested short description (Icelandic):**
> Stafir og tölur fyrir 5 ára. Engar auglýsingar, engin innheimta, ekkert net.

**Suggested short description (English):**
> Icelandic letters and numbers for kids ages 4–6. No ads, no IAP, no network.

**Suggested full description (Icelandic):**
> Hugrún hjálpar börnum að læra íslenska stafrófið og fyrstu tölurnar með snertimyndum, hljóðum og leikjum. Sérsniðið fyrir 5 ára. Engar auglýsingar, engar innkaup, ekkert internet þarft.
>
> Eiginleikar:
> • Allir 32 stafir íslenska stafrófsins með röddum
> • Tölur 1-10 með kynjabeygingu
> • Stafa-mynda samsvörun
> • Stafa-blöndun (CVC)
> • Stafa-skrift (Ítalíuskrift)
> • Foreldraskjár til að bæta við myndum
>
> Ekkert á netinu, engar persónuupplýsingar safnaðar.

**Suggested full description (English):**
> Hugrún helps Icelandic-speaking children ages 4–6 learn the alphabet and early numeracy through tap, hear, and play. Built for one child, with optional personalization (parent-uploaded photos tagged with Icelandic words).
>
> Features:
> • All 32 Icelandic letters with native-recorded audio
> • Numbers 1–10 with proper Icelandic gender forms
> • Letter-to-word matching activity
> • CVC blending (kýr, sól, hús, rós)
> • Letter tracing (Ítalíuskrift handwriting model)
> • Parent settings — add photos, tag with words
>
> No ads. No in-app purchases. No analytics. No internet required during play. Photos stay on the device.

---

## 1. Create the app in Play Console

### 1.1 Navigate to Play Console

URL: **https://play.google.com/console/**

Wait for the dashboard to load. Verify the agent is signed in by reading the avatar/account name in the top-right.

### 1.2 Create a new app

Click the **"Create app"** button (top-right corner of the All apps page).

Fill in the dialog:

| Field | Value |
|-------|-------|
| App name | `Hugrún` |
| Default language | Click dropdown → search for `Icelandic – is-IS` → select |
| App or game | Select **App** |
| Free or paid | Select **Free** |
| Declarations checkboxes | ✅ Check both — "I understand Developer Program Policies" and "I understand the US export laws" |

Click **Create app**.

You'll land on the app dashboard for Hugrún.

---

## 2. Set up the app — left-sidebar tasks

The Play Console shows a "Set up your app" checklist on the dashboard. Each item below corresponds to one checklist task. Complete in order; the agent can skip optional items but should at minimum complete every REQUIRED item.

### 2.1 App access

Sidebar: **Policy → App access** (or Dashboard → "Set up your app" → "App access")

| Question | Answer |
|----------|--------|
| Is all functionality available without restrictions? | Select **All functionality is available without special access** |

Click **Save**.

(Hugrún has no login, no paid tier, no gated content — fully open.)

### 2.2 Ads

Sidebar: **Policy → Ads** (or via checklist)

| Question | Answer |
|----------|--------|
| Does your app contain ads? | Select **No, my app does not contain ads** |

Click **Save**.

### 2.3 Content rating

Sidebar: **Policy → Content ratings**

Click **Start questionnaire**.

Email address: pre-filled with developer email — confirm it.

Category: Select **Reference, News, or Educational**.

Then answer each question:

| Section | Answer |
|---------|--------|
| Violence | **No** to all (no violence, no realistic depictions of violence, etc.) |
| Sexual content | **No** to all |
| Profanity | **No** to all |
| Drugs/alcohol/tobacco | **No** to all |
| Gambling | **No** to all |
| User-generated content | **No** (parent-uploaded photos stay on device, no shared/social UGC) |
| Personal info collection | **No** (Hugrún collects nothing) |
| Sharing | **No** to all sharing/social features |
| Location | **No** to all location questions |
| Digital purchases | **No** |
| Web browsing | **No** |
| Sensitive themes | **No** to all |

Submit the questionnaire. Expected rating: **Everyone** (US ESRB) / **PEGI 3** / **IARC General**.

Click **Apply rating**.

### 2.4 Target audience and content

Sidebar: **Policy → Target audience and content**

Step 1 — Age groups: ✅ Check **Ages 5 and Under** AND **Ages 6-8**. (Hugrún is for 5-year-olds; including 6-8 covers the natural extension as the child grows. Do NOT check older age groups — that triggers Designed-for-Families requirements and disqualifies if the user-generated content question conflicts.)

Step 2 — App appeal: When asked "Would your app's elements unintentionally appeal to children?" → Select **No, my app's elements would not unintentionally appeal to children outside the target age group**.

Step 3 — Store presence: Select **Yes, my app should be available in the Designed for Families program**.

Step 4 — Account creation: Answer **No** (no account creation).

Step 5 — Sign-in: Answer **No**.

Step 6 — Mixed audience review: Confirm Hugrún is targeting under-13 and includes appropriate safeguards. Confirm.

Click **Save**.

### 2.5 News apps

Sidebar: **Policy → News apps**

| Question | Answer |
|----------|--------|
| Is your app a news app? | **No** |

Click **Save**.

### 2.6 Health apps

Sidebar: **Policy → Health apps** (if present in newer console; skip if not)

| Question | Answer |
|----------|--------|
| Is this a health app? | **No** |

### 2.7 COVID-19 contact tracing/status apps

| Question | Answer |
|----------|--------|
| Is this a COVID-19 app? | **No** |

### 2.8 Data safety

Sidebar: **Policy → Data safety**

This is the most important section for a kids' app. Click **Start**.

**Data collection and security:**

Question 1: Does your app collect or share any of the required user data types?
→ Select **No**

If "No" is selected, most subsequent sections become optional and you can declare "no data collected."

But the agent MUST also configure these screens:

**Encryption in transit:** N/A (no data leaves device).

**Data deletion:** Select **Users can request that their data be deleted** = **No, my app doesn't collect any user data**.

**Independent security review:** Optional.

**Disclosures summary:** Should auto-fill as:
- "This app does not collect or share any user data"
- "All data stays on the user's device"

Click **Save**, then **Submit**.

### 2.9 Government apps

| Question | Answer |
|----------|--------|
| Is this a government app? | **No** |

### 2.10 Financial features

Skip — Hugrún has none.

### 2.11 Designed for Families program details

Sidebar: **Policy → Designed for Families** (only appears after step 2.4)

Confirm:
- Target audience: **5 and under, 6-8**
- Privacy policy URL: paste the URL from §0.4 (or leave blank with note: needs to be added before public release)
- ✅ Confirm app complies with Families Policy
- ✅ Confirm no third-party SDKs collect data from kids
- ✅ Confirm no ads or IAP

Click **Save**.

### 2.12 Store listing

Sidebar: **Grow → Store presence → Main store listing**

| Field | Value |
|-------|-------|
| App name | `Hugrún` |
| Short description | (Use Icelandic short from §0.5) |
| Full description | (Use Icelandic full from §0.5) |
| App icon | Upload `play-store-assets/icon-512.png` (or NEEDS CREATING placeholder) |
| Feature graphic | Upload `play-store-assets/feature-1024x500.png` (or NEEDS CREATING placeholder) |
| Phone screenshots | Upload at least 2 from `screenshots-v2/` |
| 7-inch tablet screenshots | Upload at least 2 |
| 10-inch tablet screenshots | Upload at least 2 |
| Video URL | (skip) |

After Icelandic, scroll up and **Add language** → English (United States) → fill English versions of name + descriptions.

Click **Save**.

### 2.13 Pricing & distribution

Sidebar: **Pricing & distribution → Pricing**
- App is **Free**
- Confirm by clicking **Save**

Sidebar: **Pricing & distribution → Countries / regions**
- Click **Add countries / regions**
- For initial launch: select **Iceland** only (smallest blast radius, native target market)
- Later expansion can add Denmark, Norway, Sweden, US, etc.
- Click **Add**

### 2.14 App content (final review)

Dashboard → "Set up your app" → all items should now be ✅ green.

If any are still ❌ red, the agent should drill into them and complete.

---

## 3. Set up internal testing track

### 3.1 Create the internal testing track

Sidebar: **Testing → Internal testing**

Click **Create new release**.

(First time: there will be no upload yet — that's OK. We're configuring the track BEFORE the CI runs.)

In the release setup page:

- **App signing:** Click **Use Play App Signing** (recommended — Google manages the upload key + app signing key). Click **Continue**.
- **Release name:** Default is fine (e.g., `1 (1.0.0)`)
- **Release notes (Icelandic):** `Fyrsta innri prufa.`
- **Release notes (English):** `First internal test build.`

**Don't click "Save" yet — there's no APK to attach.** We'll come back here after the CI uploads the first build.

For now, just go back via breadcrumb. The track is set up; CI uploads will populate it.

### 3.2 Add internal testers

Sidebar: **Testing → Internal testing → Testers tab**

Click **Create email list**.

| Field | Value |
|-------|-------|
| List name | `Hugrún internal testers` |
| Add email addresses | Jon's email + any trusted reviewers Jon wants |

Click **Save changes**.

Back on the Internal testing page → check the box for the new list under "Internal testers" → click **Save changes**.

### 3.3 Get the opt-in URL

After saving, scroll to **How testers join your test** → copy the URL. This is what Jon (and any other testers) clicks to get the app from Play Store as soon as a build is uploaded.

Save this URL — it's how Jon installs the app on Hugrún's Android tablet.

---

## 4. Create the service account for CI deployment

This is what allows the GitHub Actions `deploy-android.yml` workflow to upload builds without anyone clicking buttons.

### 4.1 Create a Google Cloud project (if needed)

URL: **https://console.cloud.google.com/**

If a project for Hugrún already exists, select it. Otherwise:

1. Click the project dropdown at the top → **New Project**
2. Project name: `Hugrún`
3. Click **Create**
4. Wait for it to finish, then select the new project

### 4.2 Enable the Google Play Android Developer API

URL: **https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com**

Click **Enable**. Wait for it to enable (~30 seconds).

### 4.3 Create the service account

URL: **https://console.cloud.google.com/iam-admin/serviceaccounts**

Click **Create Service Account**.

| Field | Value |
|-------|-------|
| Service account name | `hugrun-play-deploy` |
| Service account ID | (auto-fills) |
| Description | `GitHub Actions deploy to Google Play` |

Click **Create and Continue**.

Grant access:
- Role 1: `Service Account User`
- Click **Continue** → **Done**

### 4.4 Create a JSON key

Find the new service account in the list → click on it → **Keys** tab → **Add Key** → **Create new key** → JSON → **Create**.

A `.json` file downloads. **This is the credential the GitHub Action needs.**

The agent should NOT read or display the contents. Just confirm the download happened and surface to Jon: "Service account JSON downloaded — please add as `PLAY_SERVICE_ACCOUNT_JSON` GitHub secret per .github/SECRETS.md."

### 4.5 Link the service account to Play Console

Now the service account exists in Cloud, but Play Console doesn't know it has permission yet.

URL: **https://play.google.com/console/u/0/developers/-/api-access** (replace `-` with the Play Console developer ID if needed; the link goes to "API access" under "Setup" in Play Console)

Or: Sidebar **Setup → API access**

Find the service account in the list (the email looks like `hugrun-play-deploy@hugrun.iam.gserviceaccount.com`).

Click **Grant access**.

Permissions to grant:
- ✅ View app information and download bulk reports
- ✅ Manage testing tracks and edit tester lists
- ✅ Release apps to testing tracks
- ✅ Release to production, exclude devices, and use Play App Signing

Apps: select **Hugrún**.

Click **Invite user** → confirm.

The service account now has permission to upload builds to internal testing on the Hugrún app.

### 4.6 Provide the JSON to GitHub

Tell Jon:
1. Open the downloaded `.json` file
2. Copy its entire contents
3. Go to https://github.com/jbbjarnason/Hugrun/settings/secrets/actions
4. Click **New repository secret**
5. Name: `PLAY_SERVICE_ACCOUNT_JSON`
6. Value: paste the JSON
7. Click **Add secret**

Also create:
- Secret name `PLAY_PACKAGE_NAME`, value `is.hugrun.app`

(See `.github/SECRETS.md` in the repo.)

---

## 5. First upload — verify the loop works

After Jon adds the secrets, the agent (or Jon) triggers the deploy workflow:

1. Go to https://github.com/jbbjarnason/Hugrun/actions/workflows/deploy-android.yml
2. Click **Run workflow** → select branch `main` → **Run workflow**
3. Wait for the run to complete (5-15 minutes)
4. The workflow uploads the AAB to Play Console internal testing track

Verify in Play Console:
- Sidebar: **Testing → Internal testing**
- Should see the new release with the build's version code
- Click **Review release** → **Start rollout to internal testing**

After ~15 minutes, the build is available for testers via the opt-in URL from §3.3.

Jon can install on Hugrún's Android tablet and verify the app actually works.

---

## 6. Production release later (out of scope for this runbook)

When Jon is ready to ship publicly (probably never — Hugrún is for one child), the path is:

1. **Closed testing** — invite-only, broader testing
2. **Open testing** — anyone with the link
3. **Production** — public Play Store listing
4. **Designed for Families review** — Google's manual review of the kids' app (can take weeks)

Each track has its own promotion path. Don't promote to Production without Jon explicitly approving — kids' apps in the Families program get extra scrutiny.

---

## 7. Hand-off summary template

When the runbook completes, the agent should write a summary like:

```
## Google Play Console Setup — Run Summary

✅ App created: Hugrún (is.hugrun.app)
✅ Content rating: Everyone / PEGI 3
✅ Target audience: 5-and-under, 6-8 (Designed for Families)
✅ Data safety: No data collected
✅ Internal testing track configured
✅ Service account created: hugrun-play-deploy@hugrun.iam.gserviceaccount.com
✅ Service account granted Play Console upload permission
⚠ Privacy policy URL: NEEDS CREATING (set during 2.11 if available, else NEEDS UPDATING)
⚠ Store listing assets: PLACEHOLDERS (icon, feature graphic — NEEDS CREATING)
⚠ Production release: NOT YET (intentional — internal testing only)

Service account JSON: downloaded to ~/Downloads/hugrun-XXXXX.json
Action required by Jon:
1. Add GitHub secret PLAY_SERVICE_ACCOUNT_JSON with the JSON contents
2. Add GitHub secret PLAY_PACKAGE_NAME = is.hugrun.app
3. Trigger deploy-android.yml manually OR push to main to trigger automatically
4. After build appears in Internal testing, click "Start rollout to internal testing"
5. Use opt-in URL [URL] to install on Hugrún's Android tablet

Outstanding items for human:
- Create privacy policy at hugrun.is/privacy (or similar)
- Create app icon 512×512 PNG
- Create feature graphic 1024×500 PNG
- Re-export screenshots at correct phone/tablet aspect ratios
```

---

## Failure modes & recovery

| Error | Likely cause | Recovery |
|-------|-------------|----------|
| "Account not approved" on Play Console | New developer account, ID verification pending | Wait — can be 24h to 14 days. Surface to Jon. |
| "Package name already in use" | Someone else registered `is.hugrun.app` | Pick alternative: `is.hugrun.kidsapp` or similar. Update PROJECT.md + Android manifest. |
| "Service account doesn't have permission" on first upload | Step 4.5 not completed correctly | Re-check API access page; permissions take ~5 min to propagate |
| "Build's version code already exists" | CI build number collision | Bump `versionCode` in `android/app/build.gradle.kts` and re-run |
| "App requires privacy policy" before release | §2.11 didn't include URL | Create a placeholder privacy policy at any URL, add in Designed for Families section |
| Browser session lost mid-runbook | Cookie expired, MFA challenge | Save progress, surface to Jon, resume from last completed section |
| "Designed for Families" rejected during review | Some declaration doesn't match implementation | Read rejection email — usually: missing privacy policy, ads SDK detected, or analytics SDK detected. Hugrún has none of these so should pass clean. |

---

## Companion runbook

iOS / TestFlight setup is in `.planning/deployment/app-store-connect-setup.md` (TODO — analogous structure).

---

*Runbook authored: 2026-05-03*
*Suitable for: browser-driving Claude agents (Claude Chrome, browser-use, Skyvern)*
*Source of truth for what to upload: `.github/workflows/deploy-android.yml` + `.github/SECRETS.md`*
