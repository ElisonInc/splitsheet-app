# SplitSheet

Real-time collaborative split sheet agreements for music creators. No more lost royalties, no more "we'll figure it out later."

## Features

- ⚡ **Real-time Collaboration** — All writers add their splits simultaneously while the vibe is fresh
- ✓ **Legally Binding** — Digital signatures + PDF generation recognized by PROs worldwide
- 📱 **Mobile-First** — Designed for the studio, works perfectly on phones and tablets
- 🔒 **Tamper-Proof** — SHA-256 document hashing ensures agreement integrity
- 📤 **Easy Sharing** — QR codes and session links for instant collaboration

## Tech Stack

- **Frontend**: Vanilla HTML/JS with Tailwind CSS
- **Backend**: Supabase (PostgreSQL + Realtime)
- **PDF Generation**: jsPDF
- **QR Codes**: QRCode.js

## Getting Started

### Prerequisites

- A Supabase account (free tier works fine)
- A GitHub account
- A web browser

### Supabase Setup

1. Create a new Supabase project
2. Run the following SQL in the SQL Editor:

```sql
-- Create sessions table
create table sessions (
  id text primary key,
  song_title text default '',
  created_at timestamp with time zone default timezone('utc'::text, now()),
  finalized boolean default false,
  finalized_at timestamp with time zone,
  hash text
);

-- Create collaborators table
create table collaborators (
  id uuid default gen_random_uuid() primary key,
  session_id text references sessions(id) on delete cascade,
  legal_name text,
  email text,
  pro_affiliation text default 'ASCAP',
  ipi_number text,
  contribution text default 'Both',
  percentage integer default 0,
  signature_data text,
  signed_at timestamp with time zone,
  is_creator boolean default false,
  device_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now()),
  unique(session_id, device_id)
);

-- Enable realtime
alter publication supabase_realtime add table sessions;
alter publication supabase_realtime add table collaborators;

-- Enable RLS (customize policies for production)
alter table sessions enable row level security;
alter table collaborators enable row level security;

create policy "Allow all" on sessions for all using (true);
create policy "Allow all" on collaborators for all using (true);
```

3. Copy your Supabase URL and anon key
4. Update the `SUPABASE_URL` and `SUPABASE_ANON_KEY` constants in `index.html`

### Deployment

This is a static HTML app that can be deployed anywhere:

- **GitHub Pages**: Push to a repo and enable Pages
- **Vercel**: Connect your GitHub repo
- **Netlify**: Drag and drop the folder
- **Cloudflare Pages**: Connect your GitHub repo

## Usage

1. Open the app in your browser
2. Click "New Split Sheet" to create a session
3. Enter the song title
4. Add collaborators and their splits (must total 100%)
5. Each writer signs digitally
6. Once all signatures are collected, the PDF is automatically generated

## Mobile App

The app is designed to work as a PWA (Progressive Web App):

- Add to home screen on iOS/Android
- Works offline with cached assets
- Native-like experience

## License

MIT License - Copyright (c) 2026 Elison Inc.

## Credits

Built by [Elison Inc.](https://github.com/ElisonInc)
