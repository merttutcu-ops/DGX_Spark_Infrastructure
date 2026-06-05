# Cluster 6 — Commerce — DGX Spark & ASUS GX10 (Canada)

*Verified 2026-06-05. Claims sourced from `docs/master-plan.md` (§1 pre-purchase). Method: two-stage adversarial verification (independent research → independent re-verification of every ✓/⚠), plus lead-level `gh api`/HF spot-checks on load-bearing claims.*

**Verdict legend:** ✓ confirmed at a primary source · ⚠ partially true / caveated / stale · ✗ contradicted by the source · ? could not verify

**Tally:** 7 findings — **2 ✓ · 3 ⚠ · 1 ✗ · 1 ?**

## Summary

After independent re-verification the report is accurate and its verdicts stand with zero verdict flips. The two checkmark factual claims are confirmed at primary sources fetched directly: the NVIDIA Developer Forums post re-fetched as JSON confirms the 3999 to 4699 US dollar Feb 2026 MSRP hike with all four sub-claims verbatim, and the TrendForce March 31 2026 release confirms the plus 58 to 63 percent QoQ 2Q26 DRAM forecast plus the no-meaningful-expansion-until-late-2027-or-2028 framing. The warn live-commerce findings are correct: I re-confirmed the only two observable CAD data points, Newegg.ca DGX Spark CA 7199 In Stock and GX10 1TB CA 7499 In Stock, plus CDW.ca In Stock with a null-sentinel price, while three of five named retailers remain bot-walled. The cross-out on the Toms Hardware 3266.53 quote is well-founded: live text says as little as 3000 dollars with a 1TB SSD, not 3266.53. Two refinements: the plan 4TB SKU 940-54242-0006-000 is actively absent from the one reachable priced CA listing which carries -0000-000, and the report verbatim quotes are in two places slight paraphrases of live wording with substance unaffected.

## Findings

| # | Verdict | Claim | Evidence (URL · date) |
|---|---|---|---|
| 6.1 | ⚠ | DGX Spark FE SKU 940-54242-0000-000 stocked at Canada Computers, Memory Express, CDW.ca, Newegg.ca, Amazon.ca; report each retailer live CAD price and availability. | [link](https://www.newegg.ca/p/N82E16883986001) · 2026-06-05 |
| 6.2 | ? | 4TB variant SKU 940-54242-0006-000 is listed in Canada. | [link](https://www.newegg.ca/p/N82E16883986001) · 2026-06-05 |
| 6.3 | ✓ | NVIDIA raised FE MSRP 3999 to 4699 US dollars on Feb 23 2026 citing memory supply; existing orders honored; no hardware changes. | [link](https://forums.developer.nvidia.com/t/2-23-2026-price-change-announcement/361713) · 2026-06-05 |
| 6.4 | ⚠ | Plan estimate CA 6300 to 6800 before tax tracks current listings plus FX. | [link](https://www.newegg.ca/p/N82E16883986001) · 2026-06-05 |
| 6.5 | ⚠ | ASUS Ascent GX10 same GB10 platform 1TB vs 2TB SSD; find live CA listings price and stock for 1TB and 2TB. | [link](https://www.newegg.ca/barebone-systems-mini-pc-arm-v9-2-a-cpu-gb10-asus-ascent-gx10/p/2SW-000N-00129) · 2026-06-05 |
| 6.6 | ✗ | Toms Hardware quote: GX10 cheaper at 3266.53 dollars with the only difference being a smaller 1TB SSD. | [link](https://www.tomshardware.com/pc-components/gpus/nvidia-dgx-spark-review/5) · 2026-06-05 |
| 6.7 | ✓ | DRAM shortage structural past 2027; DRAM contract prices forecast plus 58 to 63 percent this quarter Q2 2026. | [link](https://www.trendforce.com/presscenter/news/20260331-12995.html) · 2026-06-05 |

## Finding detail

### 6.1 · ⚠ — DGX Spark FE SKU 940-54242-0000-000 stocked at Canada Computers, Memory Express, CDW.ca, Newegg.ca, Amazon.ca; report each retailer live CAD price and availability.
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://www.newegg.ca/p/N82E16883986001 (2026-06-05)
- **Notes:** VERIFIER RE-CHECKED. Newegg.ca re-fetched HTTP 200: JSON-LD price 7199.00 CAD, availability InStock, part 940-54242-0000-000, so CA 7199.00 In Stock, matches report. CDW.ca 8370635 re-fetched: In Stock plus Sign In gating, data-priceValue 0 and data-price 79228162514264337593543950335 (.NET decimal MaxValue sentinel = no public price), confirming report. Canada Computers 279129 re-tested: curl returned no usable HTTP response, consistent with report bot-wall. Memory Express and Amazon.ca not re-attempted, claims plausible and uncontradicted. Only Newegg.ca yields a live public CAD price, 1 of 5. Warn verdict correct.

### 6.2 · ? — 4TB variant SKU 940-54242-0006-000 is listed in Canada.
- **Verdict:** ? Unverifiable
- **Evidence:** https://www.newegg.ca/p/N82E16883986001 (2026-06-05)
- **Notes:** VERIFIER CONFIRMS ? and sharpens it. The confirmed live Newegg.ca 4TB unit N82E16883986001 carries part 940-54242-0000-000 in JSON-LD, NOT -0006-000, re-verified: -0000-000 appears repeatedly and -0006-000 does not appear. The SKU the plan attributes to the 4TB variant does not appear on the one reachable priced CA listing. No distinct live CA listing carrying -0006-000 found on a lead retailer. The plan SKU mapping for the 4TB variant is unconfirmed and possibly wrong.

### 6.3 · ✓ — NVIDIA raised FE MSRP 3999 to 4699 US dollars on Feb 23 2026 citing memory supply; existing orders honored; no hardware changes.
- **Verdict:** ✓ Confirmed
- **Evidence:** https://forums.developer.nvidia.com/t/2-23-2026-price-change-announcement/361713 (2026-06-05)
- **Notes:** VERIFIER RE-CHECKED AT SOURCE, fetched thread JSON. VERBATIM: The MSRP for DGX Spark Founders Edition has been adjusted from 3999 to 4699 due to memory supply constraints; The price adjustment reflects industry wide memory supply constraints; Does this impact existing orders No. The pricing applied at the time of ordering will be honored; No. There are no hardware or configuration changes tied to this adjustment. All four sub-claims confirmed primary. DATE NUANCE: thread TITLE is 2/23/2026 Price Change Announcement equals plan Feb 23, original post created Feb 25 2026 saying The updated pricing went live this week. Report paraphrase accurate. Plan paraphrases hardware line as No hardware changes have been made; source says no hardware or configuration changes, substance identical. Holds.

### 6.4 · ⚠ — Plan estimate CA 6300 to 6800 before tax tracks current listings plus FX.
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://www.newegg.ca/p/N82E16883986001 (2026-06-05)
- **Notes:** VERIFIER RE-CHECKED. The single live CA price Newegg.ca CA 7199.00 sits about 400 to 900 ABOVE the band. MSRP plus FX check: 4699 US dollars at about 1.36 to 1.40 equals about CA 6390 to 6580 pre-tax, inside the band, so defensible as an MSRP-derived estimate but does NOT match the only observable live listing, Newegg ships from US with markup. Other retailers bot-walled. Tracks current listings only partly true. Holds.

### 6.5 · ⚠ — ASUS Ascent GX10 same GB10 platform 1TB vs 2TB SSD; find live CA listings price and stock for 1TB and 2TB.
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://www.newegg.ca/barebone-systems-mini-pc-arm-v9-2-a-cpu-gb10-asus-ascent-gx10/p/2SW-000N-00129 (2026-06-05)
- **Notes:** VERIFIER RE-CHECKED, followed 301 from short URL to canonical URL. JSON-LD price 7499.00 CAD, availability InStock, so CA 7499.00 In Stock, 1TB GX10, matches report. Report cited the pre-redirect short URL; canonical URL is in evidence_url here. Canada Computers CA 4799.99 search snippet UNVERIFIED at source, page unreachable. No distinct live 2TB CA variant found; GX10 ships 1TB by default, larger M.2 self-install, Toms: drop your own 4TB M.2 2230 SSD into the GX10. 1TB confirmed, 2TB unconfirmed. Holds.

### 6.6 · ✗ — Toms Hardware quote: GX10 cheaper at 3266.53 dollars with the only difference being a smaller 1TB SSD.
- **Verdict:** ✗ Contradicted
- **Evidence:** https://www.tomshardware.com/pc-components/gpus/nvidia-dgx-spark-review/5 (2026-06-05)
- **Notes:** VERIFIER RE-CHECKED AT SOURCE, grepped live page 5 body. Exact text: Asus Ascent GX10 version of the Nvidia GB10 platform also sells for as little as 3000 dollars with a 1TB SSD right now, and after our testing we would take the Ascent GX10 any day for a general-purpose local AI system. Page also: drop your own 4TB M.2 2230 SSD into the GX10 and keep about 700 dollars in your pocket versus the Founders Edition Spark. 3266.53 does NOT appear; the only difference being a smaller 1TB SSD absent. Plan figure and wording contradicted. Note report own quote we would recommend is a paraphrase of live we would take, does not change verdict. Substance GX10 cheaper 1TB SSD holds; quoted price and wording contradicted. Holds.

### 6.7 · ✓ — DRAM shortage structural past 2027; DRAM contract prices forecast plus 58 to 63 percent this quarter Q2 2026.
- **Verdict:** ✓ Confirmed
- **Evidence:** https://www.trendforce.com/presscenter/news/20260331-12995.html (2026-06-05)
- **Notes:** VERIFIER RE-CHECKED AT SOURCE. TrendForce release dated March 31 2026: Conventional DRAM contract prices expected to rise 58 to 63 percent QoQ in 2Q26 and NAND Flash contract prices expected to rise by 70 to 75 percent QoQ in 2Q26, plus meaningful capacity expansion unlikely until late 2027 or 2028. Past-2027 framing corroborated by a separate TrendForce piece Memory Price Rally May Run Past 2028 as Samsung SK hynix Reportedly Cautious on Expansion and multiple Dec 2025 and Feb 2026 trade outlets citing Samsung SK hynix caution and about 2.5 percent undersupply into 2027. Both the plus 58 to 63 percent Q2 figure and the past-2027 framing confirmed. Holds.

## Method notes

Read plan at /Users/merttutcu/spark-agent-infra/docs/master-plan.md. Re-verified every checkmark and warn finding independently. WebFetch confirmed the NVIDIA forum announcement, the TrendForce 2Q26 release, and the past-2027 structural DRAM framing. Bash curl with compressed and a desktop browser UA independently re-fetched Newegg.ca DGX Spark (HTTP 200, JSON-LD price 7199.00 CAD InStock, part 940-54242-0000-000), Newegg.ca GX10 (followed 301 to canonical URL, JSON-LD price 7499.00 CAD InStock), CDW.ca DGX Spark (In Stock plus Sign In plus data-price decimal-max sentinel), and re-fetched the NVIDIA forum thread JSON to extract the exact post body for verbatim verification of all four MSRP sub-claims. Grepped the live Toms Hardware review page 5 body directly to confirm the 3266.53 figure is absent and the live phrasing is as little as 3000 dollars with a 1TB SSD. Canada Computers re-tested and again returned no usable HTTP response. verifier: 0 findings adjusted; verdicts unchanged; notes refined and quotes corrected on findings 2, 3, 5, 6.
