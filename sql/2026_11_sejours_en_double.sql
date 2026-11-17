-- =====================================================================
-- SÉJOURS EN DOUBLE
-- =====================================================================
--
-- Constat (17 novembre 2026) : sur 19 séjours, 3 sont présents deux ou
-- trois fois — FCT542/9/2026 trois fois, FCT253/10 et FCT261/10 deux
-- fois. Ce ne sont pas des numéros qui se répètent : c'est le MÊME
-- séjour (même client, mêmes dates, même montant), envoyé par deux ou
-- trois postes sous des identités différentes. Le chiffre d'affaires de
-- l'hôtel était gonflé d'environ 1 127 000 FC sur le tableau de bord.
--
-- Origine : avant le 5 octobre, un séjour recopié d'un poste à l'autre
-- recevait son identité de la copie locale, et le décalage d'horloge de
-- septembre la faisait diverger. Ces copies vivent encore sur les postes,
-- et repartent à chaque synchronisation — y compris depuis des postes qui
-- ne seront pas mis à jour.
--
-- La correction, côté serveur, pour toutes les versions :
--   * `doublon_de` désigne le séjour d'origine (le premier reçu) ;
--   * les doublons déjà présents sont marqués ;
--   * un doublon qui arrive est marqué à l'arrivée. Il n'est pas refusé :
--     un refus ferait échouer l'envoi de tous les séjours du même lot ;
--   * le tableau de bord et les postes à jour ignorent les doublons.
--
-- « Même séjour » = même numéro de facture, même client, mêmes dates
-- d'arrivée et de départ, même montant. Deux factures différentes qui
-- auraient le même numéro (l'ancienne numérotation se répétait) ne sont
-- pas confondues.
--
-- À EXÉCUTER UNE FOIS dans Supabase → SQL Editor, AVANT de publier la
-- version qui ignore les doublons. Rejouable.
-- =====================================================================

begin;

alter table public.mirror_stays
  add column if not exists doublon_de bigint;

create index if not exists mirror_stays_meme_sejour_idx
  on public.mirror_stays (receipt_number, checkin_at, checkout_at);

-- Les doublons déjà là : rattachés au premier reçu.
with groupes as (
  select id,
         first_value(id) over (
           partition by receipt_number, guest_full_name, checkin_at,
                        checkout_at, subtotal_cents
           order by id
         ) as origine
    from public.mirror_stays
)
update public.mirror_stays s
   set doublon_de = g.origine
  from groupes g
 where g.id = s.id
   and g.origine <> s.id
   and s.doublon_de is distinct from g.origine;

-- Ceux qui arrivent.
create or replace function public.bs_mirror_stays_doublon()
returns trigger language plpgsql as $$
begin
  select id into new.doublon_de
    from public.mirror_stays o
   where o.receipt_number = new.receipt_number
     and o.guest_full_name is not distinct from new.guest_full_name
     and o.checkin_at = new.checkin_at
     and o.checkout_at = new.checkout_at
     and o.subtotal_cents = new.subtotal_cents
     and o.uid is distinct from new.uid
     and o.doublon_de is null
   order by o.id
   limit 1;
  return new;
end;
$$;

drop trigger if exists mirror_stays_doublon on public.mirror_stays;
create trigger mirror_stays_doublon
  before insert on public.mirror_stays
  for each row execute function public.bs_mirror_stays_doublon();

notify pgrst, 'reload schema';

commit;

-- ── Vérification ──────────────────────────────────────────────────────
-- select receipt_number, count(*) filter (where doublon_de is null) as gardes,
--        count(*) filter (where doublon_de is not null) as doublons
--   from public.mirror_stays group by 1 having count(*) > 1;
--   -- chaque ligne : 1 gardé
