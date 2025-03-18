# SageAI - Intelligent Telegram Chatbot

A powerful AI-powered Telegram chatbot built with n8n, featuring intelligent conversations, customizable settings, and comprehensive usage tracking.

## Features

- 🤖 Advanced AI conversation capabilities using multiple AI models
- 🔧 Customizable user preferences and settings
- 📊 Detailed usage tracking and analytics
- ⚡ Rate limiting and premium user support
- 🌍 Multi-language support
- 📝 Customizable system prompts
- 📈 Daily and monthly usage monitoring

## Tech Stack

- **n8n** - Workflow automation platform
- **PostgreSQL** - Database management
- **Telegram Bot API** - Bot interface
- **Multiple AI Models** - Including support for GPT models

## Prerequisites

- n8n installed and configured
- PostgreSQL database server
- Telegram Bot Token
- AI model API keys (based on your chosen providers)

## Database Schema

The project uses a comprehensive PostgreSQL database with the following main tables:

- `users` - Stores Telegram user information
- `user_settings` - User preferences and AI interaction settings
- `bot_commands` - Available bot commands
- `usage_metrics` - Detailed interaction tracking
- `daily_usage_summary` - Aggregated daily statistics
- `rate_limits` - User rate limiting controls

## Setup

1. **Database Setup**
   ```bash
   psql -d your_database_name -f db.sql
   ```

2. **Environment Variables**
   Create a `.env` file with the following variables:
   ```
   TELEGRAM_BOT_TOKEN=your_bot_token
   DATABASE_URL=postgresql://user:password@localhost:5432/database_name
   AI_API_KEY=your_ai_api_key
   ```

3. **n8n Configuration**
   - Open your n8n instance
   - Create a new workflow
   - Click on the three dots menu in the top right
   - Select "Import from File"
   - Upload the `ai-chat.json` file provided in this repository
   - Configure the following nodes in the imported workflow:
     - PostgreSQL connection details
     - Telegram node with your bot token
     - AI model credentials
   - Save and activate the workflow

## Usage

Users can interact with the bot through Telegram using various commands:

- `/start` - Initialize the bot
- `/settings` - Customize AI interaction preferences
- `/help` - Get command list and usage instructions
- Direct messages - Engage in AI conversations

## Features in Detail

### User Settings
- AI model selection
- Response format preferences
- Language preferences
- Custom system prompts
- Token limits
- Temperature settings

### Usage Tracking
- Request monitoring
- Token usage
- Response times
- Error logging
- Daily and monthly summaries

### Rate Limiting
- Daily request limits
- Monthly request limits
- Premium user privileges
- Usage monitoring

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

Created by [@1mr-newton](https://github.com/1mr-newton)

## Acknowledgments

- Thanks to the n8n team for their excellent workflow automation platform
- Telegram Bot API for enabling bot creation
- AI model providers for their APIs 