# YouTube Analytics API Setup

This guide walks through creating credentials for the YouTube Manager Bot to fetch channel analytics.

## Option A: Service Account (Recommended for Bots)

Service accounts are ideal for automated bots—they don't require user interaction and don't expire.

### Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the project dropdown at the top
3. Click "NEW PROJECT"
4. Name: `bot-army-youtube` (or similar)
5. Click "CREATE"
6. Wait for the project to be created, then select it

### Step 2: Enable YouTube Analytics API

1. In the Cloud Console, go to **APIs & Services** → **Library**
2. Search for `YouTube Analytics API`
3. Click on it
4. Click **ENABLE**
5. You'll see "API enabled" message

### Step 3: Create Service Account

1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS**
3. Select **Service Account**
4. Fill in:
   - Service account name: `youtube-manager-bot`
   - Service account ID: (auto-filled, leave it)
   - Description: `YouTube Analytics collector for bot-army`
5. Click **CREATE AND CONTINUE**
6. Grant roles (optional but recommended):
   - Role: `Basic` → `Viewer` (read-only access)
   - Click **CONTINUE**
7. Click **DONE**

### Step 4: Create and Download Key

1. Go to **APIs & Services** → **Credentials**
2. Under **Service Accounts**, click the service account you just created
3. Go to the **KEYS** tab
4. Click **ADD KEY** → **Create new key**
5. Choose **JSON** format
6. Click **CREATE**
7. A JSON file downloads automatically—**save this securely**

### Step 5: Link Service Account to YouTube Channel

The service account needs access to your YouTube channel's analytics:

1. Open the downloaded JSON key file
2. Find the `client_email` field (looks like: `youtube-manager-bot@...iam.gserviceaccount.com`)
3. Go to [YouTube Studio](https://studio.youtube.com/)
4. Click the **Settings** icon (gear) → **Account**
5. Go to **Advanced Settings**
6. Under "Channel Permissions", click **ADD** next to "Users and permissions"
7. Paste the service account email
8. Grant **Manager** or **Editor** role (needs permission to access analytics)
9. Click **INVITE**

### Step 6: Store Credentials in Bot Environment

#### For Local Development

1. Copy the JSON key to a secure location:
   ```bash
   cp ~/Downloads/youtube-manager-bot-*.json ~/.bot_army/youtube_api_key.json
   chmod 600 ~/.bot_army/youtube_api_key.json
   ```

2. Add to your shell profile (`~/.zshrc` or `~/.bashrc`):
   ```bash
   export YOUTUBE_API_KEY="$(cat ~/.bot_army/youtube_api_key.json)"
   ```

3. Reload shell:
   ```bash
   source ~/.zshrc
   ```

#### For Production (Salt/Kubernetes)

Store the JSON key in the node-specific secrets file (e.g., `pillar/air-secrets.sls`):

```yaml
youtube_manager:
  api_key: |
    {
      "type": "service_account",
      ...full JSON key contents...
    }
```

Then reference in bot environment:
```elixir
# config/runtime.exs
config :bot_army_youtube_manager,
  youtube_api_key: System.get_env("YOUTUBE_API_KEY")
```

### Step 7: Verify Credentials

Test the credentials locally:

```bash
# Run the YouTube API test
cd /Users/abby/code/bots/bot_army_youtube_manager
mix test --only youtube
```

Or make a manual test request:

```bash
# Start an iex session
iex -S mix

# Test the API client
BotArmyYoutubeManager.Youtube.ApiClient.fetch_channel_metrics()
```

Expected output:
```elixir
{:ok, %{channel_id: nil, total_views: 0, total_watch_time: 0, videos: [], subscriber_change: 0}}
```

---

## Option B: OAuth2 User Credentials

Use this if you want per-user access (e.g., CLI tool that asks user to authenticate).

### Step 1-2: Same as Service Account

Create project and enable YouTube Analytics API (same steps above).

### Step 3: Create OAuth2 Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS**
3. Select **OAuth client ID**
4. Application type: **Desktop application**
5. Name: `YouTube Manager Bot`
6. Click **CREATE**
7. Download the credentials JSON

### Step 4: Store and Use

Store the JSON file in your bot config directory, then use the `oauth2` library to handle the flow:

```elixir
# In your bot
{:ok, token} = OAuth2.Client.get_token(client, code: auth_code)
```

This requires user interaction to authorize (not ideal for unattended bots).

---

## Troubleshooting

### "API not enabled" error
- Go to **APIs & Services** → **Library**
- Search "YouTube Analytics"
- Click **ENABLE**

### "Permission denied" when accessing channel
- The service account doesn't have access to your YouTube channel
- Go to YouTube Studio → Settings → Advanced Settings → Users and permissions
- Make sure the service account email is listed with Manager role

### "Invalid credentials" error
- Check that `YOUTUBE_API_KEY` environment variable is set
- Verify the JSON key file is valid (it's JSON, not a string)
- Check file permissions: `chmod 600 ~/.bot_army/youtube_api_key.json`

### Rate limiting
- YouTube Analytics API has quotas: 2 million requests/day per project
- The bot polls daily, so you're using ~1 request/day (well under limit)

---

## What's Next

Once credentials are set up:

1. Test with `mix test`
2. Implement real API calls in `Youtube.ApiClient`
3. Create PostgreSQL schema for storing metrics
4. Wire up the analytics collector to fetch real data

**Estimated time to wire credentials:** 15 minutes (most time is clicking through Google Cloud UI)
