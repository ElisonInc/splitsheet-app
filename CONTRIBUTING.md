# Contributing to SplitSheet

Thank you for your interest in contributing to SplitSheet!

## Development Setup

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/splitsheet-app.git`
3. Open `index.html` in your browser or use a local server

## Project Structure

```
splitsheet-app/
├── index.html          # Main app file
├── manifest.json       # PWA manifest
├── sw.js              # Service Worker
├── js/
│   └── config.js      # Configuration file
├── supabase/
│   ├── schema.sql     # Database schema
│   └── .env.example   # Environment template
├── icons/             # App icons
└── README.md
```

## Database Schema

The app uses Supabase with two main tables:

- **sessions**: Stores split sheet sessions
- **collaborators**: Stores writer information and splits

See `supabase/schema.sql` for the full schema.

## Pull Request Process

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make your changes
3. Test thoroughly
4. Commit with clear messages
5. Push and create a PR

## Code Style

- Use 4 spaces for indentation
- Follow existing patterns
- Comment complex logic
- Keep functions small and focused

## Reporting Issues

Please include:
- Browser/OS info
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable
