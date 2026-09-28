-- ═══════════════════════════════════════════════════════════════════════
-- REPRISE DES COMPTES EXISTANTS → Supabase (app_users)
-- ═══════════════════════════════════════════════════════════════════════
--
-- À exécuter APRÈS sql/2026_09_comptes_supabase.sql.
--
-- Pourquoi ce fichier
-- -------------------
-- Avant la bascule, les comptes vivaient dans la base SQLite de chaque
-- poste. Leur mot de passe y est stocké en bcrypt `$2a$` — précisément le
-- format que `crypt()` sait vérifier. On peut donc **recopier les hashs
-- tels quels** : personne ne change de mot de passe, et aucun mot de
-- passe en clair ne transite nulle part.
--
-- Comment ça se déroule
-- ---------------------
--   1. Ici, dans le SQL Editor : `select public.bs_new_import_token();`
--      → un jeton à usage unique, valable 60 minutes.
--   2. Dans l'app, sur le poste QUI FAIT RÉFÉRENCE (celui dont la liste
--      de comptes est la bonne) : écran Comptes → « Reprise vers le
--      serveur », coller le jeton, lancer.
--   3. L'app affiche ligne par ligne ce qui a été importé ou ignoré.
--
-- Le jeton est nécessaire parce qu'au moment de la reprise il n'existe
-- pas encore d'admin sur le serveur pour autoriser l'opération. Un super
-- admin déjà en place peut aussi autoriser l'import avec ses propres
-- identifiants, sans jeton.
--
-- Idempotent : rejouable. Un login déjà présent sur le serveur n'est
-- jamais écrasé — on ne veut pas qu'une reprise relancée par erreur
-- remette un ancien mot de passe en service.

-- ── 1. Jetons de reprise (usage unique, courte durée) ──────────────────
create table if not exists public.app_import_tokens (
  token      text primary key,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at    timestamptz,
  used_count int not null default 0
);

alter table public.app_import_tokens enable row level security;
revoke all on public.app_import_tokens from anon, authenticated;

-- Génère un jeton de reprise valable p_minutes minutes.
-- À exécuter DEPUIS LE SQL EDITOR uniquement (droit retiré à anon).
create or replace function public.bs_new_import_token(p_minutes int default 60)
returns text
language plpgsql security definer set search_path = public, extensions as $$
declare t text;
begin
  t := encode(gen_random_bytes(18), 'base64');
  -- Base64 URL-safe : le jeton se recopie à la main dans l'app.
  t := replace(replace(replace(t, '+', '-'), '/', '_'), '=', '');
  insert into public.app_import_tokens (token, expires_at)
  values (t, now() + make_interval(mins => p_minutes));
  return t;
end;
$$;
-- PUBLIC compris : sans ça, n'importe qui muni de la clé anon peut
-- se fabriquer un jeton, puis créer un compte super admin via
-- bs_import_account. Ce jeton ne se génère QUE depuis le SQL Editor.
revoke execute on function public.bs_new_import_token(int) from public, anon, authenticated;

-- ── 2. Import d'un compte, hash inclus ─────────────────────────────────
--
-- Autorisé si :
--   * un jeton valide et non expiré est fourni, OU
--   * les identifiants d'un super admin existant sont fournis.
--
-- Un jeton reste utilisable jusqu'à son expiration : une reprise
-- comporte plusieurs comptes, on ne va pas régénérer un jeton par ligne.
create or replace function public.bs_import_account(
  p_token          text,
  p_actor_login    text,
  p_actor_password text,
  p_login          text,
  p_full_name      text,
  p_password_hash  text,
  p_role           smallint,
  p_active         boolean,
  p_created_at     timestamptz,
  p_last_login     timestamptz
) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  tok   public.app_import_tokens;
  actor public.app_users;
  hash  text;
begin
  -- ── Autorisation ────────────────────────────────────────────────────
  if p_token is not null and length(trim(p_token)) > 0 then
    select * into tok from public.app_import_tokens
     where token = trim(p_token);
    if tok.token is null then
      raise exception 'JETON_INVALIDE';
    end if;
    if tok.expires_at < now() then
      raise exception 'JETON_EXPIRE';
    end if;
  else
    actor := public.bs_check_credentials(p_actor_login, p_actor_password);
    if actor.id is null then
      raise exception 'IDENTIFIANTS_ADMIN_INVALIDES';
    end if;
    if actor.role <> 0 then
      raise exception 'DROITS_INSUFFISANTS';
    end if;
  end if;

  -- ── Validation du hash ──────────────────────────────────────────────
  hash := trim(p_password_hash);
  -- `$2b$` / `$2y$` sont le même algorithme que `$2a$` (la différence ne
  -- concerne que les mots de passe de plus de 255 octets, cas qui
  -- n'existe pas ici). pgcrypto ne connaît que `$2a$` : on normalise.
  if hash like '$2b$%' or hash like '$2y$%' then
    hash := '$2a$' || substring(hash from 5);
  end if;
  if hash not like '$2a$%' or length(hash) < 55 then
    raise exception 'HASH_INVALIDE';
  end if;

  -- ── Insertion ───────────────────────────────────────────────────────
  if exists (select 1 from public.app_users
              where lower(login) = lower(trim(p_login))) then
    return json_build_object('status', 'skipped', 'reason', 'deja_present');
  end if;

  insert into public.app_users
    (login, full_name, password_hash, role, active, created_at, last_login)
  values
    (trim(p_login), trim(p_full_name), hash,
     coalesce(p_role, 2), coalesce(p_active, true),
     coalesce(p_created_at, now()), p_last_login);

  if tok.token is not null then
    update public.app_import_tokens
       set used_at = now(), used_count = used_count + 1
     where token = tok.token;
  end if;

  return json_build_object('status', 'imported');
end;
$$;

revoke execute on function public.bs_import_account(
  text, text, text, text, text, text, smallint, boolean,
  timestamptz, timestamptz) from public;
grant execute on function public.bs_import_account(
  text, text, text, text, text, text, smallint, boolean,
  timestamptz, timestamptz) to anon, authenticated;

-- ── 3. Vérification de la reprise ──────────────────────────────────────
-- Après import, contrôle depuis le SQL Editor :
--
--   select login, full_name, role, active,
--          left(password_hash, 4) as prefixe, last_login
--   from   public.app_users
--   order  by role, login;
--
-- `prefixe` doit valoir `$2a$` partout. Teste ensuite une vraie
-- connexion pour au moins un compte repris :
--
--   select public.bs_verify_login('sabrina', 'son-mot-de-passe');
--   -- attendu : {"status":"ok", ...}

-- ── 4. Ménage après la bascule ─────────────────────────────────────────
-- Une fois la reprise validée sur tous les postes :
--
--   delete from public.app_import_tokens;         -- jetons consommés
--   -- drop table if exists public.mirror_users;  -- ancien miroir

notify pgrst, 'reload schema';
