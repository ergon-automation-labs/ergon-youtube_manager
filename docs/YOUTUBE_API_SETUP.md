# YouTube Analytics API Setup

This guide walks through creating credentials for the YouTube Manager Bot to fetch channel analytics.

⚠️ **Important:** Service accounts do NOT work with YouTube Analytics API (Google prevents linking service accounts to YouTube channels). Use **OAuth 2.0** instead.

---

## Recommended: OAuth 2.0 (Server-Side Web App Flow)

OAuth 2.0 is the only supported method for YouTube Analytics API. The server-side flow is ideal for bots: it requires one-time user consent, then runs fully automated with a refresh token.

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

Also enable **YouTube Data API v3**:
1. Search for `YouTube Data API v3`
2. Click **ENABLE**

### Step 3: Create OAuth 2.0 Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS**
3. Select **OAuth client ID**
4. First time? Click "Configure OAuth consent screen"
   - User type: **External** (unless you have a Google Workspace)
   - App name: `YouTube Manager Bot`
   - User support email: your email
   - Developer contact: your email
   - Click **SAVE AND CONTINUE**
   - Scopes: Click **ADD OR REMOVE SCOPES**
     - Search and add: `https://www.googleapis.com/auth/yt-analytics.readonly`
     - Also add: `https://www.googleapis.com/auth/youtube.readonly`
     - Click **UPDATE**
   - Click **SAVE AND CONTINUE** → **BACK TO DASHBOARD**

5. Now create the OAuth client:
   - Go back to **APIs & Services** → **Credentials**
   - Click **+ CREATE CREDENTIALS** → **OAuth client ID**
   - Application type: **Web application**
   - Name: `YouTube Manager Bot`
   - Authorized JavaScript origins: `http://localhost:8080` (for local dev)
   - Authorized redirect URIs: `http://localhost:8080/oauth/callback`
   - Click **CREATE**

6. A dialog shows your **Client ID** and **Client Secret**
   - Copy both (you'll need them)
   - Click **DOWNLOAD JSON** to save the full credentials file

### Step 4: Store OAuth Credentials

#### For Local Development

1. Save the downloaded JSON file to a secure location:
   ```bash
   cp ~/Downloads/client_secret_*.json ~/.bot_army/youtube_oauth.json
   chmod 600 ~/.bot_army/youtube_oauth.json
   ```

2. Add to your shell profile (`~/.zshrc` or `~/.bashrc`):
   ```bash
   export YOUTUBE_OAUTH_CLIENT_ID="<client_id_from_json>"
   export YOUTUBE_OAUTH_CLIENT_SECRET="<client_secret_from_json>"
   ```

3. Reload shell:
   ```bash
   source ~/.zshrc
   ```

#### For Production (Salt/Kubernetes)

Store credentials in the node-specific secrets file (e.g., `pillar/air-secrets.sls`):

```yaml
youtube_manager:
  oauth_client_id: "xxxxx.apps.googleusercontent.com"
  oauth_client_secret: "xxxx_xxxx_xxxx"
  oauth_refresh_token: "stored_after_initial_auth"
```

Then reference in bot environment:
```elixir
# config/runtime.exs
config :bot_army_youtube_manager,
  oauth_client_id: System.get_env("YOUTUBE_OAUTH_CLIENT_ID"),
  oauth_client_secret: System.get_env("YOUTUBE_OAUTH_CLIENT_SECRET"),
  oauth_refresh_token: System.get_env("YOUTUBE_OAUTH_REFRESH_TOKEN")
```

### Step 5: Initial User Authorization (One-Time)

The bot needs you to authorize it once to access your YouTube Analytics:

```bash
cd /Users/abby/code/bots/bot_army_youtube_manager
iex -S mix

# In iex, start the OAuth flow:
BotArmyYoutubeManager.Youtube.OAuth.get_authorization_url()

# This prints a URL. Open it in your browser, click "Allow"
# You'll be redirected to localhost:8080/oauth/callback?code=...
# Copy the code from the URL

# Exchange code for tokens:
BotArmyYoutubeManager.Youtube.OAuth.exchange_code_for_token("paste_code_here")

# This prints tokens. Add to your environment:
# YOUTUBE_OAUTH_REFRESH_TOKEN=<refresh_token>
# YOUTUBE_OAUTH_ACCESS_TOKEN=<access_token>
```

After this one-time setup, the bot automatically refreshes tokens as needed.

### Step 6: Verify Credentials

Test the credentials locally:

```bash
cd /Users/abby/code/bots/bot_army_youtube_manager
mix test
```

Expected: All tests pass, API client can call YouTube Analytics endpoints.

Or make a manual test request:

```bash
iex -S mix

# Test the API client
BotArmyYoutubeManager.Youtube.ApiClient.fetch_channel_metrics()
```

---

## Not Recommended: Service Account

⚠️ **Service accounts do NOT work with YouTube Analytics API.** Google explicitly prevents linking service accounts to YouTube channels. You cannot use a service account for this project.

If you need to understand why: Service accounts are designed for server-to-server communication without user involvement. YouTube Analytics API requires an associated YouTube channel, and service accounts cannot be linked to channels. Use OAuth 2.0 instead.

---

## Troubleshooting

### "Authorization failed" error
- Make sure you completed the one-time authorization flow (Step 5)
- Check that `YOUTUBE_OAUTH_REFRESH_TOKEN` is set in your environment
- Verify `YOUTUBE_OAUTH_CLIENT_ID` and `YOUTUBE_OAUTH_CLIENT_SECRET` are correct

### "API not enabled" error
- Go to **APIs & Services** → **Library**
- Search "YouTube Analytics" and "YouTube Data API v3"
- Click **ENABLE** on both

### "Invalid scope" error
- Go to **APIs & Services** → **OAuth consent screen**
- Make sure `https://www.googleapis.com/auth/yt-analytics.readonly` is in the scopes list
- Scopes are case-sensitive

### Rate limiting
- YouTube Analytics API has quotas: 2 million requests/day per project
- The bot polls daily, so you're using ~1 request/day (well under limit)

---

## What's Next

Once OAuth credentials are set up and the initial authorization is complete:

1. Test with `mix test`
2. Real API calls in `Youtube.ApiClient` are now active
3. PostgreSQL will store daily metrics
4. Wire up the analytics collector to fetch real data

**Estimated time to wire credentials:** 20 minutes (most time is clicking through Google Cloud UI + one-time browser authorization)
