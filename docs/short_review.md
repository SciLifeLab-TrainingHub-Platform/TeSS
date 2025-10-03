# PR Architecture Review Notes

## Summary
- Updated architecture documentation to align with actual ingestion, search, background processing, and integration behaviour.
- Highlighted discrepancies discovered during review and how they were resolved.

## Overview

We now provide two complementary documents:

1. `docs/architecture-diagram.md` – concise, high-level overview (kept close to the original author’s intent, but with factual corrections).
2. `docs/architecture-deep-dive.md` – new companion guide capturing operational detail (scheduled jobs, LLM usage, model concerns, troubleshooting).

Both files cross-reference each other so readers can choose the level of depth they need.


## Findings Addressed
1. Documented that automated ingestion is orchestrated by cron and the `Scraper` service, rather than Sidekiq jobs directly hitting external APIs.
2. Corrected Sidekiq queue listings to match `config/sidekiq.yml`.
3. Clarified Redis usage (geocoding cache, Source testing, Fairsharing tokens, ActionCable) and removed fragment cache claim.
4. Added Devise, OmniAuth LS-Login, token auth, and Pundit to authentication/authorization description.
5. Noted external integrations omitted previously: Nominatim, BioPortal, Slack notifications, FAIRsharing search, LLM post-processing, MaxMind GeoIP.
6. Explained autocomplete suggestions being stored in the database via `AutocompleteSuggestion` records, not Solr.

## Follow-up Suggestions
- Ensure future architecture updates cross-check against live configuration (Sidekiq queues, cron schedule) before drafting diagrams.
- Consider a high-level sequence diagram for the Scraper ingestion workflow to complement the data-flow view.
- Keep an integrations table in docs so additions like LLMs or notification channels are easy to surface.
