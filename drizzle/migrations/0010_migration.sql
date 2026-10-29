CREATE TABLE public.community_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  author_name text NOT NULL DEFAULT 'Studiekompis',
  kind text NOT NULL DEFAULT 'tenta',
  title text NOT NULL,
  course_code text NOT NULL DEFAULT '',
  subject text NOT NULL DEFAULT '',
  school text NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  file_path text,
  solution_path text,
  like_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT community_kind CHECK (kind IN ('tenta','anteckningar','sammanfattning')),
  CONSTRAINT community_title_len CHECK (char_length(title) BETWEEN 3 AND 120),
  CONSTRAINT community_desc_len CHECK (char_length(description) <= 8000)
);
GRANT SELECT ON public.community_posts TO anon;
GRANT SELECT, INSERT, DELETE ON public.community_posts TO authenticated;
GRANT ALL ON public.community_posts TO service_role;
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "community read" ON public.community_posts FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "community own insert" ON public.community_posts FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id AND like_count = 0);
CREATE POLICY "community own delete" ON public.community_posts FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE TABLE public.community_likes (
  post_id uuid NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);
GRANT SELECT, INSERT ON public.community_likes TO authenticated;
GRANT ALL ON public.community_likes TO service_role;
ALTER TABLE public.community_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "likes own read" ON public.community_likes FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "likes own insert" ON public.community_likes FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.community_post_reward() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.community_posts WHERE user_id = NEW.user_id AND created_at > now() - interval '1 day';
  IF n <= 3 THEN UPDATE public.profiles SET xp = xp + 25 WHERE id = NEW.user_id; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER community_post_reward AFTER INSERT ON public.community_posts FOR EACH ROW EXECUTE FUNCTION public.community_post_reward();

CREATE OR REPLACE FUNCTION public.community_like_reward() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE author uuid;
BEGIN
  UPDATE public.community_posts SET like_count = like_count + 1 WHERE id = NEW.post_id RETURNING user_id INTO author;
  IF author IS NOT NULL AND author <> NEW.user_id THEN UPDATE public.profiles SET xp = xp + 2 WHERE id = author; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER community_like_reward AFTER INSERT ON public.community_likes FOR EACH ROW EXECUTE FUNCTION public.community_like_reward();
REVOKE EXECUTE ON FUNCTION public.community_post_reward() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.community_like_reward() FROM PUBLIC, anon, authenticated;

CREATE POLICY "community files read" ON storage.objects FOR SELECT TO anon, authenticated USING (bucket_id = 'community');
CREATE POLICY "community files own upload" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'community' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "community files own delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'community' AND (storage.foldername(name))[1] = auth.uid()::text);