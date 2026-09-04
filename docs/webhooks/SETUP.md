# Webhook Setup Guide

This guide explains how to set up Discord and Slack webhooks for the Surypus project.

## Discord Webhook Setup

1. Open your Discord server settings
2. Go to **Integrations** → **Webhooks**
3. Click **New Webhook**
4. Configure:
   - **Name**: Surypus Bot
   - **Channel**: Select your notifications channel
   - **Avatar**: Use the Surypus logo
5. Click **Copy Webhook URL**
6. Add this URL as a secret in your GitHub repository:
   - Go to **Settings** → **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `DISCORD_WEBHOOK_URL`
   - Value: Paste your webhook URL

## Slack Webhook Setup

1. Open your Slack workspace
2. Go to **Settings** → **Apps** → **Incoming Webhooks**
3. Click **Add to Slack**
4. Select the channel for notifications
5. Copy the webhook URL
6. Add this URL as a secret in your GitHub repository:
   - Name: `SLACK_WEBHOOK_URL`
   - Value: Paste your webhook URL

## Optional: Slack Bot Token

For advanced features (sending messages as bot, threading, etc.):

1. Create a Slack app at https://api.slack.com/apps
2. Add **Bot Token Scopes**: `chat:write`, `channels:read`
3. Install app to workspace
4. Copy **Bot User OAuth Token** (starts with `xoxb-`)
5. Add as secret: `SLACK_BOT_TOKEN`

## Events to Notify

The webhook workflow will send notifications for:

- ✅ New issues
- ✅ New pull requests
- ✅ PR reviews
- ✅ Releases
- ✅ Security advisories

## Testing

Test your webhooks with:

```bash
# Discord
curl -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content": "Test notification from Surypus"}'

# Slack
curl -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"text": "Test notification from Surypus"}'
```

## Troubleshooting

- **Discord**: Check webhook URL is correct and channel still exists
- **Slack**: Verify bot token has correct scopes
- **GitHub Actions**: Check workflow logs for errors
