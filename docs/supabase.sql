-- Base de données Supabase de l'appli Rencontres
-- À coller dans Supabase : SQL Editor › New query › Run.

-- Un profil par compte. device_id est l'identifiant envoyé en Bluetooth :
-- il est le même sur tous les appareils d'un compte (Mac, iPhone, Thor…).
create table if not exists public.profiles (
  user_id    uuid primary key references auth.users on delete cascade,
  device_id  uuid not null default gen_random_uuid(),
  pseudo     text not null default '' check (octet_length(pseudo) <= 32),
  game       text not null default '' check (octet_length(game) <= 48),
  message    text not null default '' check (octet_length(message) <= 120),
  recipe     smallint[] not null default '{0,0,0,0,0,0,0,0,0,0,1}',
  updated_at timestamptz not null default now()
);

-- Les rencontres de chaque compte (une ligne par personne croisée).
create table if not exists public.encounters (
  user_id        uuid not null references auth.users on delete cascade,
  peer_device_id uuid not null,
  pseudo         text not null default '',
  game           text not null default '',
  message        text not null default '',
  recipe         smallint[] not null default '{}',
  first_met      timestamptz not null default now(),
  last_met       timestamptz not null default now(),
  count          integer not null default 1,
  primary key (user_id, peer_device_id)
);

-- Chacun ne voit et ne modifie que ses propres données.
alter table public.profiles   enable row level security;
alter table public.encounters enable row level security;

drop policy if exists "mon profil" on public.profiles;
create policy "mon profil" on public.profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "mes rencontres" on public.encounters;
create policy "mes rencontres" on public.encounters
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Enregistre une rencontre venant de n'importe quel appareil du compte.
-- Le serveur applique lui-même le délai anti-doublon : si ton Mac et ton iPhone
-- croisent la même personne en même temps, elle n'est comptée qu'une fois.
create or replace function public.record_encounter(
  p_peer uuid, p_pseudo text, p_game text, p_message text,
  p_recipe smallint[], p_met timestamptz, p_cooldown integer
) returns void
language plpgsql security invoker as $$
begin
  insert into public.encounters (user_id, peer_device_id, pseudo, game, message, recipe, first_met, last_met, count)
  values (auth.uid(), p_peer, p_pseudo, p_game, p_message, p_recipe, p_met, p_met, 1)
  on conflict (user_id, peer_device_id) do update set
    pseudo   = excluded.pseudo,
    game     = excluded.game,
    message  = excluded.message,
    recipe   = excluded.recipe,
    count    = public.encounters.count
               + case when p_met - public.encounters.last_met >= make_interval(secs => p_cooldown) then 1 else 0 end,
    last_met = greatest(public.encounters.last_met, p_met);
end $$;

grant execute on function public.record_encounter to authenticated;
