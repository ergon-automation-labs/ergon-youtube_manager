# YouTube Manager Bot

YouTube channel analytics, performance tracking, and content insights.

## Overview

The YouTube Manager Bot collects YouTube Analytics API data, generates weekly performance summaries, detects anomalies, and makes content recommendations. It integrates with GTD for task creation and Discord for notifications.

## Capabilities (Phase 1)

### 1. Analytics Collection (`youtube.analytics.fetch`)
- Fetches daily/weekly metrics from YouTube Analytics API
- Tracks: views, watch time, CTR, engagement (likes, comments, shares)
- Stores snapshots for trend analysis
- Publishes `youtube.analytics.updated` on success

### 2. Weekly Summaries (`youtube.summary.generate`)
- Analyzes collected metrics for a date range
- Generates markdown summary with:
  - Videos published (with performance)
  - Trends and patterns
  - Traffic source breakdown
  - Engagement analysis
- Publishes `youtube.insights.generated`

### 3. Anomaly Detection
- Monitors for sudden view drops/spikes
- Detects engagement mismatches (high engagement, low reach)
- Watches subscriber churn
- Publishes alerts to `youtube.alert.performance`

## NATS Subjects

**Request/Reply:**
- `youtube.analytics.fetch` — Trigger analytics collection
- `youtube.summary.generate` — Generate weekly summary

**Published Events:**
- `youtube.analytics.updated` — Analytics data refreshed
- `youtube.insights.generated` — Insights/recommendations ready
- `youtube.alert.performance` — Anomalies detected

## Configuration

### Environment Variables

```bash
YOUTUBE_API_KEY=<YouTube Analytics API key or OAuth token>
```

In development/test, the API client returns mock data for testing.

## File Structure

```
lib/bot_army_youtube_manager/
├── youtube/
│   └── api_client.ex              # YouTube Analytics API client
├── handlers/
│   ├── analytics_handler.ex        # Analytics collection
│   └── summary_handler.ex          # Weekly summary generation
├── nats/
│   └── consumer.ex                 # NATS subscriber/responder
├── application.ex                  # OTP application supervisor
└── ...
```

## Testing

```bash
# Run all tests
mix test

# Run only handler tests
mix test --only handlers

# Run with integration tests (when available)
mix test --include integration
```

## Phase 2: Real Analytics & Storage

**Setup:**
- [ ] **Get YouTube API Credentials** — Follow [docs/YOUTUBE_API_SETUP.md](docs/YOUTUBE_API_SETUP.md) (recommended: service account)
- [ ] **Test credentials locally** — `mix test`, verify API client can authenticate

**Implementation:**
- [ ] Create Ecto schema: `VideoMetric` table (date, views, watch_time, ctr, engagement JSON, traffic JSON)
- [ ] Implement real YouTube Analytics API calls in `Youtube.ApiClient`
- [ ] Store daily metrics in PostgreSQL (upsert by video_id + date)
- [ ] Generate summaries from stored metrics (not mock data)
- [ ] Publish `youtube.insights.generated` → para bot listens and writes PARA files

**Testing:**
- [ ] Integration test hitting real YouTube API (with `@tag :integration`)
- [ ] Verify metrics stored correctly in PostgreSQL

## Phase 3+

- [ ] Para bot integration (listen for `youtube.insights.generated`)
- [ ] Create GTD task creation from recommendations (bridge.task.create)
- [ ] Wire Discord notification integration (bridge.discord.message.send)
- [ ] Anomaly detection logic (view drops, spikes, engagement mismatches)
- [ ] Add forecasting model for content performance
- [ ] Generalize patterns for social media template (LinkedIn, etc.)

## References

- Design spec: `/Users/abby/Documents/personal_os/projects/Bot Army/YouTube Social Media Manager Bot/DESIGN_SPEC.md`
- Social media operations north star: `docs/north_star_docs/SOCIAL_MEDIA_OPERATIONS_NORTH_STAR.md`
- YouTube devlog spec: `docs/north_star_docs/YOUTUBE_DEVLOG_NORTH_STAR.md`
