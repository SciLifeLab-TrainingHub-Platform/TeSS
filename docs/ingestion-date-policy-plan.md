# Plan: Automatic Event Ingestion and the "No Past Events" Policy

**Status:** Draft for review
**Author:** Harshita Gupta
**Date:** 2026-08-25
**Reviewers:** Adeel, Dimitris
**First use case:** EMBL-EBI training courses
**Applies to:** every current and future content provider

---

## 1. What we are trying to do

We want to show training events from other organisations on our portal without
anyone typing them in by hand.

The organisation publishes a web address (a "feed") that lists their courses in a
machine-readable format. Our portal reads that address on a schedule, creates the
events automatically, and links them to that organisation's page.

The first organisation we want to do this for is **EMBL-EBI**. But the point of
this document is that **EMBL is just the first one**. Whatever we build has to
work for the next provider without redoing the analysis.

We also have a firm rule: **we do not want past events on the portal.** Our portal
launched in 2024 and we are only interested in courses people can still attend.

---

## 2. The words we use

Three concepts, because they are easy to mix up:

| Word | What it means |
|---|---|
| **Content Provider** | The organisation, e.g. "EMBL-EBI". Has its own page on our portal. |
| **Source** | One web address to read, attached to one Content Provider. Says *where* to look and *how* to read it. |
| **Ingestor** | The piece of code that understands a particular format. We will use the `Bioschemas` ingestor. |

So the setup is: create a **Content Provider** for EMBL, then add a **Source**
under it pointing at their feed, with the method set to **Bioschemas**.

---

## 3. How it is supposed to work

```
Content Provider "EMBL-EBI"
  └── Source (url: EBI feed, method: bioschemas, enabled, approved)
        │
        │  runs nightly at 3am (config/schedule.rb)
        ▼
      Scraper                              lib/scraper.rb
        │  picks up every approved Source
        ▼
      BioschemasIngestor.read(url)          lib/ingestors/bioschemas_ingestor.rb
        │  reads the feed, pulls out courses
        ▼
      ingestor.write(user, provider)        lib/ingestors/ingestor.rb
        │  creates the Event records
        ▼
      Events appear on the EMBL-EBI page
```

The important thing to understand: **the feed does not say which provider the
events belong to.** Our code stamps the Source's own Content Provider onto every
event it creates (`lib/ingestors/ingestor.rb:141-143`). So the events show up
under whichever provider you attached the Source to.

**Good news:** all of the above already exists and works. We inherited it from
upstream TeSS. We are not building an ingestion system from scratch.

---

## 4. Why it does not work today

Here is the honest position. We have never run an ingestor on this portal. When
we tried the EMBL feed, the result would be:

> read 564 events, created **0** events.

There are four reasons, and all four are things **we** added to the code over
the past two years. Upstream TeSS does not have any of them.

### 4.1 We made a lot of fields compulsory

`app/models/event.rb:182` says an event cannot be created unless it has:

`language`, `prerequisites`, `target_audience`, `content_providers`,
`learning_objectives`, `start`, `end`

That is a good rule for a human filling in our web form. But a feed from another
organisation will almost never have `prerequisites` or `learning_objectives` —
those are things a person writes, not things a system publishes.

### 4.2 We made a price compulsory

`app/models/event.rb:185` says every event needs at least one price row. This was
added in PR #424 (separate academic / non-academic fees). No ingestor anywhere in
the codebase creates price rows, so this rule alone blocks 100% of ingestion.

### 4.3 We added an approval workflow

Scraped events are created by a special "scraper" user, which is not a trusted
user. So every event is created as `awaiting_review` and stays invisible to the
public until a curator approves it. On top of that, every single created event
sends two emails (one to admins, one to the submitting user). 564 events would
mean about **1,128 emails in one night**.

### 4.4 Nobody would have noticed

Every one of the 34 ingestor test files starts with
`skip 'Skipping all the ingestors tests'`. So the tests that would have caught
4.1 and 4.2 have not run since they were added.

### Why this happened

None of this was careless. Each change was correct for the feature it shipped
with. The gap is that **ingestion is upstream code and our changes were to our
own model**, so nothing connected the two. This document is the connection.

---

## 5. About past events — the surprise

We assumed we would need to write code to hide past events. **We do not.**

`lib/facets.rb:90-92` already hides finished events from every search and listing
on the portal unless someone explicitly asks to see them. The provider page shows
only upcoming events in its main tab. Past events are reachable only through a
deliberate "include expired" link.

So if we imported all 564 EMBL events tomorrow, a normal visitor would see the 18
upcoming ones and nothing else. **The display requirement is already met.**

### So why filter at all?

Because past events still cost us, just not visually:

- **546 events sitting in the curation queue** that nobody will ever action
- **~1,092 pointless emails** on the first run
- Search index bloat, slower reindexing
- Anyone browsing the database or admin panel sees years of clutter

This is a housekeeping problem, not a bug the public can see. That matters for
prioritisation: **we are not racing a visible defect.**

---

## 6. The fix, designed once for everyone

### Where the filter goes

Inside `Ingestor#write_resources` (`lib/ingestors/ingestor.rb:137`).

Every single ingestor — all 30 of them, plus every future one — passes through
that one method. Put the rule there and the next provider inherits it for free
with no extra work.

### Options we considered and rejected

| Option | Why not |
|---|---|
| Put it in the Bioschemas ingestor | Fixes EMBL only. The next provider re-opens this ticket. |
| Put it in `add_event` | Works, but then the log claims the feed had 18 records when it had 564. We lose the ability to see what the provider actually published. |
| Filter only on the display side | Already done. Does not fix the curation queue or the emails. |
| Delete past events afterwards with a cleanup job | The events still get created, still send emails, still need approval. Deleting what should never have been written. |

### The setting

Goes in `config/tess.yml`, with a default in `config/tess.example.yml`:

```yaml
ingestion_policy:
  # Skip events that have already finished. Applies to every ingestor.
  skip_finished_events: true
  # Also accept events that finished within this many days.
  finished_grace_period_days: 0
```

**Why `tess.yml` and not `ingestion.yml`?** `ingestion.yml` is copied from an
example file per environment, so it quietly drifts between dev, preprod and prod,
and comes back empty if the file is missing. `tess.yml` is tracked in git and
built into the image, so the policy is versioned and identical everywhere.

### Four details that are easy to get wrong

1. **Count what we skipped.** Add a `skipped` counter alongside the existing
   processed / added / updated / rejected counters, so the source log reads
   *"read 564, skipped 546, added 18"*. Without this, a filter bug looks
   identical to an empty feed. **No database migration needed** — the count lives
   in the log text, not a new column.

2. **Fall back to the start date.** At the moment we apply the filter, the event
   has not been saved yet, so the code that fills in a missing end time has not
   run. Use the end date if present, otherwise the start date.

3. **Read the value with brackets.** These records are `OpenStruct` objects, and
   `end` is a Ruby keyword. Use `resource[:end]`, not `resource.end`.

4. **Fail open.** If a date is missing or cannot be understood, **do not skip the
   event.** Let the normal validation rules decide. We must never silently throw
   away data we did not understand.

### One tradeoff to accept knowingly

An event that we import while it is still upcoming, which later finishes, will
stop receiving updates on later runs. That is fine — it is history at that point.
But it should be written down rather than discovered later.

---

## 7. The work, in phases

### Phase 0 — Check our assumptions in the Rails console (no code)

Read-only. Nothing is saved, no emails are sent. Details in section 9.

### Phase 1 — Make ingestion able to create events at all

- Add `unless: :scraper_record` to `app/models/event.rb:182` and `:185`
- Un-skip `test/unit/ingestors/bioschemas_ingestor_test.rb:5`

`scraper_record` is a flag set only by the ingestion code
(`lib/ingestors/ingestor.rb:123`). The web form never sets it, so **human
submissions keep all the strict rules**. This is the key safety property.

Already checked: nothing in the app assumes an event has a price. The helper at
`app/helpers/events_helper.rb:151` already handles the empty case, the JSON
output just lists whatever is there, and the form handles zero rows.

### Phase 2 — The date policy

- Add `ingestion_policy` to `tess.yml` and `tess.example.yml`
- Add the filter and the `skipped` counter to `Ingestor`
- Tests: finished event skipped; upcoming kept; missing end date falls back to
  start; unreadable date is kept, not dropped; policy switched off means no
  filtering at all

### Phase 3 — Switch on EMBL

- Set `feature.sources: true` in `config/tess.yml:70`
- Create the EMBL Content Provider and its Source, but leave it **disabled**
- Use the **Test** button for a dry run and read the log
- Enable it, and leave events as `awaiting_review` for the first real run so a
  human sees the 18 events before they go public

Note: `tess.yml` is built into the container image, so this ships with a deploy
rather than being a switch we can flip live. **To confirm with Adeel:** does the
cluster mount a ConfigMap over `tess.yml`? If so, this becomes a live change.

### Phase 4 — A second provider

The real test of whether we generalised properly. If provider #2 needs only a
Content Provider and a Source and no code, we succeeded.

### Prerequisite

The `rc-1.6.1` lint gate is currently failing, which means the build step is
skipped and **nothing deploys**. That has to be fixed before Phase 1 can ship.
Phase 0 is unaffected.

---

## 8. Decisions we need to agree on

1. **Do scraped events go live automatically, or wait for a curator?**
   Making the scraper user "trusted" would fix both the invisibility and the
   email volume in one move, but it skips curation entirely. With the Phase 2
   filter in place the email count drops from ~1,128 to ~36, which makes keeping
   curation much more affordable. **Recommendation: keep curation on.**

2. **Grace period value.** Recommendation: ship `0`, revisit if anyone asks.

3. **Global setting, or per-Source?** We could add a column so one Source could
   import history while others do not. **Recommendation: keep it global for now**
   and add the column when a real need turns up.

---

## 9. Phase 0: the console session, step by step

Run these one at a time on **dev**. Everything here only reads — nothing is
written to the database and no emails are sent.

**Step 1 — does the feed parse, and how much is in it?**

```ruby
i = Ingestors::BioschemasIngestor.new
i.read('https://www.ebi.ac.uk/api/v1/ebi-training-courses-tess?source=trainingcontenthub')
[i.events.count, i.materials.count]
```

Expected: `[564, 0]`. Proves the feed is readable and that duplicate handling
worked (the feed has 564 courses, each with one session).

**Step 2 — which fields actually survive the reading?**

```ruby
i.events.first.to_h.keys.sort
i.events.first.to_h.slice(:title, :url, :start, :end, :target_audience,
                          :language, :prerequisites, :learning_objectives)
```

Expected: title, url, start, end and target_audience filled in; language,
prerequisites and learning_objectives empty. This is the one part of the analysis
taken from a test that is currently skipped, so it is the most valuable thing to
verify by hand.

**Step 3 — prove the four blockers, without saving anything**

```ruby
e = Event.new(i.events.first.to_h)
e.content_providers << ContentProvider.first
e.valid?
e.errors.full_messages
```

Expected: `false`, and four complaints — language, prerequisites, learning
objectives, and "At least one price must be present". This is the evidence for
Phase 1.

**Step 4 — how many events survive the proposed date filter?**

```ruby
i.events.count { |ev|
  d = ev[:end] || ev[:start]
  d.present? && (Time.zone.parse(d.to_s) rescue nil)&.>=(Time.zone.now)
}
```

Expected: 18. Confirms the filter logic before we write it.

**Step 5 — confirm Phase 1 is enough**

```ruby
e.scraper_record = true
e.valid?
```

Expected: still `false` today. After Phase 1 this becomes `true`. This is the
before-picture our new tests will assert against.

---

## 10. What to do about next week

The scraper work is worth doing properly and should not be rushed to hit a
content deadline. Phase 1 and Phase 2 need two PRs, review, a build and a deploy,
and the lint gate has to be fixed first.

For the immediate need, **add the events by hand**. Only **7 of the 18 upcoming
EMBL courses start in 2026**:

| Start | Course |
|---|---|
| 2026-09-09 | Bringing structural biology to AI: exploring the PDBe MCP server |
| 2026-09-10 | Small molecules and their protein targets |
| 2026-10-04 | Causality in biomedicine: going beyond associations |
| 2026-10-07 | ProtVista hackathon |
| 2026-10-19 | Structural bioinformatics |
| 2026-11-16 | Genome bioinformatics: from short- to long-read sequencing |
| 2026-11-26 | Interpreting the effects of genetic variants on protein structure |

Those seven cover us to the end of the year. The other eleven are 2027 and can
wait for the scraper.

### One important instruction for whoever enters them

**Use the exact EBI event URL**, e.g.
`https://www.ebi.ac.uk/training/events/structural-bioinformatics-2026`.

The reason: when the scraper goes live it matches existing events by URL within
the same content provider (`app/models/event.rb:364-390`). If the URL matches, it
**updates** the event we typed in rather than creating a duplicate. If someone
types a different URL, we get two copies of every event.

Also worth knowing: the scraper respects locked fields
(`lib/ingestors/ingestor.rb:184-192`), so anything a curator locks will survive
future automatic updates.

---

## 11. Note on upstream

Phase 1 is repaying our own debt — validations we added without updating the
inherited ingestion code. It is specific to our fork.

Phase 2 is a genuine improvement that upstream TeSS does not have. Their
`lib/ingestors/oscm_ingestor.rb:31` carries a comment about past events cluttering
a feed, so they have the same problem with no solution. **This is a good
candidate to contribute back**, which is why Phase 1 and Phase 2 should be
separate PRs.

---

## 12. Risks

| Risk | How we handle it |
|---|---|
| Relaxed rules let thin events through the web form too | `scraper_record` is only set by ingestion code; the form never sets it |
| The filter silently drops events we wanted | Fail open on unreadable dates, plus the `skipped` count in every log |
| First run floods the mail queue | Source stays disabled until a dry run is reviewed; the filter cuts volume ~30x |
| Need to back it out | Set `skip_finished_events: false`, or revert the PR |
