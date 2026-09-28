-- ═══════════════════════════════════════════════════════════════════════
-- SESSIONS DU SITE — jetons délivrés par le serveur
-- ═══════════════════════════════════════════════════════════════════════
--
-- À exécuter APRÈS `2026_09_portail_super_admin.sql`. Rejouable.
--
-- Pourquoi un jeton plutôt que le mot de passe
-- --------------------------------------------
-- Le portail rafraîchit son état toutes les trente secondes, et on ne
-- veut pas retaper son mot de passe à chaque rechargement de page. La
-- solution paresseuse serait de le garder dans le navigateur. C'est
-- exactement ce qu'il ne faut pas faire : un mot de passe de super admin
-- rangé dans `localStorage` est lisible par n'importe quelle extension,
-- et survit à la fermeture de l'onglet.
--
-- Un jeton, lui, est une chaîne aléatoire sans valeur ailleurs : il
-- expire, il se révoque, et le voler ne donne pas le mot de passe.
--
-- Le mot de passe ne traverse donc le réseau qu'UNE fois, à la connexion.

-- ── 1. Les sessions ────────────────────────────────────────────────────
create table if not exists public.app_portal_sessions (
  token      text primary key,
  login      text        not null,
  role       smallint    not null,
  -- 0 = compte applicatif (app_users), 1 = propriétaire du site
  -- (dashboard_owners). Les deux mondes ont leurs propres comptes.
  origine    smallint    not null default 0,
  cree_le    timestamptz not null default now(),
  expire_le  timestamptz not null,
  dernier_usage timestamptz not null default now()
);

create index if not exists app_portal_sessions_expire_idx
  on public.app_portal_sessions (expire_le);

alter table public.app_portal_sessions enable row level security;
revoke all on public.app_portal_sessions from anon, authenticated;

-- ── 2. Ouvrir une session ──────────────────────────────────────────────
-- Accepte les DEUX familles de comptes :
--   * `app_users`        → l'équipe, dont les super admins ;
--   * `dashboard_owners` → Pamela, propriétaire du site.
--
-- Pamela garde son site exactement comme avant : la fonction lui rend
-- une session valide, et son tableau de bord continue de lire ce qu'il
-- lisait. Ce sont les données TECHNIQUES qui exigent un super admin.
create or replace function public.bs_session_ouvrir(
  p_login text, p_password text
) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  u   public.app_users;
  o   public.dashboard_owners;
  h   text;
  jeton text;
  duree constant interval := interval '12 hours';
  v_role smallint;
  v_nom  text;
  v_origine smallint;
begin
  -- D'abord l'équipe.
  u := public.bs_check_credentials(p_login, p_password);
  if u.id is not null then
    v_role := u.role;
    v_nom  := u.full_name;
    v_origine := 0;
  else
    -- Puis les propriétaires du site.
    select * into o
      from public.dashboard_owners
     where lower(login) = lower(trim(p_login))
     limit 1;

    if o.id is null or o.active is false or o.password_hash is null then
      return json_build_object('status', 'refuse');
    end if;

    -- Normalisation du préfixe bcrypt, comme le faisait le navigateur.
    -- Les hachages stockés ici sont en `$2b$` ; selon la version de
    -- pgcrypto, `crypt()` ne reconnaît que `$2a$`. Les trois variantes
    -- décrivent le même algorithme — seule l'étiquette diffère. Sans
    -- cette ligne, Pamela se retrouverait dehors et on ne s'en
    -- apercevrait qu'au moment où elle essaierait de se connecter.
    h := o.password_hash;
    if h like '$2b$%' or h like '$2y$%' then
      h := '$2a$' || substring(h from 5);
    end if;
    if h <> extensions.crypt(p_password, h) then
      return json_build_object('status', 'refuse');
    end if;

    update public.dashboard_owners set last_login = now() where id = o.id;
    v_role := 0;
    v_nom  := o.full_name;
    v_origine := 1;
  end if;

  -- Ménage : une table de sessions qui ne se purge pas finit par peser.
  delete from public.app_portal_sessions where expire_le < now();

  -- 32 octets aléatoires. Pas un identifiant devinable, pas un compteur.
  jeton := encode(extensions.gen_random_bytes(32), 'hex');
  insert into public.app_portal_sessions
    (token, login, role, origine, expire_le)
  values (jeton, coalesce(u.login, o.login), v_role, v_origine,
          now() + duree);

  return json_build_object(
    'status', 'ok',
    'token', jeton,
    'expire_le', now() + duree,
    'login', coalesce(u.login, o.login),
    'full_name', v_nom,
    'role', v_role,
    'origine', v_origine
  );
end;
$$;

-- ── 3. Valider un jeton ────────────────────────────────────────────────
-- Interne : jamais accordée à anon. Les fonctions publiques s'en servent.
create or replace function public.bs_session_valider(p_token text)
returns public.app_portal_sessions
language plpgsql security definer set search_path = public, extensions as $$
declare s public.app_portal_sessions;
begin
  select * into s from public.app_portal_sessions
   where token = p_token and expire_le > now();
  if s.token is null then
    return null;
  end if;
  update public.app_portal_sessions
     set dernier_usage = now() where token = p_token;
  return s;
end;
$$;

-- ── 4. Fermer une session ──────────────────────────────────────────────
create or replace function public.bs_session_fermer(p_token text)
returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  delete from public.app_portal_sessions where token = p_token;
  return json_build_object('status', 'ok');
end;
$$;

-- ── 5. L'état technique, contre un jeton de SUPER ADMIN ────────────────
-- Remplace `bs_portail_etat(login, password)`.
create or replace function public.bs_portail_etat(p_token text)
returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  s public.app_portal_sessions;
  resultat json;
begin
  s := public.bs_session_valider(p_token);
  if s.token is null then
    raise exception 'SESSION_EXPIREE';
  end if;
  -- Super admin de l'ÉQUIPE uniquement (origine 0, rôle 0).
  --
  -- Pamela est propriétaire, pas administratrice technique : les
  -- journaux d'erreurs et l'état des machines ne lui apprendraient rien
  -- et l'inquiéteraient pour des pannes déjà réglées.
  if s.origine <> 0 or s.role <> 0 then
    raise exception 'RESERVE_AU_SUPER_ADMIN';
  end if;

  select json_build_object(
    'genere_le', now(),

    'postes', coalesce((
      select json_agg(row_to_json(p) order by p.derniere_vue desc)
      from (
        select nom, version, derniere_vue, derive_secondes,
               ventes_en_attente, stock_en_attente, dernier_login,
               -- Un poste qu'on n'a pas vu depuis dix minutes est
               -- probablement éteint ou hors ligne. C'est le double de
               -- l'intervalle de battement : un signal manqué ne doit
               -- pas déclencher d'alarme.
               (now() - derniere_vue) < interval '10 minutes' as en_ligne
        from public.app_postes
      ) p
    ), '[]'::json),

    'comptes', coalesce((
      select json_agg(row_to_json(c) order by c.role, c.login)
      from (
        select login, full_name, role, active, last_login
        from public.app_users
      ) c
    ), '[]'::json),

    -- Les erreurs regroupées : cent lignes identiques n'apprennent rien
    -- de plus que la première et son décompte.
    'erreurs', coalesce((
      select json_agg(row_to_json(e) order by e.derniere desc)
      from (
        select split_part(message, E'\n', 1) as message,
               context,
               coalesce(poste, 'inconnu') as poste,
               count(*)          as occurrences,
               max(occurred_at)  as derniere
        from public.error_logs
        where occurred_at > now() - interval '7 days'
        group by 1, 2, 3
        order by max(occurred_at) desc
        limit 30
      ) e
    ), '[]'::json),

    'chambres', coalesce((
      select json_agg(row_to_json(r) order by r.number)
      from (
        select number, type, status, current_guest, checkout_date,
               price_usd_cents, price_per_night_cents
        from public.mirror_rooms
      ) r
    ), '[]'::json),

    'stock_bas', coalesce((
      select json_agg(row_to_json(a) order by a.stock_qty)
      from (
        select name, stock_qty, threshold, unit
        from public.mirror_articles
        where track_stock and stock_qty <= threshold
        order by stock_qty
        limit 40
      ) a
    ), '[]'::json),

    -- Les ventes de la journée COMMERCIALE de Lubumbashi (UTC+2), pas
    -- celle du serveur : une vente de 23 h appartient au jour même.
    'ventes_du_jour', (
      select json_build_object(
        'nombre', count(distinct s2.id),
        'total_cents', coalesce(sum(l.qty * l.unit_price_cents), 0),
        'a_recouvrer_cents', coalesce(sum(
          case when s2.on_credit and s2.settled_at is null
               then l.qty * l.unit_price_cents else 0 end), 0)
      )
      from public.mirror_sales s2
      left join public.mirror_sale_lines l on l.sale_id = s2.id
      where s2.sold_at >= date_trunc('day', now() + interval '2 hours')
                         - interval '2 hours'
    )
  ) into resultat;

  return resultat;
end;
$$;

-- ── 6. Droits ──────────────────────────────────────────────────────────
-- PUBLIC d'abord : sans ça le revoke ne retire rien. PostgreSQL accorde
-- EXECUTE à PUBLIC sur toute fonction neuve — c'est exactement ce qui
-- avait ouvert la faille de septembre.
revoke execute on function public.bs_session_ouvrir(text, text) from public;
revoke execute on function public.bs_session_fermer(text) from public;
revoke execute on function public.bs_portail_etat(text) from public;
-- Jamais exposée : c'est un rouage interne, pas une porte.
revoke execute on function public.bs_session_valider(text)
  from public, anon, authenticated;

grant execute on function public.bs_session_ouvrir(text, text) to anon;
grant execute on function public.bs_session_fermer(text) to anon;
grant execute on function public.bs_portail_etat(text) to anon;

-- L'ancienne signature (login, password) disparaît : garder les deux
-- laisserait une porte qui accepte un mot de passe à chaque appel.
drop function if exists public.bs_portail_etat(text, text);
drop function if exists public.bs_portail_ouvrir(text, text);

notify pgrst, 'reload schema';

-- ── 7. Contrôle ────────────────────────────────────────────────────────
-- Avec la seule clé anon :
--
--   select public.bs_portail_etat('nimporte_quoi');   -- SESSION_EXPIREE
--   select public.bs_session_ouvrir('kenny', 'faux'); -- {"status":"refuse"}
--
-- Et le chemin normal :
--
--   select public.bs_session_ouvrir('kenny', '<ton mot de passe>');
--   -- récupère le token, puis :
--   select public.bs_portail_etat('<le token>');
--
-- Avec le compte de Pamela, la session s'ouvre mais le portail refuse :
-- c'est voulu.
