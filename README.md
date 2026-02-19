# SplitSheet

Real-time collaborative split sheet agreements for music creators. No more lost royalties, no more "we'll figure it out later."

![SplitSheet](https://img.shields.io/badge/version-1.0.0-green)
![PWA](https://img.shields.io/badge/PWA-Ready-blue)
![License](https://img.shields.io/badge/license-MIT-yellow)

## Features

- ⚡ **Real-time Collaboration** — All writers add their splits simultaneously while the vibe is fresh
- ✓ **Legally Binding** — Digital signatures + PDF generation recognized by PROs worldwide
- 📱 **Mobile-First PWA** — Install on iOS/Android, works offline
- 🔒 **Tamper-Proof** — SHA-256 document hashing ensures agreement integrity
- 📤 **Easy Sharing** — QR codes and session links for instant collaboration
- 🔄 **Offline Support** — Queue changes when offline, sync when reconnected

## Quick Start

### 1. Setup Supabase

1. Create a new project at [supabase.com](https://supabase.com)
2. Go to the SQL Editor and run the contents of `supabase/schema.sql`
3. Copy your project URL and anon key from Settings → API

### 2. Configure the App

1. Copy `supabase/.env.example` to `supabase/.env`
2. Edit `js/config.js` and add your Supabase credentials:

```javascript
const SUPABASE_CONFIG = {
    URL: 'https://your-project.supabase.co',
    ANON_KEY: 'your-anon-key-here'
};
```

### 3. Generate Icons

Open `icons/generate-icons.html` in a browser and click "Download All Icons" to generate PWA icons.

### 4. Deploy

Deploy to any static hosting:

```bash
# GitHub Pages
# Just push to your repo and enable Pages in settings

# Or use Vercel
npm i -g vercel
vercel --prod

# Or Netlify
drop the folder on netlify.com
```

## Database Schema

### Sessions Table
- `id` (text, primary key) — Session code
- `song_title` (text) — Song name
- `finalized` (boolean) — Whether agreement is complete
- `hash` (text) — SHA-256 document hash

### Collaborators Table
- `id` (uuid, primary key)
- `session_id` (text) — Links to session
- `legal_name`, `email`, `pro_affiliation`, `ipi_number` — Writer info
- `percentage` (integer) — Ownership split (0-100)
- `signature_data` (text) — Base64 signature image
- `device_id` (text) — For re-identification

## PWA Features

### Install on Mobile

**iOS (Safari):**
1. Open the app in Safari
2. Tap Share → "Add to Home Screen"
3. Open from home screen like a native app

**Android (Chrome):**
1. Open the app in Chrome
2. Tap menu → "Add to Home screen"
3. Or accept the install prompt

### Offline Support

- App shell is cached for instant load
- Changes queued when offline, synced on reconnect
- Toast notifications inform you of sync status

### Push Notifications

Service worker supports push notifications for:
- Session updates
- New collaborators joining
- Finalization events

(Requires additional setup with your push notification provider)

## Project Structure

```
splitsheet-app/
├── index.html              # Main application
├── manifest.json           # PWA manifest
├── sw.js                   # Service Worker (offline support)
├── js/
│   └── config.js           # App configuration
├── supabase/
│   ├── schema.sql          # Database setup
│   └── .env.example        # Environment template
├── icons/
│   └── generate-icons.html # Icon generator tool
├── README.md
└── CONTRIBUTING.md
```

## Environment Variables

Create `supabase/.env` from the example file:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

## Development

```bash
# Clone the repo
git clone https://github.com/ElisonInc/splitsheet-app.git
cd splitsheet-app

# Start a local server
python3 -m http.server 8000
# or
npx serve .

# Open http://localhost:8000
```

## Customization

### Colors
Edit the CSS variables in `index.html`:

```css
--primary: #30D158;      /* Green accent */
--secondary: #007AFF;     /* Blue accent */
```

### Max Collaborators
Edit `APP_CONFIG` in `js/config.js`:

```javascript
MAX_COLLABORATORS: 10,
DEFAULT_CREATOR_SPLIT: 50,
```

## Security Considerations

⚠️ **Important:** The current setup uses open RLS policies for demo purposes. For production:

1. Enable proper Row Level Security
2. Add authentication if needed
3. Rate limit session creation
4. Validate all inputs server-side

## Browser Support

- Chrome/Edge 90+
- Safari 14+
- Firefox 90+
- iOS Safari 14+
- Chrome Android 90+

## License

MIT License - Copyright (c) 2026 Elison Inc.

## Credits

Built by [Elison Inc.](https://github.com/ElisonInc)

---

**Need help?** Open an issue on GitHub or email support@elison.inc
