-- ═══════════════════════════════════════════════════════════════════════
-- PORTAIL SUPER ADMIN — état des postes en direct, protégé côté serveur
-- ═══════════════════════════════════════════════════════════════════════
--
-- À exécuter dans Supabase → SQL Editor. Rejouable sans risque.
--
-- Ce que ce fichier corrige, avant même d'ajouter quoi que ce soit
-- ----------------------------------------------------------------
-- Vérifié le 24 septembre 2026, avec la seule clé anon — celle que tout
-- visiteur du tableau de bord reçoit dans `config.js` :
--
--   * `dashboard_owners` rendait le HACHAGE du mot de passe de Pamela.
--     Le site le comparait ensuite dans le navigateur : l'écran de
--     connexion ne protégeait donc rien, il décorait.
--   * `error_logs` rendait 214 journaux, traces techniques et requêtes
--     SQL comprises.
--   * `mirror_clients` rendait 45 clients avec leurs téléphones.
--
-- Même forme que la faille de septembre sur `bs_check_credentials` :
-- une donnée sensible accessible à qui possède une clé publique.
--
-- Le principe retenu
-- ------------------
-- Le portail ne lit AUCUNE table directement. Il appelle une fonction
-- qui vérifie elle-même les identifiants d'un super admin, puis renvoie
-- l'état. Posséder la clé anon ne suffit pas — il faut un mot de passe,
-- et il est vérifié sur le serveur, jamais dans le navigateur.

-- ── 1. Fermer ce qui n'aurait jamais dû être ouvert ────────────────────
alter table public.dashboard_owners enable row level security;
revoke all on public.dashboard_owners from anon, authenticated;

alter table public.error_logs enable row level security;
revoke all on public.error_logs from anon, authenticated;
-- L'application doit continuer à SIGNALER ses pannes : elle insère, elle
-- ne lit jamais. C'est le seul droit qu'on lui rend.
grant insert on public.error_logs to anon;

-- La connexion de Pamela ne doit PAS tomber pour autant : fermer la
-- table sans fournir le remplacement lui couperait l'accès. D'où la
-- fonction ci-dessous, qui fait côté serveur ce que le navigateur
-- faisait mal.

-- ── 1 bis. Connexion du tableau de bord, vérifiée sur le serveur ───────
-- Le mot de passe est comparé ICI. Le hachage ne quitte jamais la base,
-- et la réponse ne contient que de quoi afficher un nom.
create or replace function public.bs_portail_ouvrir(
  p_login text, p_password text
) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  o public.dashboard_owners;
  h text;
begin
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
  -- décrivent le même algorithme — seule l'étiquette diffère. Sans cette
  -- ligne, fermer la table enfermerait Pamela dehors, et on ne s'en
  -- apercevrait qu'au moment où elle essaierait de se connecter.
  h := o.password_hash;
  if h like '$2b$%' or h like '$2y$%' then
    h := '$2a$' || substring(h from 5);
  end if;

  -- Un seul bcrypt, sur le compte concerné. Filtrer par mot de passe
  -- dans le WHERE ferait évaluer crypt() sur chaque ligne — c'est ce qui
  -- a fait expirer les connexions de l'application le 19 septembre.
  if h <> extensions.crypt(p_password, h) then
    return json_build_object('status', 'refuse');
  end if;

  update public.dashboard_owners set last_login = now() where id = o.id;

  return json_build_object(
    'status', 'ok',
    'login', o.login,
    'full_name', o.full_name
  );
end;
$$;

revoke execute on function public.bs_portail_ouvrir(text, text) from public;
grant execute on function public.bs_portail_ouvrir(text, text) to anon;

-- ── 2. Registre des postes ─────────────────────────────────────────────
-- Rien ne disait jusqu'ici quels postes existent, lequel tourne, quelle
-- version il porte. Diagnostiquer une panne revenait à arrêter une
-- application pour voir si les erreurs cessaient — méthode qui m'a
-- donné une conclusion fausse le 24 septembre.
create table if not exists public.app_postes (
  nom              text primary key,        -- nom de machine Windows
  version          text,
  derniere_vue     timestamptz not null default now(),
  -- Dérive de l'horloge en secondes, mesurée par le poste. Positif : il
  -- avance. C'est ce qui a décalé 163 ventes de deux heures.
  derive_secondes  int,
  ventes_en_attente int not null default 0,
  stock_en_attente  int not null default 0,
  dernier_login    text
);

alter table public.app_postes enable row level security;
revoke all on public.app_postes from anon, authenticated;

-- ── 3. Le poste signale son état ───────────────────────────────────────
-- Exige des identifiants valides : sans ça, n'importe qui muni de la clé
-- anon pourrait inventer des postes et brouiller le tableau.
create or replace function public.bs_heartbeat(
  p_login text,
  p_password text,
  p_poste text,
  p_version text,
  p_derive_secondes int default null,
  p_ventes_en_attente int default 0,
  p_stock_en_attente int default 0
) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare u public.app_users;
begin
  u := public.bs_check_credentials(p_login, p_password);
  if u.id is null then
    raise exception 'IDENTIFIANTS_INVALIDES';
  end if;
  if p_poste is null or length(trim(p_poste)) = 0 then
    raise exception 'POSTE_MANQUANT';
  end if;

  insert into public.app_postes as p
    (nom, version, derniere_vue, derive_secondes,
     ventes_en_attente, stock_en_attente, dernier_login)
  values (trim(p_poste), p_version, now(), p_derive_secondes,
          coalesce(p_ventes_en_attente, 0), coalesce(p_stock_en_attente, 0),
          u.login)
  on conflict (nom) do update set
    version           = excluded.version,
    derniere_vue      = now(),
    derive_secondes   = excluded.derive_secondes,
    ventes_en_attente = excluded.ventes_en_attente,
    stock_en_attente  = excluded.stock_en_attente,
    dernier_login     = excluded.dernier_login;

  return json_build_object('status', 'ok');
end;
$$;

-- ── 4. Le portail : tout l'état, pour un super admin seulement ─────────
create or replace function public.bs_portail_etat(
  p_login text, p_password text
) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  u public.app_users;
  resultat json;
begin
  u := public.bs_check_credentials(p_login, p_password);
  if u.id is null then
    raise exception 'IDENTIFIANTS_INVALIDES';
  end if;
  -- SUPER ADMIN uniquement. Un gérant a déjà tout ce qu'il lui faut dans
  -- l'application ; ce portail expose les journaux d'erreurs et l'état
  -- technique des machines, qui ne le concernent pas.
  if u.role <> 0 then
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
               -- probablement éteint ou hors ligne.
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

    -- Les erreurs récentes, regroupées : cent lignes identiques
    -- n'apprennent rien de plus que la première et son décompte.
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

    -- Les ventes du jour, à l'heure de Lubumbashi (UTC+2), pas à celle
    -- du serveur : c'est la journée commerciale qui compte.
    'ventes_du_jour', (
      select json_build_object(
        'nombre', count(distinct s.id),
        'total_cents', coalesce(sum(l.qty * l.unit_price_cents), 0),
        'a_recouvrer_cents', coalesce(sum(
          case when s.on_credit and s.settled_at is null
               then l.qty * l.unit_price_cents else 0 end), 0)
      )
      from public.mirror_sales s
      left join public.mirror_sale_lines l on l.sale_id = s.id
      where s.sold_at >= date_trunc('day', now() + interval '2 hours')
                        - interval '2 hours'
    )
  ) into resultat;

  return resultat;
end;
$$;

-- ── 5. Droits ──────────────────────────────────────────────────────────
-- PUBLIC d'abord : sans ça le revoke ne retire rien. PostgreSQL accorde
-- EXECUTE à PUBLIC sur toute fonction neuve — c'est exactement ce qui
-- avait ouvert la faille de septembre.
revoke execute on function public.bs_portail_etat(text, text) from public;
revoke execute on function public.bs_heartbeat(
  text, text, text, text, int, int, int) from public;

-- On accorde à anon : ces deux fonctions vérifient elles-mêmes qui les
-- appelle. C'est le même contrat que `bs_verify_login`.
grant execute on function public.bs_portail_etat(text, text) to anon;
grant execute on function public.bs_heartbeat(
  text, text, text, text, int, int, int) to anon;

notify pgrst, 'reload schema';

-- ── 6. Contrôle ────────────────────────────────────────────────────────
-- Avec la seule clé anon, ces deux appels doivent ÉCHOUER :
--
--   select * from public.dashboard_owners;          -- refusé
--   select public.bs_portail_etat('kenny', 'faux'); -- IDENTIFIANTS_INVALIDES
--
-- Et celui-ci doit renvoyer l'état complet :
--
--   select public.bs_portail_etat('kenny', '<ton mot de passe>');
