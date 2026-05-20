defmodule BotArmyYoutubeManager.Youtube.OAuth do
  @moduledoc """
  OAuth 2.0 authentication for YouTube Analytics API.

  Handles the server-side web app flow:
  1. Generate authorization URL (user clicks to authorize)
  2. Exchange auth code for access + refresh tokens
  3. Refresh access token when expired
  """

  require Logger

  @auth_endpoint "https://accounts.google.com/o/oauth2/v2/auth"
  @token_endpoint "https://oauth2.googleapis.com/token"
  @revoke_endpoint "https://oauth2.googleapis.com/revoke"

  @scopes [
    "https://www.googleapis.com/auth/yt-analytics.readonly",
    "https://www.googleapis.com/auth/youtube.readonly"
  ]

  @spec get_authorization_url() :: {:ok, String.t()} | {:error, String.t()}
  def get_authorization_url do
    client_id = Application.get_env(:bot_army_youtube_manager, :oauth_client_id)

    if client_id do
      url =
        "#{@auth_endpoint}?" <>
          URI.encode_query(%{
            client_id: client_id,
            redirect_uri: redirect_uri(),
            response_type: "code",
            scope: Enum.join(@scopes, " "),
            access_type: "offline",
            prompt: "consent"
          })

      {:ok, url}
    else
      {:error, "YOUTUBE_OAUTH_CLIENT_ID not configured"}
    end
  end

  @spec exchange_code_for_token(String.t()) :: {:ok, map()} | {:error, String.t()}
  def exchange_code_for_token(code) do
    client_id = Application.get_env(:bot_army_youtube_manager, :oauth_client_id)
    client_secret = Application.get_env(:bot_army_youtube_manager, :oauth_client_secret)

    if client_id && client_secret do
      body = %{
        code: code,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri(),
        grant_type: "authorization_code"
      }

      case post_token_request(body) do
        {:ok, tokens} ->
          Logger.info("OAuth exchange successful")
          {:ok, tokens}

        {:error, reason} ->
          Logger.error("OAuth exchange failed: #{reason}")
          {:error, reason}
      end
    else
      {:error, "OAuth credentials not configured"}
    end
  end

  @spec refresh_access_token(String.t()) :: {:ok, map()} | {:error, String.t()}
  def refresh_access_token(refresh_token) do
    client_id = Application.get_env(:bot_army_youtube_manager, :oauth_client_id)
    client_secret = Application.get_env(:bot_army_youtube_manager, :oauth_client_secret)

    if client_id && client_secret do
      body = %{
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: refresh_token,
        grant_type: "refresh_token"
      }

      case post_token_request(body) do
        {:ok, tokens} ->
          Logger.debug("OAuth token refreshed")
          {:ok, tokens}

        {:error, reason} ->
          Logger.error("OAuth refresh failed: #{reason}")
          {:error, reason}
      end
    else
      {:error, "OAuth credentials not configured"}
    end
  end

  @spec get_valid_access_token() :: {:ok, String.t()} | {:error, String.t()}
  def get_valid_access_token do
    case System.get_env("YOUTUBE_OAUTH_ACCESS_TOKEN") do
      nil ->
        {:error, "No access token available. Run initial authorization first."}

      token ->
        # In a real implementation, check token expiration and refresh if needed
        {:ok, token}
    end
  end

  defp post_token_request(body) do
    case Req.post(@token_endpoint, json: body) do
      {:ok, response} ->
        data = response.body

        if is_map(data) && Map.has_key?(data, "error") do
          error = Map.get(data, "error")
          description = Map.get(data, "error_description", "")
          msg = if description != "", do: "#{error}: #{description}", else: error
          {:error, msg}
        else
          {:ok, data}
        end

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp redirect_uri do
    Application.get_env(:bot_army_youtube_manager, :oauth_redirect_uri) ||
      "http://localhost:8080/oauth/callback"
  end
end
