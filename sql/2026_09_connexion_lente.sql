-- ═══════════════════════════════════════════════════════════════════════
-- CONNEXION QUI EXPIRE — un bcrypt par compte au lieu d'un seul
-- ═══════════════════════════════════════════════════════════════════════
--
-- À exécuter dans Supabase → SQL Editor. Rejouable sans risque.
--
-- Le symptôme
-- -----------
-- Depuis le 19 septembre 2026, les postes remontent des erreurs
-- « canceling statement due to statement timeout » (code 57014) sur
-- `accounts/verifyLogin`. Relevé du 24 septembre : 75 échecs, dont 70 sur
-- la connexion et 5 sur le changement de mot de passe. Concrètement, des
-- employés qui n'arrivent pas à ouvrir la caisse.
--
-- La cause
-- --------
-- `bs_check_credentials` s'écrivait ainsi :
--
--     select u.* from public.app_users u
--      where lower(u.login) = lower(trim(p_login))
--        and u.active
--        and u.password_hash = crypt(p_password, u.password_hash)
--
-- La table ne contient qu'une dizaine de comptes. Postgres juge donc le
-- balayage complet moins cher que l'index — et évalue alors `crypt()`
-- sur CHAQUE ligne, parce que rien ne lui dit que cette fonction coûte
-- cher. Onze bcrypt à coût 12 font environ trois secondes sur un CPU
-- partagé : le délai d'attente tombe avant la fin.
--
-- Et la chronologie le confirme : aucun timeout avant la reprise des
-- comptes. Avec deux ou trois comptes, ça passait. À onze, non.
--
-- La correction
-- -------------
-- On sépare les deux étapes : trouver LE compte par son login, puis
-- vérifier SON mot de passe. Un seul bcrypt, quel que soit le nombre de
-- comptes. Le coût devient constant au lieu d'être proportionnel — c'est
-- ce qui évite que ça recommence quand l'équipe grandira.

create or replace function public.bs_check_credentials(
  p_login text, p_password text
) returns public.app_users
language plpgsql security definer set search_path = public, extensions as $$
declare u public.app_users;
begin
  -- 1. Le compte, par son login. Aucun calcul cryptographique ici :
  --    l'index unique sur lower(login) répond immédiatement.
  select * into u
    from public.app_users
   where lower(login) = lower(trim(p_login))
   limit 1;

  if u.id is null or not u.active then
    return null;
  end if;

  -- 2. UN SEUL bcrypt, sur le compte concerné et lui seul.
  if u.password_hash = extensions.crypt(p_password, u.password_hash) then
    return u;
  end if;
  return null;
end;
$$;

-- Les droits, à re-poser : `create or replace` ne les conserve pas
-- toujours, et PUBLIC reçoit EXECUTE par défaut sur toute fonction neuve
-- — c'est exactement ce qui avait ouvert la faille de septembre.
revoke execute on function public.bs_check_credentials(text, text)
  from public, anon, authenticated;

-- ── Hygiène : la table des tentatives grandit sans fin ─────────────────
-- Chaque connexion y insère une ligne. Elle n'est lue que sur les cinq
-- dernières minutes, donc tout ce qui dépasse une journée est du poids
-- mort — et un jour, un balayage de trop.
delete from public.app_login_attempts
 where attempted_at < now() - interval '1 day';

-- ── Contrôle ───────────────────────────────────────────────────────────
-- Une connexion doit maintenant répondre en quelques centaines de
-- millisecondes, et non plus en secondes :
--
--   explain analyze
--   select public.bs_verify_login('un_login_existant', 'mauvais_mot_de_passe');
--
-- Le temps total doit rester bien en dessous de la seconde. S'il monte
-- encore, c'est que le coût bcrypt lui-même est trop élevé pour ce plan
-- Supabase — mais ce n'est plus un problème de nombre de comptes.

-- ── Identifier le poste qui remonte une erreur ─────────────────────────
-- `error_logs` ne disait pas d'où venait une panne. Le 24 septembre, il
-- a fallu arrêter une application et observer si les erreurs
-- continuaient pour deviner leur origine — et deux minutes de silence ne
-- prouvent pas grand-chose. Un nom de machine répond tout de suite.
--
-- C'est un nom d'ordinateur (« CAISSE-1 », « RECEPTION »), pas une
-- donnée personnelle : rien sur qui l'utilisait.
alter table public.error_logs
  add column if not exists poste text;

notify pgrst, 'reload schema';
