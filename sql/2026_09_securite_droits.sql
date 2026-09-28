-- ═══════════════════════════════════════════════════════════════════════
-- CORRECTIF DE SÉCURITÉ — fermeture des droits PUBLIC
-- ═══════════════════════════════════════════════════════════════════════
--
-- À exécuter dans Supabase → SQL Editor. Rejouable sans risque.
--
-- Le problème
-- -----------
-- PostgreSQL accorde EXECUTE à PUBLIC sur toute nouvelle fonction. Le
-- `revoke ... from anon, authenticated` des scripts précédents ne
-- retirait donc RIEN : le droit PUBLIC restait, et la clé anon — qui est
-- extractible du binaire de l'application — ouvrait deux portes :
--
--   * `bs_check_credentials` renvoie la ligne complète du compte,
--     **hash du mot de passe inclus**. C'est exactement ce que le modèle
--     promettait d'empêcher.
--   * `bs_new_import_token` permet de se forger un jeton de reprise,
--     donc de s'inventer un compte super admin via `bs_import_account`.
--
-- Vérifié en conditions réelles le 6 septembre 2026 : les deux fonctions
-- répondaient à un appel extérieur muni de la seule clé anon.
--
-- La correction
-- -------------
-- On retire PUBLIC partout, puis on re-accorde explicitement à `anon`
-- les seules fonctions qui contrôlent elles-mêmes l'autorisation de
-- l'appelant. Les helpers internes ne sont jamais re-accordés.

-- ── 1. Tout fermer, PUBLIC compris ─────────────────────────────────────
revoke execute on function public.bs_check_credentials(text, text)
  from public, anon, authenticated;
revoke execute on function public.bs_require_admin(text, text)
  from public, anon, authenticated;
revoke execute on function public.bs_new_import_token(int)
  from public, anon, authenticated;

revoke execute on function public.bs_verify_login(text, text) from public;
revoke execute on function public.bs_create_account(
  text, text, text, text, text, smallint) from public;
revoke execute on function public.bs_set_password(text, text, text, text)
  from public;
revoke execute on function public.bs_set_active(text, text, text, boolean)
  from public;
revoke execute on function public.bs_rename_account(text, text, text, text)
  from public;
revoke execute on function public.bs_delete_account(text, text, text)
  from public;
revoke execute on function public.bs_import_account(
  text, text, text, text, text, text, smallint, boolean,
  timestamptz, timestamptz) from public;

-- ── 2. Rouvrir uniquement ce que l'application doit appeler ────────────
-- Chacune de ces fonctions vérifie elle-même qui l'appelle : posséder la
-- clé anon ne suffit jamais à écrire.
grant execute on function public.bs_verify_login(text, text)
  to anon, authenticated;
grant execute on function public.bs_create_account(
  text, text, text, text, text, smallint) to anon, authenticated;
grant execute on function public.bs_set_password(text, text, text, text)
  to anon, authenticated;
grant execute on function public.bs_set_active(text, text, text, boolean)
  to anon, authenticated;
grant execute on function public.bs_rename_account(text, text, text, text)
  to anon, authenticated;
grant execute on function public.bs_delete_account(text, text, text)
  to anon, authenticated;
grant execute on function public.bs_import_account(
  text, text, text, text, text, text, smallint, boolean,
  timestamptz, timestamptz) to anon, authenticated;

-- ── 3. Éviter que le piège se reproduise ───────────────────────────────
-- Les fonctions créées plus tard dans ce schéma ne seront pas exposées
-- à PUBLIC par défaut. C'est ce réglage qui manquait depuis le début.
alter default privileges in schema public
  revoke execute on functions from public;

-- ── 4. Purger les jetons de reprise ────────────────────────────────────
-- Dont celui généré pendant le diagnostic du 6 septembre.
delete from public.app_import_tokens;

notify pgrst, 'reload schema';

-- ── 5. Contrôle — les trois lignes doivent afficher `false` ────────────
select p.proname,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_peut_appeler
from   pg_proc p
join   pg_namespace n on n.oid = p.pronamespace
where  n.nspname = 'public'
  and  p.proname in ('bs_check_credentials',
                     'bs_require_admin',
                     'bs_new_import_token')
order  by p.proname;
