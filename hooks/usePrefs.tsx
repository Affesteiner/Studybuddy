import { createContext, useContext, useEffect, useState, type ReactNode } from "react";

type Prefs = { dark: boolean; dyslexic: boolean; focus: boolean; sound: boolean; motion: boolean };
type Ctx = Prefs & { calm: boolean; setCalm: (value: boolean) => void; toggle: (k: keyof Prefs) => void };
const DEFAULTS: Prefs = { dark: true, dyslexic: false, focus: false, sound: true, motion: true };
const PrefsContext = createContext<Ctx>({ ...DEFAULTS, calm: false, setCalm: () => {}, toggle: () => {} });

export function PrefsProvider({ children }: { children: ReactNode }) {
  const [p, setP] = useState<Prefs>(DEFAULTS);
  const [calm, setCalm] = useState(false);

  useEffect(() => {
    try {
      const saved = localStorage.getItem("kompis-prefs");
      if (saved) setP((x) => ({ ...x, ...JSON.parse(saved), focus: false }));
    } catch { /* ignore */ }
  }, []);

  useEffect(() => {
    const el = document.documentElement;
    el.classList.toggle("dark", p.dark);
    el.classList.toggle("dyslexic", p.dyslexic);
    el.classList.toggle("focus-mode", p.focus);
    el.classList.toggle("no-motion", !p.motion);
    const { focus: _f, ...keep } = p;
    localStorage.setItem("kompis-prefs", JSON.stringify(keep));
  }, [p]);

  return <PrefsContext.Provider value={{ ...p, sound: p.sound && !calm, motion: p.motion && !calm, calm, setCalm, toggle: (k) => setP((x) => ({ ...x, [k]: !x[k] })) }}>{children}</PrefsContext.Provider>;
}

export const usePrefs = () => useContext(PrefsContext);
