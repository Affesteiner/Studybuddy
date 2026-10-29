import { useCallback } from "react";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/useAuth";
import { usePrefs } from "@/hooks/usePrefs";
import { burst, playTone } from "@/lib/feedback";
import { levelFromXp, PEP } from "@/lib/rewards";

export function useRewards() {
  const { user, profile, refreshProfile } = useAuth();
  const { sound, motion } = usePrefs();
  const celebrate = useCallback((label: string) => {
    if (sound) playTone("success");
    if (motion && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) burst(label);
  }, [sound, motion]);

  const award = useCallback(async (xp: number, reason?: string) => {
    const before = profile?.xp ?? 0;
    const leveled = levelFromXp(before + xp).level > levelFromXp(before).level;
    if (sound) playTone(leveled ? "levelup" : "success");
    if (motion && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) burst(`+${xp} XP`);
    toast.success(leveled ? `Ny nivå: ${levelFromXp(before + xp).level}! 🎉` : (PEP[Math.floor(Math.random() * PEP.length)] ?? "Snyggt jobbat!"), { description: reason });
    if (!user) return;
    const { error } = await supabase.rpc("add_study_xp", { amount: xp });
    if (error) toast.error("Dina XP kunde inte sparas just nu.");
    refreshProfile();
  }, [user, profile, sound, motion, refreshProfile]);

  const click = useCallback(() => { if (sound) playTone("click"); }, [sound]);
  return { award, click, celebrate };
}
