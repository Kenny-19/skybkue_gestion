-- ═══════════════════════════════════════════════════════════════════════
-- QUI ENTRE DANS LE PORTAIL — une autorisation explicite, pas un rôle
-- ═══════════════════════════════════════════════════════════════════════
--
-- À exécuter APRÈS `2026_09_portail_sessions.sql`. Rejouable.
--
-- Le défaut que ça corrige
-- ------------------------
-- Le portail vérifiait « rôle = super admin ». Ça paraissait suffisant.
-- Ça ne l'était pas : Pamela possède DEUX comptes — propriétaire du site
-- dans `dashboard_owners`, et super admin dans `app_users`. Avec ce
-- second jeu d'identifiants, elle serait entrée dans le portail
-- technique, journaux d'erreurs compris.
--
-- La leçon vaut au-delà de ce cas : déduire une autorisation d'un rôle
-- revient à espérer que personne n'aura jamais deux casquettes. Une
-- autorisation se donne, elle ne se devine pas.
--
-- D'où une colonne dédiée, à FAUX par défaut. Créer un compte super
-- admin n'ouvre plus le portail ; il faut le dire.

alter table public.app_users
  add column if not exists acces_portail boolean not null default false;

-- ⚠ À TOI DE JOUER : personne n'a l'accès tant que tu ne l'accordes pas.
--   Décommente et ajuste la liste — elle doit rester courte.
--
-- update public.app_users
--    set acces_portail = true
--  where lower(login) in ('kenny');

-- ── Le portail exige désormais cette autorisation ──────────────────────
create or replace function public.bs_portail_etat(p_token text)
returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  s public.app_portal_sessions;
  u public.app_users;
  resultat json;
begin
  s := public.bs_session_valider(p_token);
  if s.token is null then
    raise exception 'SESSION_EXPIREE';
  end if;

  -- Un compte du site (origine 1) n'entre jamais ici, quel que soit son
  -- rôle : c'est un compte de propriétaire, pas d'administrateur
  -- technique.
  if s.origine <> 0 then
    raise exception 'RESERVE_AU_SUPER_ADMIN';
  end if;

  -- Et pour l'équipe, on relit l'autorisation à CHAQUE appel plutôt que
  -- de la figer dans la session : retirer l'accès à quelqu'un doit
  -- prendre effet tout de suite, pas dans douze heures.
  select * into u from public.app_users
   where lower(login) = lower(s.login) limit 1;

  if u.id is null or not u.active or not u.acces_portail then
    raise exception 'RESERVE_AU_SUPER_ADMIN';
  end if;

  select json_build_object(
    'genere_le', now(),

    'postes', coalesce((
      select json_agg(row_to_json(p) order by p.derniere_vue desc)
      from (
        select nom, version, derniere_vue, derive_secondes,
               ventes_en_attente, stock_en_attente, dernier_login,
               -- Dix minutes : le double de l'intervalle de battement,
               -- pour qu'un signal manqué ne déclenche pas d'alarme.
               (now() - derniere_vue) < interval '10 minutes' as en_ligne
        from public.app_postes
      ) p
    ), '[]'::json),

    'comptes', coalesce((
      select json_agg(row_to_json(c) order by c.role, c.login)
      from (
        select login, full_name, role, active, last_login, acces_portail
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

    -- La journée COMMERCIALE de Lubumbashi (UTC+2), pas celle du
    -- serveur : une vente de 23 h appartient au jour même.
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

revoke execute on function public.bs_portail_etat(text) from public;
grant execute on function public.bs_portail_etat(text) to anon;

notify pgrst, 'reload schema';

-- ── Contrôle ───────────────────────────────────────────────────────────
-- Qui peut entrer, en une requête :
--
--   select login, full_name, role, active, acces_portail
--   from   public.app_users
--   where  acces_portail
--   order  by login;
--
-- Cette liste doit tenir sur une ligne ou deux. Si elle s'allonge, c'est
-- que l'autorisation est devenue une formalité — et elle ne protège plus
-- rien.


-- ── La connexion dit si le portail est ouvert à ce compte ──────────────
-- Sans ça, le site ne peut pas décider s'il affiche l'entrée du portail.
-- Et l'alternative — un lien visible par tous, qui échoue pour la
-- plupart — serait pire : une porte fermée reste une invitation à
-- pousser.
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
  v_portail boolean := false;
begin
  -- D'abord l'équipe.
  u := public.bs_check_credentials(p_login, p_password);
  if u.id is not null then
    v_role := u.role;
    v_nom  := u.full_name;
    v_origine := 0;
    v_portail := coalesce(u.acces_portail, false);
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
    -- Les trois variantes décrivent le même algorithme ; selon la
    -- version de pgcrypto, `crypt()` ne reconnaît que `$2a$`.
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
    -- Un compte du site n'accède JAMAIS au portail technique, quel que
    -- soit son rôle affiché.
    v_portail := false;
  end if;

  delete from public.app_portal_sessions where expire_le < now();

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
    'origine', v_origine,
    'acces_portail', v_portail
  );
end;
$$;

revoke execute on function public.bs_session_ouvrir(text, text) from public;
grant execute on function public.bs_session_ouvrir(text, text) to anon;

notify pgrst, 'reload schema';
