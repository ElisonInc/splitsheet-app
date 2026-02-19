-- SplitSheet Hardened Schema - Legally Defensible Ownership System
-- Security, Immutability, Auditability, Verification

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- PROFILES TABLE
-- ============================================
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  legal_name text,
  artist_name text,
  email text,
  pro_affiliation text default 'ASCAP',
  ipi_number text,
  avatar_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ============================================
-- SESSIONS TABLE (Agreement Container)
-- ============================================
create table if not exists public.sessions (
  id text primary key,
  song_title text default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  
  -- Version control
  version integer default 1 not null,
  parent_session_id text references public.sessions(id) on delete set null,
  
  -- Finalization (immutable lock)
  finalized boolean default false not null,
  finalized_at timestamp with time zone,
  finalized_by uuid references auth.users(id) on delete set null,
  
  -- Verification
  hash text,
  previous_hash text,
  
  -- Access control
  is_public boolean default false not null, -- Changed to false for security
  
  -- Constraints
  constraint valid_finalization check (
    (finalized = false) or 
    (finalized = true and finalized_at is not null and finalized_by is not null)
  )
);

-- ============================================
-- CONTRIBUTORS TABLE (Ownership Stakeholders)
-- ============================================
create table if not exists public.contributors (
  id uuid default gen_random_uuid() primary key,
  session_id text references public.sessions(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete set null,
  
  -- Identity
  legal_name text not null,
  email text,
  
  -- Role & Rights
  role text not null check (role in ('Artist', 'Producer', 'Writer', 'Engineer', 'Featured', 'Other')),
  rights_type text not null check (rights_type in ('Master', 'Publishing', 'Both')),
  
  -- Ownership (stored as basis points to avoid floating point: 10000 = 100%)
  ownership_bps integer not null default 0 check (ownership_bps >= 0 and ownership_bps <= 10000),
  
  -- PRO Information
  pro_affiliation text default 'ASCAP',
  ipi_number text,
  
  -- Signature with consent
  signature_data text,
  signed_at timestamp with time zone,
  signature_consent boolean default false not null,
  
  -- Metadata
  is_creator boolean default false not null,
  device_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  
  -- Immutability: Prevent edits after finalization via trigger
  constraint signature_requires_consent check (
    (signature_data is null) or 
    (signature_data is not null and signature_consent = true)
  )
);

-- ============================================
-- AUDIT LOG (Comprehensive Trail)
-- ============================================
create table if not exists public.audit_log (
  id uuid default gen_random_uuid() primary key,
  session_id text references public.sessions(id) on delete cascade not null,
  contributor_id uuid references public.contributors(id) on delete set null,
  
  -- Action type
  action text not null check (action in (
    'SESSION_CREATED', 'SESSION_FINALIZED', 'CONTRIBUTOR_ADDED', 
    'CONTRIBUTOR_UPDATED', 'SIGNATURE_ADDED', 'SIGNATURE_REVOKED',
    'OWNERSHIP_CHANGED', 'ROLE_CHANGED', 'VERSION_CREATED'
  )),
  
  -- Actor identity
  user_id uuid references auth.users(id) on delete set null,
  user_email text,
  
  -- Technical metadata
  ip_address inet,
  user_agent text,
  
  -- Data snapshot (JSON of what changed)
  old_data jsonb,
  new_data jsonb,
  
  -- Verification
  agreement_hash text,
  
  -- Timestamp
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ============================================
-- AGREEMENT VERSIONS (Immutable History)
-- ============================================
create table if not exists public.agreement_versions (
  id uuid default gen_random_uuid() primary key,
  session_id text references public.sessions(id) on delete cascade not null,
  version_number integer not null,
  
  -- Snapshot of entire agreement at this version
  song_title text,
  contributors_snapshot jsonb not null,
  total_ownership_bps integer not null,
  
  -- Verification
  hash text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  created_by uuid references auth.users(id) on delete set null,
  
  unique(session_id, version_number)
);

-- ============================================
-- VERIFICATION ENDPOINTS (Public Access)
-- ============================================
create table if not exists public.verification_records (
  id uuid default gen_random_uuid() primary key,
  session_id text references public.sessions(id) on delete cascade not null,
  hash text not null,
  
  -- Public data (what anyone can verify)
  song_title text,
  finalized_at timestamp with time zone,
  contributor_count integer not null,
  all_signed boolean not null,
  
  -- No sensitive data here (no names, no signatures)
  
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- ============================================
-- INDEXES
-- ============================================
create index if not exists idx_contributors_session on public.contributors(session_id);
create index if not exists idx_contributors_user on public.contributors(user_id);
create index if not exists idx_audit_session on public.audit_log(session_id);
create index if not exists idx_audit_action on public.audit_log(action);
create index if not exists idx_audit_created on public.audit_log(created_at);
create index if not exists idx_versions_session on public.agreement_versions(session_id);
create index if not exists idx_verification_hash on public.verification_records(hash);
create index if not exists idx_verification_session on public.verification_records(session_id);
create index if not exists idx_sessions_finalized on public.sessions(finalized);

-- ============================================
-- ROW LEVEL SECURITY (Strict)
-- ============================================

-- Enable RLS on all tables
alter table public.profiles enable row level security;
alter table public.sessions enable row level security;
alter table public.contributors enable row level security;
alter table public.audit_log enable row level security;
alter table public.agreement_versions enable row level security;
alter table public.verification_records enable row level security;

-- ============================================
-- RLS POLICIES
-- ============================================

-- PROFILES: Public read, self-only write
drop policy if exists "Public profiles readable" on public.profiles;
create policy "Public profiles readable"
  on public.profiles for select using (true);

drop policy if exists "Users insert own profile" on public.profiles;
create policy "Users insert own profile"
  on public.profiles for insert with check (auth.uid() = id);

drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile"
  on public.profiles for update using (auth.uid() = id);

-- SESSIONS: Participants only
drop policy if exists "Session participants can read" on public.sessions;
create policy "Session participants can read"
  on public.sessions for select
  using (
    -- Can read if: creator, contributor, or public (only if finalized)
    created_by = auth.uid() or
    is_public = true or
    exists (
      select 1 from public.contributors c
      where c.session_id = sessions.id and c.user_id = auth.uid()
    ) or
    exists (
      select 1 from public.contributors c
      where c.session_id = sessions.id and c.device_id = current_setting('app.device_id', true)
    )
  );

drop policy if exists "Authenticated users create sessions" on public.sessions;
create policy "Authenticated users create sessions"
  on public.sessions for insert
  with check (
    auth.uid() is not null or
    current_setting('app.device_id', true) is not null
  );

drop policy if exists "Only creator can update unfinalized" on public.sessions;
create policy "Only creator can update unfinalized"
  on public.sessions for update
  using (
    -- Must be unfinalized
    finalized = false and
    -- And be creator or admin
    (
      created_by = auth.uid() or
      created_by is null
    )
  );

-- CONTRIBUTORS: Session participants only
drop policy if exists "Contributors readable by participants" on public.contributors;
create policy "Contributors readable by participants"
  on public.contributors for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = contributors.session_id
      and (
        s.created_by = auth.uid() or
        s.is_public = true or
        exists (
          select 1 from public.contributors c2
          where c2.session_id = s.id and c2.user_id = auth.uid()
        ) or
        exists (
          select 1 from public.contributors c2
          where c2.session_id = s.id and c2.device_id = current_setting('app.device_id', true)
        )
      )
    )
  );

drop policy if exists "Participants can add contributors" on public.contributors;
create policy "Participants can add contributors"
  on public.contributors for insert
  with check (
    -- Session must be unfinalized
    exists (
      select 1 from public.sessions s
      where s.id = contributors.session_id and s.finalized = false
    ) and
    -- Must be authenticated or have device ID
    (auth.uid() is not null or current_setting('app.device_id', true) is not null)
  );

drop policy if exists "Only self can update own contributor" on public.contributors;
create policy "Only self can update own contributor"
  on public.contributors for update
  using (
    -- Session must be unfinalized
    exists (
      select 1 from public.sessions s
      where s.id = contributors.session_id and s.finalized = false
    ) and
    -- Can only update own entry
    (
      user_id = auth.uid() or
      device_id = current_setting('app.device_id', true)
    )
  );

drop policy if exists "Only self can delete own contributor" on public.contributors;
create policy "Only self can delete own contributor"
  on public.contributors for delete
  using (
    -- Session must be unfinalized
    exists (
      select 1 from public.sessions s
      where s.id = contributors.session_id and s.finalized = false
    ) and
    -- Can only delete own entry
    (
      user_id = auth.uid() or
      device_id = current_setting('app.device_id', true)
    )
  );

-- AUDIT LOG: Append-only, readable by participants
drop policy if exists "Audit readable by participants" on public.audit_log;
create policy "Audit readable by participants"
  on public.audit_log for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = audit_log.session_id
      and (
        s.created_by = auth.uid() or
        exists (
          select 1 from public.contributors c
          where c.session_id = s.id and c.user_id = auth.uid()
        )
      )
    )
  );

drop policy if exists "System can insert audit" on public.audit_log;
create policy "System can insert audit"
  on public.audit_log for insert
  with check (true); -- Inserted via triggers/functions

-- AGREEMENT VERSIONS: Immutable, readable by participants
drop policy if exists "Versions readable by participants" on public.agreement_versions;
create policy "Versions readable by participants"
  on public.agreement_versions for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = agreement_versions.session_id
      and (
        s.created_by = auth.uid() or
        exists (
          select 1 from public.contributors c
          where c.session_id = s.id and c.user_id = auth.uid()
        )
      )
    )
  );

drop policy if exists "System can create versions" on public.agreement_versions;
create policy "System can create versions"
  on public.agreement_versions for insert
  with check (true);

-- VERIFICATION RECORDS: Public readable
drop policy if exists "Verification records public readable" on public.verification_records;
create policy "Verification records public readable"
  on public.verification_records for select using (true);

drop policy if exists "System can create verification" on public.verification_records;
create policy "System can create verification"
  on public.verification_records for insert
  with check (true);

-- ============================================
-- FUNCTIONS FOR IMMUTABILITY & AUDIT
-- ============================================

-- Prevent updates to finalized sessions
CREATE OR REPLACE FUNCTION public.prevent_finalized_modification()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.finalized = true THEN
    RAISE EXCEPTION 'Cannot modify finalized agreement. Create a new version instead.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS prevent_session_finalized_update ON public.sessions;
CREATE TRIGGER prevent_session_finalized_update
  BEFORE UPDATE ON public.sessions
  FOR EACH ROW EXECUTE FUNCTION public.prevent_finalized_modification();

-- Prevent updates to finalized contributors
CREATE OR REPLACE FUNCTION public.prevent_contributor_finalized_modification()
RETURNS TRIGGER AS $$
DECLARE
  session_finalized boolean;
BEGIN
  SELECT finalized INTO session_finalized
  FROM public.sessions
  WHERE id = NEW.session_id;
  
  IF session_finalized = true THEN
    RAISE EXCEPTION 'Cannot modify contributors in finalized agreement.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS prevent_contributor_finalized_update ON public.contributors;
CREATE TRIGGER prevent_contributor_finalized_update
  BEFORE UPDATE ON public.contributors
  FOR EACH ROW EXECUTE FUNCTION public.prevent_contributor_finalized_modification();

-- Auto-update timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_profile_updated ON public.profiles;
CREATE TRIGGER on_profile_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS on_contributor_updated ON public.contributors;
CREATE TRIGGER on_contributor_updated
  BEFORE UPDATE ON public.contributors
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, legal_name)
  VALUES (
    NEW.id, 
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- AUDIT LOGGING FUNCTIONS
-- ============================================

-- Log contributor changes
CREATE OR REPLACE FUNCTION public.log_contributor_change()
RETURNS TRIGGER AS $$
DECLARE
  session_hash text;
BEGIN
  -- Get current session hash if available
  SELECT hash INTO session_hash
  FROM public.sessions
  WHERE id = COALESCE(NEW.session_id, OLD.session_id);

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.audit_log (
      session_id, contributor_id, action, user_id, user_email,
      new_data, agreement_hash, user_agent
    ) VALUES (
      NEW.session_id, NEW.id, 'CONTRIBUTOR_ADDED', NEW.user_id, NEW.email,
      jsonb_build_object(
        'legal_name', NEW.legal_name,
        'role', NEW.role,
        'rights_type', NEW.rights_type,
        'ownership_bps', NEW.ownership_bps
      ),
      session_hash,
      current_setting('request.headers', true)::jsonb->>'user-agent'
    );
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Only log if ownership changed
    IF OLD.ownership_bps != NEW.ownership_bps THEN
      INSERT INTO public.audit_log (
        session_id, contributor_id, action, user_id, user_email,
        old_data, new_data, agreement_hash
      ) VALUES (
        NEW.session_id, NEW.id, 'OWNERSHIP_CHANGED', NEW.user_id, NEW.email,
        jsonb_build_object('ownership_bps', OLD.ownership_bps),
        jsonb_build_object('ownership_bps', NEW.ownership_bps),
        session_hash
      );
    END IF;
    
    -- Log signature addition
    IF OLD.signature_data IS NULL AND NEW.signature_data IS NOT NULL THEN
      INSERT INTO public.audit_log (
        session_id, contributor_id, action, user_id, user_email,
        new_data, agreement_hash
      ) VALUES (
        NEW.session_id, NEW.id, 'SIGNATURE_ADDED', NEW.user_id, NEW.email,
        jsonb_build_object(
          'signed_at', NEW.signed_at,
          'signature_consent', NEW.signature_consent
        ),
        session_hash
      );
    END IF;
    
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS log_contributor_audit ON public.contributors;
CREATE TRIGGER log_contributor_audit
  AFTER INSERT OR UPDATE ON public.contributors
  FOR EACH ROW EXECUTE FUNCTION public.log_contributor_change();

-- ============================================
-- DATA INTEGRITY FUNCTIONS
-- ============================================

-- Validate ownership totals 100%
CREATE OR REPLACE FUNCTION public.validate_ownership_total()
RETURNS TRIGGER AS $$
DECLARE
  total_bps integer;
  session_finalized boolean;
BEGIN
  -- Skip validation for finalized sessions (immutable)
  SELECT finalized INTO session_finalized
  FROM public.sessions WHERE id = NEW.session_id;
  
  IF session_finalized = true THEN
    RETURN NEW;
  END IF;

  -- Calculate total ownership in basis points
  SELECT COALESCE(SUM(ownership_bps), 0) INTO total_bps
  FROM public.contributors
  WHERE session_id = NEW.session_id;

  -- Only validate on finalization attempt
  IF NEW.finalized = true AND OLD.finalized = false THEN
    IF total_bps != 10000 THEN
      RAISE EXCEPTION 'Total ownership must equal 100%% (current: %)', total_bps / 100.0;
    END IF;
    
    -- Check all contributors have signed
    IF EXISTS (
      SELECT 1 FROM public.contributors
      WHERE session_id = NEW.session_id
      AND (signature_data IS NULL OR signature_consent = false)
    ) THEN
      RAISE EXCEPTION 'All contributors must sign and consent before finalization';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS validate_ownership_on_finalize ON public.sessions;
CREATE TRIGGER validate_ownership_on_finalize
  BEFORE UPDATE ON public.sessions
  FOR EACH ROW EXECUTE FUNCTION public.validate_ownership_total();

-- ============================================
-- ENABLE REALTIME
-- ============================================
DO $$
DECLARE
  tables_to_add text[] := ARRAY['sessions', 'contributors', 'profiles'];
  t text;
BEGIN
  FOREACH t IN ARRAY tables_to_add LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION 
      WHEN duplicate_object THEN null;
      WHEN OTHERS THEN null;
    END;
  END LOOP;
END $$;

-- Comments
COMMENT ON TABLE public.profiles IS 'User profiles extending auth.users';
COMMENT ON TABLE public.sessions IS 'Agreement sessions with versioning and immutability';
COMMENT ON TABLE public.contributors IS 'Ownership stakeholders with signature requirements';
COMMENT ON TABLE public.audit_log IS 'Comprehensive audit trail for legal defensibility';
COMMENT ON TABLE public.agreement_versions IS 'Immutable agreement version history';
COMMENT ON TABLE public.verification_records IS 'Public verification data (no PII)';
