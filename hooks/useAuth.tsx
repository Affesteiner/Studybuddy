import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/integrations/supabase/client";
import { parseAvatarLook, type AvatarLook } from "@/lib/rewards";

type Profile = { display_name: string | null; avatar_url: string | null; points: number; xp: number; streak_count: number; streak_freezes: number; last_active_date: string | null };
type Ctx = { user: User | null; session: Session | null; profile: Profile | null; avatarLook: AvatarLook; loading: boolean; refreshProfile: () => void };

const AuthContext = createContext<Ctx>({ user: null, session: null, profile: null, avatarLook: {}, loading: true, refreshProfile: () => {} });

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [tick, setTick] = useState(0);
  const [avatarLook, setAvatarLook] = useState<AvatarLook>({});

  useEffect(() => {
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s));
    supabase.auth.getSession().then(({ data }) => { setSession(data.session); setLoading(false); });
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session?.user) { setProfile(null); setAvatarLook({}); return; }
    supabase.from("profiles").select("display_name, avatar_url, points, xp, streak_count, streak_freezes, last_active_date").eq("id", session.user.id).maybeSingle()
      .then(({ data }) => setProfile(data));
    supabase.from("avatar_equipment").select("look").eq("user_id", session.user.id).maybeSingle().then(({ data }) => setAvatarLook(parseAvatarLook(data?.look)));
  }, [session?.user?.id, tick]);

  return (
    <AuthContext.Provider value={{ user: session?.user ?? null, session, profile, avatarLook, loading, refreshProfile: () => setTick((t) => t + 1) }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
