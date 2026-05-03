# Azure Neural TTS Setup — Hugrún

**Goal:** Replace Piper Steinn with Microsoft Azure Neural TTS (`is-IS-GudrunNeural` female / `is-IS-GunnarNeural` male) for higher-quality Icelandic pronunciation. The free tier covers Hugrún's full lexicon many times over.

**Audience:** Jon (or a browser-driving Claude with Jon already signed in to Microsoft).

---

## Free tier reality check

- **Free F0 tier** = 500,000 characters/month for Neural voices
- Hugrún's full lexicon (118 utterances, ~5 chars average word + a few longer narrations) ≈ **~1,000 characters total**
- Re-baking the entire app costs ~0.2% of one month's free tier
- Even with weekly re-bakes during iteration, you'd never come close to limits
- Azure F0 tier is permanently free (no auto-conversion to paid)

**No credit card required for F0** as of 2026. (Microsoft asks for one for "Azure Free Trial" which is different — that's the $200 credit thing. Just F0 Speech is permanently free, no card.)

---

## Step 1 — Sign up for Azure (5 minutes)

URL: **https://azure.microsoft.com/free**

If you already have a Microsoft account (Outlook, Xbox, GitHub-via-Microsoft), use it. Otherwise:
1. Click **Start free** → sign in with Microsoft account or create one
2. Skip the "Free trial" if it asks for credit card — you only need F0 Speech, not Free Trial
3. Land on https://portal.azure.com/

---

## Step 2 — Create a Speech resource (3 minutes)

URL: **https://portal.azure.com/#create/Microsoft.CognitiveServicesSpeechServices**

(Or: portal.azure.com → search "Speech Services" → Create → Speech)

Fill in the form:

| Field | Value |
|-------|-------|
| Subscription | (your free subscription — usually only one option) |
| Resource group | Click **Create new** → `hugrun-tts-rg` |
| Region | Pick **West Europe** (closest to Iceland) |
| Name | `hugrun-tts` |
| Pricing tier | **Free F0** (this is the critical choice — F0 = free permanently) |

Click **Review + create** → **Create**.

Wait ~30 seconds for deployment. Click **Go to resource**.

---

## Step 3 — Get the key + region (1 minute)

On the resource page, sidebar → **Keys and Endpoint**.

Copy these two values:

| What to copy | Where it goes |
|--------------|---------------|
| **KEY 1** (32-char hex string) | GitHub secret `AZURE_TTS_KEY` |
| **Location/Region** (e.g. `westeurope`) | GitHub secret `AZURE_TTS_REGION` |

**IMPORTANT:** the key is a secret. Don't paste it into chat or commit it to git. Only paste it into the GitHub Secrets UI (or local `.env`).

---

## Step 4 — Add to GitHub secrets

URL: **https://github.com/jbbjarnason/Hugrun/settings/secrets/actions**

Click **New repository secret** twice:

1. Name: `AZURE_TTS_KEY`, Value: (paste KEY 1 from Azure)
2. Name: `AZURE_TTS_REGION`, Value: (paste region, e.g. `westeurope`)

Optional — also add as local environment for the bake pipeline:

```bash
echo "export AZURE_TTS_KEY='...'" >> ~/.zshrc
echo "export AZURE_TTS_REGION='westeurope'" >> ~/.zshrc
source ~/.zshrc
```

---

## Step 5 — Tell me you're ready

Once the secrets are in place, let me know. I'll dispatch an agent that:

1. Adds `tools/tts/azure_client.py` (REST client for Azure Speech Synthesis API)
2. Updates `tools/tts/bake_audio.py` to support `--provider azure` flag
3. Re-bakes all 118 clips with `is-IS-GudrunNeural` (female; matching the original Diljá v2 plan)
4. Re-runs spectral review to confirm quality improvement
5. Regenerates `lib/gen/audio_manifest.g.dart`
6. Tests on device, pushes

**Voice choice:** Gudrun (female warm narrator) is the recommended starting point — matches the original Diljá v2 plan in PROJECT.md. If you want to A/B with Gunnar (male), we can bake both and you pick.

**Cost:** zero. The full re-bake at 1K characters total is well under 0.5% of one month's free tier.

---

## Quotas, in case you ever ship publicly

| Tier | Neural chars/month | Cost |
|------|-------------------|------|
| F0 (free) | 500,000 | $0 |
| S0 (pay-as-you-go) | unlimited | $16 / 1M chars |

For a single-child app, F0 is permanent. Even if you ship publicly and 1,000 kids download it, the audio is *baked into the app bundle* — runtime usage is zero. The TTS API is only called at build time, by you, on your dev machine. F0 will always cover that.

---

## Troubleshooting

| Error | Likely cause | Fix |
|-------|--------------|-----|
| "Subscription not found" | Account not yet activated | Wait 5 min after signup; refresh portal |
| "401 Unauthorized" on first API call | Key not propagated yet | Wait 60 seconds; key takes a moment to activate after creation |
| "Out of region" / "Voice not available" | Picked wrong region | Some voices are region-locked; westeurope and northeurope both have all Icelandic voices |
| "Quota exceeded" on F0 | Burning through 500K/month | Implausible for Hugrún but if it happens: upgrade to S0 ($16/1M = ~$0.016 for full re-bake) |
| Double-charge concerns | Picked S0 by accident | Delete the resource, recreate as F0. Microsoft refunds inadvertent charges on free-tier accounts via support ticket |

---

*Runbook authored: 2026-05-03*
