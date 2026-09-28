-- ═══════════════════════════════════════════════════════════════════════
-- DÉBLOQUER LE COMPTE SUPER ADMIN `kenny`
-- ═══════════════════════════════════════════════════════════════════════
--
-- À exécuter dans Supabase → SQL Editor.
--
-- Ce qui s'est passé
-- ------------------
-- Le compte est ACTIF côté serveur — ce n'était pas une désactivation.
-- Le blocage venait du poste : la connexion super admin se faisait par
-- passphrase comparée aux hachages LOCAUX, sans jamais interroger le
-- serveur. Or `kenny` porte en local le hachage sentinelle
-- (`no-offline-access`), posé par la bascule vers des comptes hébergés
-- exclusivement sur Supabase. Il signifie « demande au serveur » — mais
-- ce chemin de connexion n'avait pas de branche serveur.
--
-- Le code est corrigé (lib/core/auth.dart) : la connexion super admin
-- interroge désormais le serveur pour les comptes sans accès local.
-- Reste à s'assurer que le serveur connaît bien un mot de passe pour
-- `kenny` — la reprise a pu y recopier la sentinelle, auquel cas aucune
-- saisie ne pourra jamais correspondre.
--
-- Choisis ton mot de passe
-- ------------------------
-- Remplace MON_MOT_DE_PASSE ci-dessous. Évite `0000` : la connexion
-- super admin se fait sans identifiant, elle essaie donc les comptes
-- super admin l'un après l'autre. Deux super admins avec le même mot de
-- passe, et tu ouvrirais la session de l'autre.

update public.app_users
   set password_hash = extensions.crypt(
                         'MON_MOT_DE_PASSE',
                         extensions.gen_salt('bf', 12)),
       active        = true
 where lower(login) = 'kenny';

-- Contrôle : doit renvoyer une ligne, `ok` à true.
select login, active,
       (password_hash = extensions.crypt('MON_MOT_DE_PASSE', password_hash))
         as ok
from   public.app_users
where  lower(login) = 'kenny';

-- Si la table des tentatives existe, on efface un éventuel blocage.
do $$
begin
  if to_regclass('public.app_login_attempts') is not null then
    delete from public.app_login_attempts where lower(login) = 'kenny';
  end if;
end $$;
