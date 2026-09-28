import 'package:blue_sky/core/auth.dart';
import 'package:blue_sky/data/schema.dart';
import 'package:flutter_test/flutter_test.dart';

// Qui voit quel historique.
//
// La règle, posée le 24 septembre 2026 : la réception voit l'hôtel, les
// serveuses voient les ventes, les gérants et le super admin voient
// tout. Ce n'est pas une préférence d'affichage — les séjours facturés
// portent des noms de clients, des tarifs négociés et des coordonnées de
// sociétés, et les tickets de bar portent le détail de ce que chaque
// serveuse a encaissé.

void main() {
  Perms pour(DbUserRole? role) => Perms(role);

  group("L'hôtel", () {
    test('la réception y a droit : c\'est son métier', () {
      expect(pour(DbUserRole.reception).canHistoriqueHotel, isTrue);
    });

    test("une serveuse n'y a PAS droit", () {
      expect(pour(DbUserRole.serveur).canHistoriqueHotel, isFalse,
          reason: 'les factures de séjour ne la regardent pas');
    });

    test('les gérants et le super admin voient tout', () {
      expect(pour(DbUserRole.gerant).canHistoriqueHotel, isTrue);
      expect(pour(DbUserRole.superAdmin).canHistoriqueHotel, isTrue);
    });
  });

  group('Les ventes', () {
    test('une serveuse y a droit : elle y retrouve ses tickets', () {
      expect(pour(DbUserRole.serveur).canHistoriqueVentes, isTrue);
    });

    test("la réception n'y a PAS droit", () {
      expect(pour(DbUserRole.reception).canHistoriqueVentes, isFalse,
          reason: 'les transactions du bar ne sont pas son métier');
    });

    test('les gérants et le super admin voient tout', () {
      expect(pour(DbUserRole.gerant).canHistoriqueVentes, isTrue);
      expect(pour(DbUserRole.superAdmin).canHistoriqueVentes, isTrue);
    });
  });

  group('Personne ne reste sans rien, ni avec tout', () {
    test('chaque rôle connecté voit au moins un historique', () {
      for (final r in DbUserRole.values) {
        final p = pour(r);
        expect(p.canHistoriqueHotel || p.canHistoriqueVentes, isTrue,
            reason: 'un écran vide fait croire à une panne — $r');
      }
    });

    test('seuls gérant et super admin cumulent les deux', () {
      final lesDeux = DbUserRole.values.where((r) {
        final p = pour(r);
        return p.canHistoriqueHotel && p.canHistoriqueVentes;
      }).toSet();
      expect(lesDeux, {DbUserRole.gerant, DbUserRole.superAdmin});
    });

    test('déconnecté, on ne voit rien du tout', () {
      expect(pour(null).canHistoriqueHotel, isFalse);
      expect(pour(null).canHistoriqueVentes, isFalse);
    });
  });
}
