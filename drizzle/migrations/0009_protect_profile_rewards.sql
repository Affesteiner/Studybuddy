REVOKE INSERT, UPDATE ON public.profiles FROM authenticated;
GRANT UPDATE(display_name,dyslexia_mode) ON public.profiles TO authenticated;
CREATE FUNCTION public.equip_fox_avatar() RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE uid uuid:=auth.uid();
BEGIN
IF uid IS NULL OR NOT EXISTS(SELECT 1 FROM public.reward_inventory WHERE user_id=uid AND item='avatar-fox') THEN RAISE EXCEPTION 'Lås upp avataren först'; END IF;
UPDATE public.profiles SET avatar_url='reward:fox' WHERE id=uid;
RETURN true;
END; $$;
REVOKE ALL ON FUNCTION public.equip_fox_avatar() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.equip_fox_avatar() TO authenticated;
CREATE OR REPLACE FUNCTION public.add_study_xp(amount integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE uid uuid:=auth.uid(); p public.profiles; today date:=(now() AT TIME ZONE 'Europe/Stockholm')::date; gap integer; s integer; f integer;
BEGIN
IF uid IS NULL OR amount NOT IN (3,5,10,15,25,50) THEN RAISE EXCEPTION 'Ogiltig belöning'; END IF;
SELECT * INTO p FROM public.profiles WHERE id=uid FOR UPDATE;
IF NOT FOUND THEN RAISE EXCEPTION 'Profil saknas'; END IF;
gap:=today-p.last_active_date; s:=p.streak_count; f:=p.streak_freezes;
IF p.last_active_date IS NULL THEN s:=1; ELSIF gap=1 THEN s:=s+1; ELSIF gap=2 AND f>0 THEN s:=s+1; f:=f-1; ELSIF gap>1 THEN s:=1; END IF;
UPDATE public.profiles SET xp=xp+amount,streak_count=s,streak_freezes=f,last_active_date=today WHERE id=uid;
RETURN jsonb_build_object('xp',p.xp+amount);
END; $$;
REVOKE ALL ON FUNCTION public.add_study_xp(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.add_study_xp(integer) TO authenticated;