-- ==============================================================================
-- SpecEI Memory System Schema Extension
-- Adds structured metadata tables for AI-analyzed content
-- Run this in Supabase SQL Editor
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TRANSCRIPTS TABLE - Stores speech-to-text output
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transcripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID REFERENCES public.media(id) ON DELETE CASCADE,
    language TEXT DEFAULT 'en',
    full_text TEXT NOT NULL,
    confidence FLOAT,
    word_count INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for transcripts
CREATE INDEX IF NOT EXISTS idx_transcripts_media ON public.transcripts(media_id);
CREATE INDEX IF NOT EXISTS idx_transcripts_fulltext ON public.transcripts USING gin(to_tsvector('english', full_text));

-- ------------------------------------------------------------------------------
-- 2. EVENTS TABLE - Represents meaningful moments/activities
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    summary TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    event_type TEXT CHECK (event_type IN ('conversation', 'activity', 'scene', 'memory')),
    importance INTEGER DEFAULT 5 CHECK (importance BETWEEN 1 AND 10),
    location TEXT,
    tags TEXT[], -- Array of tags
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for events
CREATE INDEX IF NOT EXISTS idx_events_user ON public.events(user_id);
CREATE INDEX IF NOT EXISTS idx_events_time ON public.events(start_time);
CREATE INDEX IF NOT EXISTS idx_events_type ON public.events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_summary ON public.events USING gin(to_tsvector('english', COALESCE(summary, '')));

-- ------------------------------------------------------------------------------
-- 3. EVENT_MEDIA JUNCTION TABLE - Links events to media
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.event_media (
    event_id UUID REFERENCES public.events(id) ON DELETE CASCADE,
    media_id UUID REFERENCES public.media(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'primary', -- 'primary', 'context', 'reference'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (event_id, media_id)
);

-- ------------------------------------------------------------------------------
-- 4. DETECTED_OBJECTS TABLE - Stores object/entity detections
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.detected_objects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID REFERENCES public.media(id) ON DELETE CASCADE,
    object_type TEXT NOT NULL CHECK (object_type IN ('person', 'object', 'text', 'place', 'animal', 'brand', 'activity')),
    label TEXT NOT NULL,
    confidence FLOAT,
    bounding_box JSONB, -- {x, y, width, height} normalized 0-1
    timestamp_seconds FLOAT, -- For video: which second this was detected
    metadata JSONB, -- Additional structured data
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for detected_objects
CREATE INDEX IF NOT EXISTS idx_detected_objects_media ON public.detected_objects(media_id);
CREATE INDEX IF NOT EXISTS idx_detected_objects_type ON public.detected_objects(object_type);
CREATE INDEX IF NOT EXISTS idx_detected_objects_label ON public.detected_objects(label);
CREATE INDEX IF NOT EXISTS idx_detected_objects_label_search ON public.detected_objects USING gin(to_tsvector('english', label));

-- ------------------------------------------------------------------------------
-- 5. RLS POLICIES - Enable Row Level Security
-- ------------------------------------------------------------------------------
ALTER TABLE public.transcripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.detected_objects ENABLE ROW LEVEL SECURITY;

-- Public access policies (matching existing media table pattern)
DROP POLICY IF EXISTS "transcripts_public" ON public.transcripts;
CREATE POLICY "transcripts_public" ON public.transcripts FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "events_public" ON public.events;
CREATE POLICY "events_public" ON public.events FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "event_media_public" ON public.event_media;
CREATE POLICY "event_media_public" ON public.event_media FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "detected_objects_public" ON public.detected_objects;
CREATE POLICY "detected_objects_public" ON public.detected_objects FOR ALL USING (true) WITH CHECK (true);

-- ------------------------------------------------------------------------------
-- 6. RPC FUNCTIONS - Secure operations
-- ------------------------------------------------------------------------------

-- Save transcript function
CREATE OR REPLACE FUNCTION public.save_transcript(
    p_media_id UUID,
    p_full_text TEXT,
    p_language TEXT DEFAULT 'en',
    p_confidence FLOAT DEFAULT NULL
)
RETURNS SETOF public.transcripts
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_word_count INTEGER;
BEGIN
    -- Calculate word count
    v_word_count := array_length(string_to_array(trim(p_full_text), ' '), 1);
    
    RETURN QUERY
    INSERT INTO public.transcripts (media_id, full_text, language, confidence, word_count)
    VALUES (p_media_id, p_full_text, p_language, p_confidence, v_word_count)
    ON CONFLICT DO NOTHING
    RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_transcript(UUID, TEXT, TEXT, FLOAT) TO anon, authenticated, service_role;

-- Save detected object function
CREATE OR REPLACE FUNCTION public.save_detected_object(
    p_media_id UUID,
    p_object_type TEXT,
    p_label TEXT,
    p_confidence FLOAT DEFAULT NULL,
    p_timestamp_seconds FLOAT DEFAULT NULL,
    p_bounding_box JSONB DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
)
RETURNS SETOF public.detected_objects
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO public.detected_objects (
        media_id, object_type, label, confidence, timestamp_seconds, bounding_box, metadata
    )
    VALUES (
        p_media_id, p_object_type, p_label, p_confidence, p_timestamp_seconds, p_bounding_box, p_metadata
    )
    RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION public.save_detected_object(UUID, TEXT, TEXT, FLOAT, FLOAT, JSONB, JSONB) TO anon, authenticated, service_role;

-- Semantic search function - searches across all metadata
CREATE OR REPLACE FUNCTION public.search_memory(
    p_user_id TEXT,
    p_query TEXT
)
RETURNS TABLE (
    media_id UUID,
    media_type TEXT,
    file_url TEXT,
    match_source TEXT,
    match_text TEXT,
    relevance FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tsquery tsquery;
BEGIN
    -- Convert query to tsquery
    v_tsquery := plainto_tsquery('english', p_query);
    
    RETURN QUERY
    -- Search in ai_description
    SELECT 
        m.id as media_id,
        m.media_type,
        m.file_url,
        'ai_description'::TEXT as match_source,
        m.ai_description as match_text,
        ts_rank(to_tsvector('english', COALESCE(m.ai_description, '')), v_tsquery)::FLOAT as relevance
    FROM public.media m
    WHERE m.user_id = p_user_id
      AND m.ai_description IS NOT NULL
      AND to_tsvector('english', m.ai_description) @@ v_tsquery
    
    UNION ALL
    
    -- Search in transcripts
    SELECT 
        t.media_id,
        m.media_type,
        m.file_url,
        'transcript'::TEXT as match_source,
        t.full_text as match_text,
        ts_rank(to_tsvector('english', t.full_text), v_tsquery)::FLOAT as relevance
    FROM public.transcripts t
    JOIN public.media m ON m.id = t.media_id
    WHERE m.user_id = p_user_id
      AND to_tsvector('english', t.full_text) @@ v_tsquery
    
    UNION ALL
    
    -- Search in detected objects
    SELECT 
        d.media_id,
        m.media_type,
        m.file_url,
        'detected_object'::TEXT as match_source,
        d.label as match_text,
        ts_rank(to_tsvector('english', d.label), v_tsquery)::FLOAT as relevance
    FROM public.detected_objects d
    JOIN public.media m ON m.id = d.media_id
    WHERE m.user_id = p_user_id
      AND to_tsvector('english', d.label) @@ v_tsquery
    
    ORDER BY relevance DESC
    LIMIT 50;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_memory(TEXT, TEXT) TO anon, authenticated, service_role;

-- ==============================================================================
-- END OF MIGRATION
-- ==============================================================================
