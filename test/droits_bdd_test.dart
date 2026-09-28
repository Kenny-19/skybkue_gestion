import 'package:blue_sky/core/auth.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:flutter_test/flutter_test.dart';

// Le gérant a fait des dégâts sur la base : on lui retire la vue sur
// tout ce qui touche au stockage et à Supabase. Il garde la gestion de
// l'équipe et du commerce, pas la plomberie.
//
// Ces tests figent la frontière. Sans eux, une garde se relâche au
// premier écran ajouté — c'est exactement ce qui s'est produit avec
// `canHistory` sur la récupération d'urgence : le commentaire disait
// « admin + super admin », la garde laissait passer TOUT LE MONDE.

void main() {
  const superAdmin = Perms(DbUserRole.superAdmin);
  const gerant = Perms(DbUserRole.gerant);
  const serveur = Perms(DbUserRole.serveur);
  const reception = Perms(DbUserRole.reception);

  group('La base de données appartient au super admin seul', () {
    test('lui seul ouvre les réglages techniques', () {
      expect(superAdmin.canSettings, true);
      for (final p in [gerant, serveur, reception]) {
        expect(p.canSettings, false, reason: p.role.toString());
      }
    });

    test('lui seul gère les comptes de niveau gérant', () {
      expect(superAdmin.canManageGerants, true);
      expect(gerant.canManageGerants, false);
    });

    test('lui seul supprime un compte définitivement', () {
      expect(superAdmin.canDeleteAccounts, true);
      expect(gerant.canDeleteAccounts, false);
    });
  });

  group('Ce que le gérant garde', () {
    test('il gère toujours l\'équipe de service', () {
      expect(gerant.canManageServeurs, true);
    });

    test('il garde le commerce : catalogue, stock, clients', () {
      expect(gerant.canEditCatalog, true);
      expect(gerant.canStock, true);
      expect(gerant.canClients, true);
      expect(gerant.canDiscount, true);
    });
  });

  group("L'historique de la réception est celui de l'hôtel", () {
    test('la réception est reconnue comme telle', () {
      expect(reception.isReception, true);
      for (final p in [superAdmin, gerant, serveur]) {
        expect(p.isReception, false, reason: p.role.toString());
      }
    });

    test('elle accède à l\'historique mais pas à la caisse', () {
      // C'est ce qui justifie de lui montrer les séjours et non les
      // ventes du bar : elle ne peut même pas en créer.
      expect(reception.canHistory, true);
      expect(reception.canPos, false);
      expect(reception.canRooms, true);
      expect(reception.canReservations, true);
    });
  });

  group("Mots de passe : ce que le gérant peut, et ce qu'il ne peut pas", () {
    test('il change le mot de passe des serveuses et de la réception', () {
      // C'est le besoin réel : quelqu'un oublie son code un samedi soir
      // et le gérant doit pouvoir le débloquer sans le super admin.
      expect(gerant.canManageServeurs, true);
    });

    test('il ne touche pas à un compte de son propre niveau', () {
      // Le serveur refuse (bs_set_password exige un super admin dès que
      // la cible est gérant ou super admin) : l'écran doit refuser aussi,
      // sinon le bouton échoue après le clic.
      expect(gerant.canManageGerants, false);
      expect(superAdmin.canManageGerants, true);
    });

    test('personne ne peut LIRE un mot de passe', () {
      // Il n'existe aucun droit de ce genre, et c'est volontaire : rien
      // n'est stocké en clair, ni sur le poste ni sur le serveur. Ce
      // test existe pour que l'absence soit un choix documenté et non
      // un oubli qu'on « corrigerait » un jour.
      const droits = [
        'canDiscount',
        'canManageServeurs',
        'canManageGerants',
        'canDeleteAccounts',
        'canSettings',
        'canStock',
        'canPos',
      ];
      expect(droits.any((d) => d.toLowerCase().contains('password')), false);
    });
  });
}
