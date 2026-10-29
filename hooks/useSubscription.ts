import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { getStripeEnvironment } from "@/lib/stripe";
import { useAuth } from "./useAuth";

export function useSubscription() {
  const { user } = useAuth();
  const [isPro, setIsPro] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!user) { setIsPro(false); setLoading(false); return; }
    let env: "sandbox" | "live";
    try { env = getStripeEnvironment(); } catch { setLoading(false); return; }
    const load = () =>
      supabase.from("subscriptions").select("status, current_period_end").eq("user_id", user.id).eq("environment", env)
        .order("created_at", { ascending: false }).limit(1).maybeSingle()
        .then(({ data }) => {
          const future = !data?.current_period_end || new Date(data.current_period_end) > new Date();
          setIsPro(!!data && ((["active", "trialing", "past_due"].includes(data.status) && future) || (data.status === "canceled" && !!data.current_period_end && future)));
          setLoading(false);
        });
    load();
    const ch = supabase.channel(`subs-${Math.random().toString(36).slice(2)}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "subscriptions", filter: `user_id=eq.${user.id}` }, load).subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [user?.id]);

  return { isPro, loading };
}
