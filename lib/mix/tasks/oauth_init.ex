defmodule Mix.Tasks.OauthInit do
  @moduledoc """
  Initialize YouTube OAuth 2.0 credentials.

  This task guides you through the initial authorization flow to get
  refresh_token and access_token for deployment.

  Usage:
    mix oauth_init CLIENT_ID=<your_client_id> CLIENT_SECRET=<your_client_secret>

  Steps:
    1. Opens authorization URL in your browser (manual step)
    2. You click "Allow" and get redirected with ?code=...
    3. Paste the code back here
    4. Task exchanges code for tokens
    5. Copy tokens to pillar/air-secrets.sls

  The refresh_token is permanent and used for token auto-refresh at runtime.
  The access_token expires ~1 hour and is auto-refreshed by the bot.
  """

  use Mix.Task
  require Logger

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [client_id: :string, client_secret: :string])

    client_id = Keyword.get(opts, :client_id) || System.get_env("YOUTUBE_OAUTH_CLIENT_ID")

    client_secret =
      Keyword.get(opts, :client_secret) || System.get_env("YOUTUBE_OAUTH_CLIENT_SECRET")

    unless client_id && client_secret do
      IO.puts(:stderr, "ERROR: Missing OAuth credentials")
      IO.puts(:stderr, "")
      IO.puts(:stderr, "Usage: mix oauth_init CLIENT_ID=<id> CLIENT_SECRET=<secret>")
      IO.puts(:stderr, "")
      IO.puts(:stderr, "Or set environment variables:")
      IO.puts(:stderr, "  export YOUTUBE_OAUTH_CLIENT_ID=<id>")
      IO.puts(:stderr, "  export YOUTUBE_OAUTH_CLIENT_SECRET=<secret>")
      IO.puts(:stderr, "  mix oauth_init")
      exit(1)
    end

    # Set env vars for OAuth module
    System.put_env("YOUTUBE_OAUTH_CLIENT_ID", client_id)
    System.put_env("YOUTUBE_OAUTH_CLIENT_SECRET", client_secret)

    # Start the app to load config
    {:ok, _} = Application.ensure_all_started(:bot_army_youtube_manager)

    IO.puts("")
    IO.puts("=" |> String.duplicate(70))
    IO.puts("YouTube Manager Bot - OAuth 2.0 Initial Authorization")
    IO.puts("=" |> String.duplicate(70))
    IO.puts("")

    # Step 1: Get authorization URL
    IO.puts("Step 1: Opening authorization URL in your browser...")
    IO.puts("")

    case BotArmyYoutubeManager.Youtube.OAuth.get_authorization_url() do
      {:ok, auth_url} ->
        IO.puts("Authorization URL:")
        IO.puts(auth_url)
        IO.puts("")
        IO.puts("Opening in browser (if available)...")
        System.cmd("open", [auth_url])
        IO.puts("")

      {:error, reason} ->
        IO.puts(:stderr, "ERROR: Failed to generate auth URL: #{reason}")
        exit(1)
    end

    # Step 2: Get code from user
    IO.puts("Step 2: After authorizing, you'll be redirected to:")
    IO.puts("  http://localhost:8080/oauth/callback?code=...")
    IO.puts("")
    code = IO.gets("Paste the code from the URL: ") |> String.trim()

    unless String.length(code) > 0 do
      IO.puts(:stderr, "ERROR: No code provided")
      exit(1)
    end

    # Step 3: Exchange code for tokens
    IO.puts("")
    IO.puts("Step 3: Exchanging code for tokens...")

    case BotArmyYoutubeManager.Youtube.OAuth.exchange_code_for_token(code) do
      {:ok, tokens} ->
        refresh_token = Map.get(tokens, "refresh_token")
        access_token = Map.get(tokens, "access_token")
        expires_in = Map.get(tokens, "expires_in", "~3600 seconds")

        IO.puts("")
        IO.puts("=" |> String.duplicate(70))
        IO.puts("SUCCESS! Tokens obtained:")
        IO.puts("=" |> String.duplicate(70))
        IO.puts("")

        IO.puts("Access Token (expires in #{expires_in}s):")
        IO.puts(access_token)
        IO.puts("")

        IO.puts("Refresh Token (permanent, use for auto-refresh):")
        IO.puts(refresh_token)
        IO.puts("")

        IO.puts("=" |> String.duplicate(70))
        IO.puts("Step 4: Add to bot_army_infra/pillar/air-secrets.sls:")
        IO.puts("=" |> String.duplicate(70))
        IO.puts("")

        IO.puts("youtube_manager:")
        IO.puts("  oauth_client_id: \"#{client_id}\"")
        IO.puts("  oauth_client_secret: \"#{client_secret}\"")
        IO.puts("  oauth_refresh_token: \"#{refresh_token}\"")
        IO.puts("  oauth_access_token: \"#{access_token}\"")
        IO.puts("")

        IO.puts("=" |> String.duplicate(70))
        IO.puts("Next: Deploy via Salt")
        IO.puts("=" |> String.duplicate(70))
        IO.puts("")
        IO.puts("  1. Update pillar/air-secrets.sls with tokens above")
        IO.puts("  2. Run: cd bot_army_infra && make deploy-bot BOT=youtube_manager")

        IO.puts(
          "  3. Verify: nats request --server nats://localhost:4222 youtube.analytics.fetch '{}' --timeout 5s"
        )

        IO.puts("")

      {:error, reason} ->
        IO.puts(:stderr, "")
        IO.puts(:stderr, "ERROR: Failed to exchange code for tokens:")
        IO.puts(:stderr, "  #{reason}")
        IO.puts(:stderr, "")
        IO.puts(:stderr, "Troubleshooting:")
        IO.puts(:stderr, "  - Check that the code is correct (copy from URL)")
        IO.puts(:stderr, "  - Verify CLIENT_ID and CLIENT_SECRET are correct")
        IO.puts(:stderr, "  - Ensure redirect URI matches Google Console config")
        exit(1)
    end
  end
end
