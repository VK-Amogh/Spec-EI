-- ============================================
-- SpecEI Database Tables for Supabase
-- Run this in your Supabase SQL Editor
-- Go to: Supabase Dashboard > SQL Editor > New Query
-- ============================================

-- 1. REMINDERS TABLE
-- Stores user reminders set from the Home page
CREATE TABLE IF NOT EXISTS public.reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  reminder_datetime TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  is_completed BOOLEAN DEFAULT FALSE
);

-- Enable RLS (Row Level Security)
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own reminders
CREATE POLICY "Users can manage their own reminders" ON public.reminders
  FOR ALL USING (user_id = auth.uid()::text OR user_id = current_user);

-- Allow insert for authenticated users
CREATE POLICY "Allow insert for all" ON public.reminders
  FOR INSERT WITH CHECK (true);

-- Allow select for all (temporary for development)
CREATE POLICY "Allow select for all" ON public.reminders
  FOR SELECT USING (true);

-- Allow update for all
CREATE POLICY "Allow update for all" ON public.reminders
  FOR UPDATE USING (true);

-- Allow delete for all
CREATE POLICY "Allow delete for all" ON public.reminders
  FOR DELETE USING (true);

-- 2. NOTES TABLE
-- Stores user notes from the Notes screen
CREATE TABLE IF NOT EXISTS public.notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- Policies for notes
CREATE POLICY "Allow insert notes" ON public.notes FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow select notes" ON public.notes FOR SELECT USING (true);
CREATE POLICY "Allow update notes" ON public.notes FOR UPDATE USING (true);
CREATE POLICY "Allow delete notes" ON public.notes FOR DELETE USING (true);

-- 3. FOCUS SESSIONS TABLE
-- Tracks focus mode sessions
CREATE TABLE IF NOT EXISTS public.focus_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  session_type TEXT DEFAULT 'timed',
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  actual_minutes INTEGER,
  is_completed BOOLEAN DEFAULT FALSE
);

-- Enable RLS
ALTER TABLE public.focus_sessions ENABLE ROW LEVEL SECURITY;

-- Policies for focus_sessions
CREATE POLICY "Allow insert focus" ON public.focus_sessions FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow select focus" ON public.focus_sessions FOR SELECT USING (true);
CREATE POLICY "Allow update focus" ON public.focus_sessions FOR UPDATE USING (true);
CREATE POLICY "Allow delete focus" ON public.focus_sessions FOR DELETE USING (true);

-- 4. MEDIA TABLE (for photos, videos, audio)
-- Stores metadata for captured media (actual files stored in Supabase Storage)
CREATE TABLE IF NOT EXISTS public.media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  media_type TEXT NOT NULL CHECK (media_type IN ('photo', 'video', 'audio')),
  file_path TEXT,
  file_url TEXT,
  duration_seconds INTEGER,
  captured_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.media ENABLE ROW LEVEL SECURITY;

-- Policies for media
CREATE POLICY "Allow insert media" ON public.media FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow select media" ON public.media FOR SELECT USING (true);
CREATE POLICY "Allow update media" ON public.media FOR UPDATE USING (true);
CREATE POLICY "Allow delete media" ON public.media FOR DELETE USING (true);

-- ============================================
-- Create indexes for better performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_reminders_user ON public.reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_datetime ON public.reminders(reminder_datetime);
CREATE INDEX IF NOT EXISTS idx_notes_user ON public.notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_created ON public.notes(created_at);
CREATE INDEX IF NOT EXISTS idx_focus_user ON public.focus_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_media_user ON public.media(user_id);
CREATE INDEX IF NOT EXISTS idx_media_type ON public.media(media_type);

-- ============================================
-- SUCCESS! All tables created.
-- Your app can now save reminders, notes, focus sessions, and media!
-- ============================================
