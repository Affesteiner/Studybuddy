alter table public.profiles add column if not exists xp integer not null default 0,
  add column if not exists streak_count integer not null default 0,
  add column if not exists streak_freezes integer not null default 2,
  add column if not exists last_active_date date;

create table public.study_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  title text not null,
  subject text,
  target_date date not null,
  frequency_per_week integer not null default 4,
  minutes_per_session integer not null default 15,
  tasks jsonb not null default '[]'::jsonb,
  reminders boolean not null default true,
  created_at timestamptz not null default now()
);
grant select, insert, update, delete on public.study_goals to authenticated;
grant all on public.study_goals to service_role;
alter table public.study_goals enable row level security;
create policy "goals own" on public.study_goals for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.library_documents (
  id uuid primary key default gen_random_uuid(),
  uploader_id uuid,
  title text not null,
  school_level text not null,
  subject text not null,
  topic text,
  keywords text[] not null default '{}',
  summary text not null default '',
  preview text not null default '',
  verified_by_ai boolean not null default false,
  created_at timestamptz not null default now()
);
grant select on public.library_documents to anon;
grant select, insert, delete on public.library_documents to authenticated;
grant all on public.library_documents to service_role;
alter table public.library_documents enable row level security;
create policy "library public read" on public.library_documents for select to anon, authenticated using (true);
create policy "library own insert" on public.library_documents for insert to authenticated with check (auth.uid() = uploader_id);
create policy "library own delete" on public.library_documents for delete to authenticated using (auth.uid() = uploader_id);

create table public.library_content (
  document_id uuid primary key references public.library_documents(id) on delete cascade,
  uploader_id uuid,
  content text not null
);
grant select, insert on public.library_content to authenticated;
grant all on public.library_content to service_role;
alter table public.library_content enable row level security;
create policy "members read content" on public.library_content for select to authenticated using (true);
create policy "own content insert" on public.library_content for insert to authenticated with check (auth.uid() = uploader_id);

with d as (
  insert into public.library_documents (title, school_level, subject, topic, keywords, summary, preview, verified_by_ai) values
  ('Franska revolutionen – sammanfattning', 'hogstadiet', 'SO', 'Historia', '{1789,Bastiljen,upplysningen}', 'Orsaker, förlopp och följder av franska revolutionen.', 'År 1789 var Frankrike i kris: staten var skuldsatt och bröd var dyrt.', true),
  ('Bråk och procent – grunderna', 'mellanstadiet', 'Matte', 'Bråk', '{bråk,procent,förlänga}', 'Hur bråk, decimaltal och procent hänger ihop.', '1/2 = 0,5 = 50 %. Ett bråk är en del av en helhet.', true),
  ('Linjär regression STK120', 'university', 'Statistik STK120', 'Regression', '{regression,minsta kvadrat,R2}', 'Minsta kvadrat-metoden, tolkning av koefficienter och R².', 'Modellen y = b0 + b1x + e skattas med minsta kvadrat-metoden.', true),
  ('Fotosyntesen enkelt förklarad', 'lagstadiet', 'NO', 'Biologi', '{växter,solljus,syre}', 'Hur växter gör mat av solljus.', 'Växter tar in solljus, vatten och koldioxid och gör socker och syre.', true),
  ('Engelska oregelbundna verb', 'gymnasium', 'Engelska', 'Grammatik', '{verb,past tense}', 'Lista och minnesknep för vanliga oregelbundna verb.', 'go – went – gone, see – saw – seen.', true)
  returning id, summary, preview
)
insert into public.library_content (document_id, content)
select id, preview || E'\n\n' || summary || E'\n\nHela materialet: läs, repetera och testa dig själv med flashcards i AI-Studion.' from d;