CREATE TABLE public.study_techniques (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  author_name text NOT NULL DEFAULT 'Studiekompis',
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  subject text NOT NULL DEFAULT '',
  steps jsonb NOT NULL DEFAULT '[]'::jsonb,
  is_public boolean NOT NULL DEFAULT false,
  like_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT technique_name_len CHECK (char_length(name) BETWEEN 3 AND 80),
  CONSTRAINT technique_desc_len CHECK (char_length(description) <= 600),
  CONSTRAINT technique_steps CHECK (jsonb_typeof(steps) = 'array' AND jsonb_array_length(steps) BETWEEN 1 AND 12)
);
GRANT SELECT ON public.study_techniques TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.study_techniques TO authenticated;
GRANT ALL ON public.study_techniques TO service_role;
ALTER TABLE public.study_techniques ENABLE ROW LEVEL SECURITY;
CREATE POLICY "techniques public read" ON public.study_techniques FOR SELECT TO anon, authenticated USING (is_public);
CREATE POLICY "techniques own read" ON public.study_techniques FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "techniques own insert" ON public.study_techniques FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id AND like_count = 0);
CREATE POLICY "techniques own delete" ON public.study_techniques FOR DELETE TO authenticated USING (auth.uid() = user_id);
REVOKE UPDATE ON public.study_techniques FROM authenticated;
GRANT UPDATE (name, description, subject, steps, is_public) ON public.study_techniques TO authenticated;
CREATE POLICY "techniques own update" ON public.study_techniques FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE public.technique_likes (
  technique_id uuid NOT NULL REFERENCES public.study_techniques(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (technique_id, user_id)
);
GRANT SELECT, INSERT ON public.technique_likes TO authenticated;
GRANT ALL ON public.technique_likes TO service_role;
ALTER TABLE public.technique_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tlikes own read" ON public.technique_likes FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "tlikes own insert" ON public.technique_likes FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id AND EXISTS (SELECT 1 FROM public.study_techniques t WHERE t.id = technique_id AND t.is_public));

CREATE OR REPLACE FUNCTION public.technique_like_reward() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE author uuid;
BEGIN
  UPDATE public.study_techniques SET like_count = like_count + 1 WHERE id = NEW.technique_id RETURNING user_id INTO author;
  IF author IS NOT NULL AND author <> NEW.user_id THEN UPDATE public.profiles SET xp = xp + 2 WHERE id = author; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER technique_like_reward AFTER INSERT ON public.technique_likes FOR EACH ROW EXECUTE FUNCTION public.technique_like_reward();

CREATE TABLE public.technique_shares (
  technique_id uuid PRIMARY KEY REFERENCES public.study_techniques(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT ALL ON public.technique_shares TO service_role;
ALTER TABLE public.technique_shares ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.technique_share_reward() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n integer;
BEGIN
  IF NEW.is_public AND NOT EXISTS (SELECT 1 FROM public.technique_shares WHERE technique_id = NEW.id) THEN
    INSERT INTO public.technique_shares (technique_id, user_id) VALUES (NEW.id, NEW.user_id);
    SELECT count(*) INTO n FROM public.technique_shares WHERE user_id = NEW.user_id AND created_at > now() - interval '1 day';
    IF n <= 3 THEN UPDATE public.profiles SET xp = xp + 25 WHERE id = NEW.user_id; END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER technique_share_reward AFTER INSERT OR UPDATE OF is_public ON public.study_techniques FOR EACH ROW EXECUTE FUNCTION public.technique_share_reward();
REVOKE EXECUTE ON FUNCTION public.technique_like_reward() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.technique_share_reward() FROM PUBLIC, anon, authenticated;

CREATE TABLE public.review_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  subject text NOT NULL DEFAULT '',
  content text NOT NULL DEFAULT '',
  stage integer NOT NULL DEFAULT 0,
  due_on date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT review_title_len CHECK (char_length(title) BETWEEN 1 AND 120),
  CONSTRAINT review_content_len CHECK (char_length(content) <= 8000),
  CONSTRAINT review_stage CHECK (stage BETWEEN 0 AND 10)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.review_items TO authenticated;
GRANT ALL ON public.review_items TO service_role;
ALTER TABLE public.review_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reviews own all" ON public.review_items FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX review_items_due ON public.review_items (user_id, due_on);