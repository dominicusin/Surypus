# Webhook Configuration

This directory contains webhook configuration templates for Discord and Slack integration.

## Setup

1. Create webhooks in Discord/Slack
2. Add webhook URLs as repository secrets
3. Use the webhook setup scripts in `.github/workflows/`

## Templates

- `discord-template.json` - Discord webhook payload template
- `slack-template.json` - Slack webhook payload template

## Required Secrets

- `DISCORD_WEBHOOK_URL` - Discord webhook URL
- `SLACK_WEBHOOK_URL` - Slack webhook URL
- `SLACK_BOT_TOKEN` - Slack bot token (optional, for advanced features)
