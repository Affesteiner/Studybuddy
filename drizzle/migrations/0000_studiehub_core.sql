create type public.app_role as enum ('student','tutor','seller','admin');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  points integer not null default 0,
  dyslexia_mode boolean not null default false,
  created_at timestamptz not null default now()
);
grant select, insert, update on public.profiles to authenticated;
grant all on public.profiles to service_role;
alter table public.profiles enable row level security;
create policy "own profile read" on public.profiles for select to authenticated using (auth.uid() = id);
create policy "own profile update" on public.profiles for update to authenticated using (auth.uid() = id);
create policy "own profile insert" on public.profiles for insert to authenticated with check (auth.uid() = id);

create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  role public.app_role not null,
  unique (user_id, role)
);
grant select on public.user_roles to authenticated;
grant all on public.user_roles to service_role;
alter table public.user_roles enable row level security;
create policy "own roles read" on public.user_roles for select to authenticated using (auth.uid() = user_id);

create or replace function public.has_role(_user_id uuid, _role public.app_role)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = _user_id and role = _role)
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email,'@',1)), new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing;
  insert into public.user_roles (user_id, role) values (new.id, 'student') on conflict do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  school_level text not null check (school_level in ('lagstadiet','mellanstadiet','hogstadiet','gymnasium','university')),
  subject_name text not null
);
grant select on public.categories to anon, authenticated;
grant all on public.categories to service_role;
alter table public.categories enable row level security;
create policy "categories public" on public.categories for select to anon, authenticated using (true);

create table public.tutor_listings (
  id uuid primary key default gen_random_uuid(),
  tutor_id uuid,
  display_name text not null,
  avatar_url text,
  bio text not null default '',
  hourly_rate integer not null check (hourly_rate between 50 and 5000),
  verified_grade text,
  subjects text[] not null default '{}',
  school_levels text[] not null default '{}',
  npf_experience boolean not null default false,
  rating numeric(2,1) not null default 5.0,
  reviews integer not null default 0,
  verified boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
grant select on public.tutor_listings to anon, authenticated;
grant insert, update, delete on public.tutor_listings to authenticated;
grant all on public.tutor_listings to service_role;
alter table public.tutor_listings enable row level security;
create policy "listings public" on public.tutor_listings for select to anon, authenticated using (active or auth.uid() = tutor_id);
create policy "listings own insert" on public.tutor_listings for insert to authenticated with check (auth.uid() = tutor_id and verified = false);
create policy "listings own update" on public.tutor_listings for update to authenticated using (auth.uid() = tutor_id) with check (auth.uid() = tutor_id);
create policy "listings own delete" on public.tutor_listings for delete to authenticated using (auth.uid() = tutor_id);

create table public.marketplace_items (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid,
  seller_name text not null,
  item_title text not null,
  description text not null default '',
  subject text not null,
  school_level text not null,
  category text not null check (category in ('notes','exam_solutions')),
  price integer not null check (price between 10 and 2000),
  file_path text,
  preview_text text not null default '',
  pages integer not null default 1,
  rating numeric(2,1) not null default 5.0,
  sales integer not null default 0,
  created_at timestamptz not null default now()
);
grant select on public.marketplace_items to anon, authenticated;
grant insert, update, delete on public.marketplace_items to authenticated;
grant all on public.marketplace_items to service_role;
alter table public.marketplace_items enable row level security;
create policy "items public" on public.marketplace_items for select to anon, authenticated using (true);
create policy "items own insert" on public.marketplace_items for insert to authenticated with check (auth.uid() = seller_id);
create policy "items own update" on public.marketplace_items for update to authenticated using (auth.uid() = seller_id) with check (auth.uid() = seller_id);
create policy "items own delete" on public.marketplace_items for delete to authenticated using (auth.uid() = seller_id);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null,
  tutor_listing_id uuid not null references public.tutor_listings(id) on delete cascade,
  scheduled_time timestamptz not null,
  hours integer not null default 1,
  price_total integer not null,
  platform_fee_amount integer not null,
  status text not null default 'pending' check (status in ('pending','paid','cancelled','completed')),
  stripe_session_id text,
  environment text not null default 'sandbox',
  created_at timestamptz not null default now()
);
grant select on public.bookings to authenticated;
grant all on public.bookings to service_role;
alter table public.bookings enable row level security;
create policy "bookings student read" on public.bookings for select to authenticated using (auth.uid() = student_id);
create policy "bookings tutor read" on public.bookings for select to authenticated using (exists (select 1 from public.tutor_listings t where t.id = tutor_listing_id and t.tutor_id = auth.uid()));

create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null,
  item_id uuid not null references public.marketplace_items(id) on delete cascade,
  amount integer not null,
  platform_fee_amount integer not null,
  status text not null default 'pending' check (status in ('pending','paid','failed')),
  stripe_session_id text,
  environment text not null default 'sandbox',
  created_at timestamptz not null default now()
);
grant select on public.purchases to authenticated;
grant all on public.purchases to service_role;
alter table public.purchases enable row level security;
create policy "purchases own read" on public.purchases for select to authenticated using (auth.uid() = buyer_id);

create table public.uploaded_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  path text not null,
  mime text not null,
  size integer not null,
  created_at timestamptz not null default now()
);
grant select, insert, delete on public.uploaded_documents to authenticated;
grant all on public.uploaded_documents to service_role;
alter table public.uploaded_documents enable row level security;
create policy "docs own" on public.uploaded_documents for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.generated_exams (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  kind text not null,
  title text not null,
  content text not null,
  created_at timestamptz not null default now()
);
grant select, delete on public.generated_exams to authenticated;
grant all on public.generated_exams to service_role;
alter table public.generated_exams enable row level security;
create policy "gen own read" on public.generated_exams for select to authenticated using (auth.uid() = user_id);
create policy "gen own delete" on public.generated_exams for delete to authenticated using (auth.uid() = user_id);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  stripe_subscription_id text not null unique,
  stripe_customer_id text not null,
  product_id text not null,
  price_id text not null,
  status text not null default 'active',
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean default false,
  environment text not null default 'sandbox',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index idx_subscriptions_user_id on public.subscriptions(user_id);
grant select on public.subscriptions to authenticated;
grant all on public.subscriptions to service_role;
alter table public.subscriptions enable row level security;
create policy "own subscription read" on public.subscriptions for select to authenticated using (auth.uid() = user_id);

create or replace function public.has_active_subscription(user_uuid uuid, check_env text default 'live')
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.subscriptions
    where user_id = user_uuid and environment = check_env
    and ((status in ('active','trialing','past_due') and (current_period_end is null or current_period_end > now()))
      or (status = 'canceled' and current_period_end > now()))
  );
$$;

insert into public.categories (school_level, subject_name) values
('lagstadiet','Matte'),('lagstadiet','Svenska'),('mellanstadiet','Matte'),('mellanstadiet','Engelska'),('mellanstadiet','NO'),
('hogstadiet','Matte'),('hogstadiet','SO'),('hogstadiet','NO'),('hogstadiet','Engelska'),('gymnasium','Matte'),('gymnasium','Fysik'),
('gymnasium','Ekonomi'),('gymnasium','Svenska'),('university','Statistik STK120'),('university','Statistik STK110'),('university','Ekonomi'),('university','Matematik');

insert into public.tutor_listings (display_name, avatar_url, bio, hourly_rate, verified_grade, subjects, school_levels, npf_experience, rating, reviews, verified) values
('Elin Johansson','https://i.pravatar.cc/240?img=47','Ekonomistudent på Handels i Göteborg. Jag förklarar regression steg för steg, utan stress.',320,'Fick A i STK120',array['Statistik STK120','Statistik STK110','Ekonomi'],array['university','gymnasium'],true,4.9,58,true),
('Omar Haddad','https://i.pravatar.cc/240?img=12','Civilingenjörsstudent. Matte och fysik för gymnasiet – med mycket övning och tydliga exempel.',280,'A i Matematik 5',array['Matte','Fysik'],array['gymnasium','hogstadiet'],false,4.8,41,true),
('Sara Lindqvist','https://i.pravatar.cc/240?img=32','Blivande lågstadielärare. Läsinlärning och tal-förståelse i lugnt tempo.',220,'Lärarstudent termin 6',array['Svenska','Matte'],array['lagstadiet','mellanstadiet'],true,5.0,33,true),
('Jonas Berg','https://i.pravatar.cc/240?img=68','Doktorand i nationalekonomi. Tentaplugg i STK110, ekonometri och mikroekonomi.',450,'VG i Ekonometri',array['Statistik STK110','Statistik STK120','Ekonomi'],array['university'],false,4.7,72,true),
('Amira Nilsson','https://i.pravatar.cc/240?img=45','Engelska och SO för högstadiet. Strukturerade läxpass för dig med ADHD eller dyslexi.',250,'A i Engelska 7',array['Engelska','SO'],array['hogstadiet','mellanstadiet'],true,4.9,27,true),
('Leo Andersson','https://i.pravatar.cc/240?img=15','NO och matte för mellanstadiet med experiment och vardagsexempel.',200,'Lärarstudent NO',array['NO','Matte'],array['mellanstadiet'],false,4.6,19,true);

insert into public.marketplace_items (seller_name, item_title, description, subject, school_level, category, price, preview_text, pages, rating, sales) values
('Elin J.','STK120 – Komplett formelsamling','Alla formler för regression, F-test, LPM och logit med tolkningsexempel.','Statistik STK120','university','notes',79,'## Multipel regression\n$$y = \\beta_0 + \\beta_1x_1 + \\dots + u$$\nTolka varje $b_j$ allt annat lika...',14,4.9,212),
('Jonas B.','STK110 – Lösta gamla tentor (2022–2025)','Åtta tentor med fullständiga steg-för-steg-lösningar.','Statistik STK110','university','exam_solutions',149,'**Uppgift 1a:** $z = \\frac{x-\\mu}{\\sigma} = 2{,}0$ ...',62,4.8,154),
('Omar H.','Matte 3c – Derivata & integraler','Sammanfattning med 40 lösta exempel.','Matte','gymnasium','notes',59,'Derivatan av $x^n$ är $nx^{n-1}$...',22,4.7,98),
('Amira N.','Engelska 7 – Essäguide','Struktur, länkord och bedömda exempel-essäer.','Engelska','hogstadiet','notes',39,'**Thesis statement:** Start with a clear claim...',10,4.9,77),
('Sara L.','Läsförståelse åk 2 – Övningshäfte','Korta texter med bildstöd och frågor.','Svenska','lagstadiet','notes',29,'Läs texten om katten Misse och svara...',16,5.0,45),
('Jonas B.','Ekonometri – Interaktioner & marginaleffekter','Fördjupning med plottar och tentauppgifter.','Statistik STK120','university','exam_solutions',99,'$$\\frac{\\partial y}{\\partial x} = b_1 + 2b_2x$$',28,4.8,88);
