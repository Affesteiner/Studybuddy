CREATE TABLE public.reward_inventory (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, item text NOT NULL CHECK (item IN ('shield','avatar-fox','sound-soft')), cost integer NOT NULL CHECK (cost > 0), created_at timestamptz NOT NULL DEFAULT now());
GRANT SELECT ON public.reward_inventory TO authenticated;
GRANT ALL ON public.reward_inventory TO service_role;
ALTER TABLE public.reward_inventory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "inventory own read" ON public.reward_inventory FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE OR REPLACE FUNCTION public.buy_reward(reward_item text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid uuid := auth.uid(); price integer; earned integer; spent integer;
BEGIN
IF uid IS NULL THEN RAISE EXCEPTION 'Logga in först'; END IF;
price := CASE reward_item WHEN 'shield' THEN 50 WHEN 'avatar-fox' THEN 100 WHEN 'sound-soft' THEN 75 ELSE NULL END;
IF price IS NULL THEN RAISE EXCEPTION 'Okänd belöning'; END IF;
SELECT xp INTO earned FROM public.profiles WHERE id = uid FOR UPDATE;
IF earned IS NULL THEN RAISE EXCEPTION 'Profil saknas'; END IF;
SELECT coalesce(sum(cost),0) INTO spent FROM public.reward_inventory WHERE user_id=uid;
IF earned-spent < price THEN RETURN jsonb_build_object('error','Du behöver lite mer XP'); END IF;
IF reward_item <> 'shield' AND EXISTS(SELECT 1 FROM public.reward_inventory WHERE user_id=uid AND item=reward_item) THEN RETURN jsonb_build_object('error','Redan upplåst'); END IF;
INSERT INTO public.reward_inventory(user_id,item,cost) VALUES(uid,reward_item,price);
IF reward_item='shield' THEN UPDATE public.profiles SET streak_freezes=streak_freezes+1 WHERE id=uid; END IF;
RETURN jsonb_build_object('ok',true);
END; $$;
REVOKE ALL ON FUNCTION public.buy_reward(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.buy_reward(text) TO authenticated;