CREATE TABLE public.daily_drops (user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, day date NOT NULL, xp integer NOT NULL DEFAULT 20, PRIMARY KEY(user_id,day));
GRANT SELECT ON public.daily_drops TO authenticated;
GRANT ALL ON public.daily_drops TO service_role;
ALTER TABLE public.daily_drops ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own daily drops" ON public.daily_drops FOR SELECT TO authenticated USING(auth.uid()=user_id);
CREATE TABLE public.avatar_equipment (user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE, look jsonb NOT NULL DEFAULT '{}'::jsonb);
GRANT SELECT ON public.avatar_equipment TO authenticated;
GRANT ALL ON public.avatar_equipment TO service_role;
ALTER TABLE public.avatar_equipment ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own avatar equipment" ON public.avatar_equipment FOR SELECT TO authenticated USING(auth.uid()=user_id);
ALTER TABLE public.reward_inventory DROP CONSTRAINT IF EXISTS reward_inventory_item_check;
ALTER TABLE public.reward_inventory ADD CONSTRAINT reward_inventory_item_check CHECK(item IN ('shield','avatar-fox','sound-soft','hat-beanie','hat-crown','glasses-round','accessory-star','background-grid','theme-coral','theme-mint'));
CREATE OR REPLACE FUNCTION public.buy_reward(reward_item text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE uid uuid:=auth.uid(); price integer; earned integer; spent integer;
BEGIN
IF uid IS NULL THEN RAISE EXCEPTION 'Logga in först'; END IF;
price:=CASE reward_item WHEN 'shield' THEN 50 WHEN 'avatar-fox' THEN 100 WHEN 'sound-soft' THEN 75 WHEN 'hat-beanie' THEN 30 WHEN 'hat-crown' THEN 80 WHEN 'glasses-round' THEN 40 WHEN 'accessory-star' THEN 25 WHEN 'background-grid' THEN 35 WHEN 'theme-coral' THEN 45 WHEN 'theme-mint' THEN 45 END;
IF price IS NULL THEN RAISE EXCEPTION 'Okänd belöning'; END IF;
SELECT xp INTO earned FROM public.profiles WHERE id=uid FOR UPDATE;
IF earned IS NULL THEN RAISE EXCEPTION 'Profil saknas'; END IF;
SELECT coalesce(sum(cost),0) INTO spent FROM public.reward_inventory WHERE user_id=uid;
IF earned-spent<price THEN RETURN jsonb_build_object('error','Du behöver lite mer XP'); END IF;
IF reward_item<>'shield' AND EXISTS(SELECT 1 FROM public.reward_inventory WHERE user_id=uid AND item=reward_item) THEN RETURN jsonb_build_object('error','Redan upplåst'); END IF;
INSERT INTO public.reward_inventory(user_id,item,cost) VALUES(uid,reward_item,price);
IF reward_item='shield' THEN UPDATE public.profiles SET streak_freezes=streak_freezes+1 WHERE id=uid; END IF;
RETURN jsonb_build_object('ok',true);
END; $$;
REVOKE ALL ON FUNCTION public.buy_reward(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.buy_reward(text) TO authenticated;
CREATE FUNCTION public.equip_avatar(reward_item text, equipment_slot text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE uid uuid:=auth.uid(); expected text;
BEGIN
IF uid IS NULL THEN RAISE EXCEPTION 'Logga in först'; END IF;
PERFORM 1 FROM public.profiles WHERE id=uid FOR UPDATE;
IF equipment_slot NOT IN ('hat','glasses','accessory','background','theme') THEN RAISE EXCEPTION 'Okänd plats'; END IF;
IF reward_item<>'' THEN
expected:=CASE reward_item WHEN 'hat-beanie' THEN 'hat' WHEN 'hat-crown' THEN 'hat' WHEN 'glasses-round' THEN 'glasses' WHEN 'accessory-star' THEN 'accessory' WHEN 'background-grid' THEN 'background' WHEN 'theme-coral' THEN 'theme' WHEN 'theme-mint' THEN 'theme' END;
IF expected IS DISTINCT FROM equipment_slot OR NOT EXISTS(SELECT 1 FROM public.reward_inventory WHERE user_id=uid AND item=reward_item) THEN RETURN jsonb_build_object('error','Lås upp accessoaren först'); END IF;
END IF;
INSERT INTO public.avatar_equipment(user_id) VALUES(uid) ON CONFLICT DO NOTHING;
UPDATE public.avatar_equipment SET look=CASE WHEN reward_item='' THEN look-equipment_slot ELSE jsonb_set(look,ARRAY[equipment_slot],to_jsonb(reward_item),true) END WHERE user_id=uid;
UPDATE public.profiles SET avatar_url='reward:monster' WHERE id=uid;
RETURN jsonb_build_object('ok',true);
END; $$;
REVOKE ALL ON FUNCTION public.equip_avatar(text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.equip_avatar(text,text) TO authenticated;
CREATE FUNCTION public.add_study_xp(amount integer) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE uid uuid:=auth.uid(); p public.profiles; today date:=(now() AT TIME ZONE 'Europe/Stockholm')::date; gap integer; s integer; f integer;
BEGIN
IF uid IS NULL OR amount NOT IN (3,5,10,15,25) THEN RAISE EXCEPTION 'Ogiltig belöning'; END IF;
SELECT * INTO p FROM public.profiles WHERE id=uid FOR UPDATE;
IF NOT FOUND THEN RAISE EXCEPTION 'Profil saknas'; END IF;
gap:=today-p.last_active_date; s:=p.streak_count; f:=p.streak_freezes;
IF p.last_active_date IS NULL THEN s:=1; ELSIF gap=1 THEN s:=s+1; ELSIF gap=2 AND f>0 THEN s:=s+1; f:=f-1; ELSIF gap>1 THEN s:=1; END IF;
UPDATE public.profiles SET xp=xp+amount,streak_count=s,streak_freezes=f,last_active_date=today WHERE id=uid;
RETURN jsonb_build_object('xp',p.xp+amount);
END; $$;
REVOKE ALL ON FUNCTION public.add_study_xp(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.add_study_xp(integer) TO authenticated;
CREATE FUNCTION public.claim_daily_drop() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE uid uuid:=auth.uid(); today date:=(now() AT TIME ZONE 'Europe/Stockholm')::date; p public.profiles; gap integer; s integer; f integer;
BEGIN
IF uid IS NULL THEN RAISE EXCEPTION 'Logga in först'; END IF;
SELECT * INTO p FROM public.profiles WHERE id=uid FOR UPDATE;
IF NOT FOUND THEN RAISE EXCEPTION 'Profil saknas'; END IF;
IF EXISTS(SELECT 1 FROM public.daily_drops WHERE user_id=uid AND day=today) THEN RETURN jsonb_build_object('claimed',false,'xp',0); END IF;
INSERT INTO public.daily_drops(user_id,day,xp) VALUES(uid,today,20);
gap:=today-p.last_active_date; s:=p.streak_count; f:=p.streak_freezes;
IF p.last_active_date IS NULL THEN s:=1; ELSIF gap=1 THEN s:=s+1; ELSIF gap=2 AND f>0 THEN s:=s+1; f:=f-1; ELSIF gap>1 THEN s:=1; END IF;
UPDATE public.profiles SET xp=xp+20,streak_count=s,streak_freezes=f,last_active_date=today WHERE id=uid;
RETURN jsonb_build_object('claimed',true,'xp',20);
END; $$;
REVOKE ALL ON FUNCTION public.claim_daily_drop() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.claim_daily_drop() TO authenticated;