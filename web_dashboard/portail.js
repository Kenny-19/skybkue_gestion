// ─── Skyblue — Portail technique (super admin) ──────────────────────────
//
// Ce que cette page N'A PAS le droit de faire
// -------------------------------------------
// Lire une table. Pas une seule. Tout passe par `bs_portail_etat`, qui
// vérifie sur le serveur que l'appelant est bien un super admin avant de
// répondre.
//
// La raison est concrète : la clé anon est servie à tout visiteur dans
// `config.js`. Vérifié le 24 septembre 2026, elle donnait accès aux 233
// ventes, à 214 journaux d'erreurs et aux téléphones de 45 clients. Ce
// portail montre davantage — l'état des machines, le stock, les comptes.
// Il ne pouvait pas naître sur le même modèle.
//
// La session tient par un JETON, pas par le mot de passe.
//
// Le mot de passe ne traverse le réseau qu'une fois, à la connexion. Ce
// qui est conservé ensuite est une chaîne aléatoire sans valeur
// ailleurs : elle expire au bout de douze heures, elle se révoque, et la
// voler ne donne pas le mot de passe. Ranger un mot de passe de super
// admin dans le navigateur aurait été la solution paresseuse — lisible
// par n'importe quelle extension, et survivant à la fermeture.

const cfg = window.SKYBLUE_CONFIG;
const supa = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey);

const CLE_SESSION = 'skyblue_portail_session';
let session = null; // { token, expire_le, login, full_name }
let dernierEtat = null;
let minuterie = null;

function lireSession() {
  try {
    const brut = localStorage.getItem(CLE_SESSION);
    if (!brut) return null;
    const s = JSON.parse(brut);
    // Le serveur tranche vraiment ; cette vérification évite juste
    // d'afficher un portail qui échouera à sa première requête.
    if (!s.token || new Date(s.expire_le).getTime() < Date.now()) {
      localStorage.removeItem(CLE_SESSION);
      return null;
    }
    return s;
  } catch (_) {
    return null;
  }
}

function ecrireSession(s) {
  try {
    localStorage.setItem(CLE_SESSION, JSON.stringify(s));
  } catch (_) {
    // Navigation privée, stockage refusé : la session vivra le temps de
    // l'onglet. Ce n'est pas une raison pour empêcher d'entrer.
  }
}

function oublierSession() {
  try {
    localStorage.removeItem(CLE_SESSION);
  } catch (_) {}
}

const $ = (id) => document.getElementById(id);

// ── Connexion ──────────────────────────────────────────────────────────
async function ouvrirSession(login, mdp) {
  const { data, error } = await supa.rpc('bs_session_ouvrir', {
    p_login: login.trim(),
    p_password: mdp,
  });
  if (error) throw new Error('Connexion impossible. Vérifie le réseau.');
  if (!data || data.status !== 'ok') {
    throw new Error('Identifiant ou mot de passe incorrect.');
  }
  return data;
}

/// Demande l'état au serveur, contre le jeton de session.
async function etat(token) {
  const { data, error } = await supa.rpc('bs_portail_etat', {
    p_token: token,
  });
  if (error) {
    // Le serveur lève des exceptions nommées. On les traduit plutôt que
    // de montrer le message brut de PostgreSQL.
    const m = error.message || '';
    if (m.includes('RESERVE_AU_SUPER_ADMIN')) {
      throw new Error(
        'Ce portail est réservé au super admin de l\'équipe.',
      );
    }
    if (m.includes('SESSION_EXPIREE')) {
      throw new Error('Session expirée. Reconnecte-toi.');
    }
    if (m.includes('statement timeout')) {
      throw new Error('Le serveur met trop longtemps à répondre. Réessaie.');
    }
    throw new Error('Connexion impossible. Vérifie le réseau.');
  }
  return data;
}

$('btn-entrer').addEventListener('click', async () => {
  const b = $('btn-entrer');
  const err = $('login-erreur');
  err.classList.add('cache');
  b.disabled = true;
  b.textContent = 'Vérification…';
  try {
    const login = $('login').value;
    const mdp = $('mdp').value;
    const s = await ouvrirSession(login, mdp);
    // On demande l'état AVANT d'enregistrer la session : si le compte
    // n'est pas super admin, mieux vaut le dire tout de suite que
    // d'ouvrir un portail qui refusera tout.
    dernierEtat = await etat(s.token);
    session = s;
    ecrireSession(s);
    $('mdp').value = '';
    $('ecran-login').classList.add('cache');
    $('ecran-portail').classList.remove('cache');
    afficher(dernierEtat);
    // Rafraîchissement automatique : « en direct » veut dire qu'on ne
    // clique pas pour savoir si un poste vient de tomber.
    minuterie = setInterval(rafraichir, 30000);
  } catch (e) {
    err.textContent = e.message;
    err.classList.remove('cache');
  } finally {
    b.disabled = false;
    b.textContent = 'Ouvrir le portail';
  }
});

$('mdp').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') $('btn-entrer').click();
});

$('btn-sortir').addEventListener('click', () => {
  // On prévient le serveur : un jeton abandonné dans la nature resterait
  // valide douze heures.
  if (session) supa.rpc('bs_session_fermer', { p_token: session.token });
  session = null;
  oublierSession();
  dernierEtat = null;
  if (minuterie) clearInterval(minuterie);
  $('ecran-portail').classList.add('cache');
  $('ecran-login').classList.remove('cache');
});

$('btn-rafraichir').addEventListener('click', rafraichir);

async function rafraichir() {
  if (!session) return;
  const b = $('btn-rafraichir');
  b.disabled = true;
  try {
    dernierEtat = await etat(session.token);
    afficher(dernierEtat);
  } catch (e) {
    if (String(e.message).includes('Session expirée')) {
      // Rien à sauver : on renvoie proprement vers la connexion plutôt
      // que de laisser un écran qui se périme en silence.
      oublierSession();
      session = null;
      if (minuterie) clearInterval(minuterie);
      $('ecran-portail').classList.add('cache');
      $('ecran-login').classList.remove('cache');
      $('login-erreur').textContent = e.message;
      $('login-erreur').classList.remove('cache');
      return;
    }
    // Une coupure ne doit pas vider l'écran : on garde le dernier état
    // connu et on date l'information, pour qu'on sache qu'elle vieillit.
    $('horodatage').textContent = 'hors ligne — ' + e.message;
  } finally {
    b.disabled = false;
  }
}

// ── Affichage ──────────────────────────────────────────────────────────
const echapper = (v) =>
  String(v ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]),
  );

/// « il y a 3 min », « il y a 2 h ». Un horodatage brut oblige à
/// calculer ; ce qu'on veut savoir, c'est si c'est frais.
function ilYA(iso) {
  if (!iso) return '—';
  const s = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 60) return "à l'instant";
  if (s < 3600) return 'il y a ' + Math.round(s / 60) + ' min';
  if (s < 86400) return 'il y a ' + Math.round(s / 3600) + ' h';
  return 'il y a ' + Math.round(s / 86400) + ' j';
}

const argent = (cents) =>
  new Intl.NumberFormat('fr-FR').format(Math.round(cents)) + ' FC';

function table(el, colonnes, lignes, messageVide) {
  if (!lignes.length) {
    el.innerHTML = '<tr><td class="vide">' + messageVide + '</td></tr>';
    return;
  }
  const entete =
    '<tr>' +
    colonnes
      .map((c) => '<th' + (c.num ? ' class="num"' : '') + '>' + c.titre + '</th>')
      .join('') +
    '</tr>';
  const corps = lignes
    .map(
      (l) =>
        '<tr>' +
        colonnes
          .map(
            (c) =>
              '<td' + (c.num ? ' class="num"' : '') + '>' + c.valeur(l) + '</td>',
          )
          .join('') +
        '</tr>',
    )
    .join('');
  el.innerHTML = entete + corps;
}

function afficher(e) {
  $('horodatage').textContent = 'à jour ' + ilYA(e.genere_le);

  const postes = e.postes || [];
  const erreurs = e.erreurs || [];
  const v = e.ventes_du_jour || {};
  const enLigne = postes.filter((p) => p.en_ligne).length;
  const enAttente = postes.reduce((s, p) => s + (p.ventes_en_attente || 0), 0);
  const erreurs24 = erreurs
    .filter((x) => Date.now() - new Date(x.derniere).getTime() < 86400000)
    .reduce((s, x) => s + Number(x.occurrences || 0), 0);

  $('tuiles').innerHTML = [
    tuile('Postes en ligne', enLigne + ' / ' + postes.length,
      enLigne === postes.length && postes.length ? 'vert' : 'ambre'),
    tuile('Ventes du jour', v.nombre ?? 0, 'gris'),
    tuile('Encaissé', argent((v.total_cents || 0) / 100), 'gris'),
    tuile('À recouvrer', argent((v.a_recouvrer_cents || 0) / 100),
      (v.a_recouvrer_cents || 0) > 0 ? 'ambre' : 'vert'),
    tuile('Ventes pas encore en ligne', enAttente,
      enAttente > 0 ? 'ambre' : 'vert'),
    tuile('Erreurs (24 h)', erreurs24, erreurs24 > 0 ? 'rouge' : 'vert'),
  ].join('');

  table($('t-postes'),
    [
      { titre: 'Poste', valeur: (p) => '<strong>' + echapper(p.nom) + '</strong>' },
      { titre: 'État', valeur: (p) =>
          p.en_ligne
            ? '<span class="pastille vert">en ligne</span>'
            : '<span class="pastille gris">vu ' + ilYA(p.derniere_vue) + '</span>' },
      { titre: 'Version', valeur: (p) => echapper(p.version || '—') },
      { titre: 'Horloge', valeur: (p) => horloge(p.derive_secondes) },
      { titre: 'Ventes en attente', num: true, valeur: (p) =>
          (p.ventes_en_attente || 0) > 0
            ? '<span class="pastille ambre">' + p.ventes_en_attente + '</span>'
            : '0' },
      { titre: 'Stock en attente', num: true, valeur: (p) => p.stock_en_attente || 0 },
      { titre: 'Dernier utilisateur', valeur: (p) => echapper(p.dernier_login || '—') },
    ],
    postes,
    "Aucun poste ne s'est encore signalé. La version installée ne sait "
      + 'peut-être pas le faire.');

  table($('t-erreurs'),
    [
      { titre: 'Dernière', valeur: (x) => ilYA(x.derniere) },
      { titre: 'Poste', valeur: (x) => echapper(x.poste) },
      { titre: 'Où', valeur: (x) => echapper(x.context || '—') },
      { titre: 'Message', valeur: (x) => echapper(x.message) },
      { titre: 'Fois', num: true, valeur: (x) =>
          Number(x.occurrences) > 5
            ? '<span class="pastille rouge">' + x.occurrences + '</span>'
            : x.occurrences },
    ],
    erreurs,
    'Aucune erreur remontée depuis sept jours.');

  table($('t-stock'),
    [
      { titre: 'Article', valeur: (a) => echapper(a.name) },
      { titre: 'Restant', num: true, valeur: (a) =>
          '<span class="pastille ' + (a.stock_qty <= 0 ? 'rouge' : 'ambre') + '">'
          + a.stock_qty + ' ' + echapper(a.unit || '') + '</span>' },
      { titre: 'Seuil', num: true, valeur: (a) => a.threshold },
    ],
    e.stock_bas || [],
    'Rien au seuil.');

  const ETAT_CHAMBRE = ['libre', 'occupée', 'nettoyage', 'maintenance'];
  table($('t-chambres'),
    [
      { titre: 'N°', valeur: (r) => echapper(r.number) },
      { titre: 'Type', valeur: (r) => echapper(r.type) },
      { titre: 'État', valeur: (r) =>
          '<span class="pastille ' + (r.status === 1 ? 'ambre' : r.status === 3 ? 'rouge' : 'vert')
          + '">' + (ETAT_CHAMBRE[r.status] || '?') + '</span>' },
      { titre: 'Occupant', valeur: (r) => echapper(r.current_guest || '—') },
      { titre: 'Tarif', num: true, valeur: (r) =>
          r.price_usd_cents > 0
            ? '$' + (r.price_usd_cents / 100).toFixed(0)
            : argent((r.price_per_night_cents || 0) / 100) },
    ],
    e.chambres || [],
    'Aucune chambre.');

  const ROLE = { 0: 'Super admin', 1: 'Gérant', 2: 'Serveuse', 3: 'Réception' };
  table($('t-comptes'),
    [
      { titre: 'Identifiant', valeur: (c) => echapper(c.login) },
      { titre: 'Nom', valeur: (c) => echapper(c.full_name) },
      { titre: 'Rôle', valeur: (c) => ROLE[c.role] || c.role },
      { titre: 'Actif', valeur: (c) =>
          c.active
            ? '<span class="pastille vert">oui</span>'
            : '<span class="pastille gris">non</span>' },
      { titre: 'Dernière connexion', valeur: (c) => ilYA(c.last_login) },
    ],
    e.comptes || [],
    'Aucun compte.');
}

function tuile(libelle, valeur, couleur) {
  return (
    '<div class="tuile"><div class="libelle">' + libelle + '</div>' +
    '<div class="valeur"><span class="pastille ' + couleur + '">' +
    echapper(valeur) + '</span></div></div>'
  );
}

/// La dérive d'horloge, dite en clair.
///
/// Deux heures d'écart ont fait classer 163 ventes au mauvais jour en
/// septembre 2026. Ce n'est plus grave depuis que l'application prend son
/// heure en ligne, mais un poste qui dérive redeviendra faux le jour où
/// il démarrera sans connexion.
function horloge(secondes) {
  if (secondes === null || secondes === undefined) return '—';
  const s = Math.abs(secondes);
  if (s < 300) return '<span class="pastille vert">juste</span>';
  const txt = s >= 3600
    ? Math.round(s / 3600) + ' h'
    : Math.round(s / 60) + ' min';
  return '<span class="pastille ' + (s >= 3600 ? 'rouge' : 'ambre') + '">'
    + (secondes > 0 ? 'avance de ' : 'retarde de ') + txt + '</span>';
}

// ── Copier le diagnostic ───────────────────────────────────────────────
// Un bouton, parce que la façon de me décrire une panne ne doit pas être
// « je te renvoie les mails ». Ceci produit un résumé compact, collable
// tel quel dans une conversation.
$('btn-copier').addEventListener('click', async () => {
  if (!dernierEtat) return;
  const e = dernierEtat;
  const l = [];
  l.push('DIAGNOSTIC SKYBLUE — ' + new Date(e.genere_le).toISOString());
  l.push('');
  l.push('POSTES');
  (e.postes || []).forEach((p) => {
    l.push('  ' + p.nom + ' | ' + (p.en_ligne ? 'en ligne' : 'vu ' + ilYA(p.derniere_vue))
      + ' | v' + (p.version || '?')
      + ' | horloge ' + (p.derive_secondes ?? '?') + ' s'
      + ' | ' + (p.ventes_en_attente || 0) + ' vente(s) en attente');
  });
  if (!(e.postes || []).length) l.push('  (aucun poste signalé)');
  l.push('');
  l.push('ERREURS');
  (e.erreurs || []).slice(0, 15).forEach((x) => {
    l.push('  [' + x.occurrences + '×] ' + x.poste + ' / ' + (x.context || '—')
      + ' : ' + x.message);
  });
  if (!(e.erreurs || []).length) l.push('  (aucune)');
  const v = e.ventes_du_jour || {};
  l.push('');
  l.push('JOUR : ' + (v.nombre ?? 0) + ' vente(s), '
    + argent((v.total_cents || 0) / 100) + ' dont '
    + argent((v.a_recouvrer_cents || 0) / 100) + ' à recouvrer');

  const texte = l.join('\n');
  const btn = $('btn-copier');
  try {
    await navigator.clipboard.writeText(texte);
    btn.textContent = 'Copié';
  } catch (_) {
    // Le presse-papier est refusé hors HTTPS, ou par la configuration du
    // navigateur. On ne laisse pas l'utilisateur sans recours.
    window.prompt('Copie ce texte :', texte);
    btn.textContent = 'Copier le diagnostic';
    return;
  }
  setTimeout(() => (btn.textContent = 'Copier le diagnostic'), 1800);
});


// ── Reprise de session ─────────────────────────────────────────────────
// Recharger la page ne doit pas obliger à retaper : c'est tout l'intérêt
// d'un jeton. Il reste vérifié par le serveur à chaque appel.
(async function reprendre() {
  const s = lireSession();
  if (!s) return;
  try {
    dernierEtat = await etat(s.token);
    session = s;
    $('ecran-login').classList.add('cache');
    $('ecran-portail').classList.remove('cache');
    afficher(dernierEtat);
    minuterie = setInterval(rafraichir, 30000);
  } catch (_) {
    // Jeton périmé ou révoqué : on repart de l'écran de connexion,
    // sans message d'erreur — ce n'est pas une panne.
    oublierSession();
  }
})();
