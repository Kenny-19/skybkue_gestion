// ─── Skyblue — Dashboard propriétaire ───────────────────────────────────
// Lit les tables mirror_* de Supabase et affiche un résumé des ventes.
// Auth : vérifiée CÔTÉ SERVEUR (bs_portail_ouvrir) — le hachage ne quitte
// jamais la base.
// ─────────────────────────────────────────────────────────────────────────

const cfg = window.SKYBLUE_CONFIG;
const supa = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey);

// Rôles Flutter (uniquement pour afficher le libellé des serveurs dans
// la liste des ventes récentes — pas pour l'auth).
const ROLE_LABEL = { 0: 'Super Admin', 1: 'Admin', 2: 'Serveur' };

const LOCATION_LABEL = { 0: 'Restaurant', 1: 'Terrasse', 2: 'Hôtel' };
const CATEGORY_LABEL = { 0: 'Boissons', 1: 'Nourriture', 2: 'Chambres' };
// Palette — les MÊMES valeurs que le logiciel Windows (lib/theme/tokens.dart)
// et que le tailwind.config de index.html. Avant, app.js portait sa propre
// copie, restée sur l'ancien bleu #3EA5C9, plus un violet #8E44AD qui
// n'existait dans aucune charte.
const PALETTE = {
  ink: '#0E3A47',
  sky: '#2E7FA1',
  sunrise: '#D97E2B',
  success: '#2E8B57',
  warning: '#B8860B',
  danger: '#B93B33',
  slate: '#55606D',
  line: '#E0D8C9',
};

const CATEGORY_COLOR = {
  0: PALETTE.sky,      // boissons
  1: PALETTE.sunrise,  // nourriture
  2: PALETTE.ink,      // chambres
};

// Formats
const nfFc = new Intl.NumberFormat('fr-FR');
const money = (fc) => nfFc.format(Math.round(fc || 0)) + ' FC';
// Le taux réellement appliqué par l'application.
//
// Recopier une valeur à la main garantit qu'elle divergera : le site
// affichait ses dollars à 2800 pendant que l'application comptait à
// 2300, et les mêmes montants donnaient deux chiffres différents selon
// l'écran. Personne ne pouvait dire lequel était le bon.
//
// Depuis que l'hôtel tarifie en dollars, `mirror_rooms` porte les DEUX
// prix d'une chambre. Leur rapport EST le taux que l'application a
// utilisé pour convertir — et elle recalcule ces prix à chaque
// changement de taux. Le déduire, c'est donc être juste par
// construction, sans rien synchroniser.
//
// La valeur de `config.js` ne sert plus que de secours, avant le premier
// chargement des chambres.
let tauxFcParUsd = cfg.fcPerUsd;

/// Relit le taux depuis les chambres. Ignore celles dont un des deux
/// prix manque : un tarif à zéro donnerait une division absurde.
function majTauxDepuisChambres(rooms) {
  const taux = (rooms || [])
    .filter((r) => r.price_usd_cents > 0 && r.price_per_night_cents > 0)
    .map((r) => r.price_per_night_cents / (r.price_usd_cents / 100));
  if (!taux.length) return;
  // La médiane, pas la moyenne : une chambre au tarif saisi de travers
  // ne doit pas tirer le taux de tout le site.
  taux.sort((a, b) => a - b);
  tauxFcParUsd = Math.round(taux[Math.floor(taux.length / 2)]);
}

const moneyUsd = (fc) =>
  '$' + ((fc || 0) / (tauxFcParUsd || cfg.fcPerUsd)).toFixed(2);

// ── Session (localStorage) ─────────────────────────────────────────────
const SESSION_KEY = 'skyblue_dashboard_session';
function loadSession() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const s = JSON.parse(raw);
    if (Date.now() > s.expiresAt) {
      localStorage.removeItem(SESSION_KEY);
      return null;
    }
    return s;
  } catch (_) {
    return null;
  }
}
function saveSession(user) {
  localStorage.setItem(
    SESSION_KEY,
    JSON.stringify({
      user,
      expiresAt: Date.now() + cfg.sessionTtlMs,
    }),
  );
}
function clearSession() {
  localStorage.removeItem(SESSION_KEY);
}

// ── Auth : vérification CÔTÉ SERVEUR ───────────────────────────────────
//
// Ce qui se passait avant, et pourquoi c'était grave
// -------------------------------------------------
// Cette fonction lisait la ligne complète de `dashboard_owners` avec la
// clé anon — celle que tout visiteur reçoit dans `config.js` — puis
// comparait bcrypt dans le navigateur. Deux conséquences :
//
//   1. Le hachage du mot de passe était lisible par n'importe qui.
//      Vérifié le 24 septembre 2026 : une simple requête le rendait.
//   2. La comparaison étant côté client, l'écran de connexion ne
//      protégeait rien. Il suffisait d'ignorer cette fonction pour lire
//      les mêmes données.
//
// Désormais le mot de passe part au serveur, qui compare et ne renvoie
// qu'un nom. Le hachage ne quitte plus la base.
async function login_(loginInput, password) {
  const { data, error } = await supa.rpc('bs_session_ouvrir', {
    p_login: loginInput.trim(),
    p_password: password,
  });
  if (error) throw new Error('Connexion impossible. Vérifie le réseau.');
  if (!data || data.status !== 'ok') {
    throw new Error('Identifiants incorrects');
  }
  return {
    id: data.login,
    login: data.login,
    fullName: data.full_name,
    // Le jeton n'est pas encore utilisé par ce tableau de bord, qui lit
    // les tables miroir directement comme avant. Il est conservé pour
    // que la session puisse être fermée côté serveur, et parce que
    // c'est par là que passera la suite.
    token: data.token,
    // Le SERVEUR dit si ce compte a droit au portail technique. On ne le
    // déduit pas du rôle : Pamela possède un compte super admin côté
    // application, et un rôle ne suffit donc pas à distinguer.
    accesPortail: data.acces_portail === true,
    role: 0, // Toujours "propriétaire" côté dashboard — pas d'autre rôle.
  };
}

const loginScreen = document.getElementById('login-screen');
const dashboard = document.getElementById('dashboard');
let currentUser = null;
// Vue par défaut = aujourd'hui. Pamela veut voir "ce qui se passe MAINTENANT"
// à l'ouverture ; les autres périodes restent accessibles via le sélecteur.
let currentPeriodDays = 0;
let refreshTimer = null;
let revenueChart = null;

function showLogin() {
  currentUser = null;
  dashboard.classList.add('hidden');
  loginScreen.classList.remove('hidden');
  if (refreshTimer) {
    clearInterval(refreshTimer);
    refreshTimer = null;
  }
}
function showDashboard(user) {
  currentUser = user;
  loginScreen.classList.add('hidden');
  dashboard.classList.remove('hidden');
  document.getElementById('user-name').textContent = user.fullName;
  document.getElementById('user-role').textContent = ROLE_LABEL[user.role] || '';
  // L'entrée du portail technique n'apparaît que si le serveur l'a
  // autorisée pour ce compte. Masquer par défaut, révéler sur preuve —
  // l'inverse laisserait le lien visible une fraction de seconde, ou
  // définitivement en cas d'erreur de chargement.
  const lienPortail = document.getElementById('portail-link');
  if (lienPortail) {
    lienPortail.classList.toggle('hidden', user.accesPortail !== true);
  }
  // Hero perso : "Bonjour Pamela" (prénom seul).
  const firstName = (user.fullName || '').split(/\s+/)[0] || 'Bienvenue';
  const heroGreeting = document.getElementById('hero-greeting');
  const heroUser = document.getElementById('hero-user');
  if (heroGreeting) heroGreeting.textContent = _greetingLabel();
  if (heroUser) heroUser.textContent = firstName;
  renderPeriodSelector();
  updateTodayLabel();
  refreshDashboard();
  if (cfg.refreshMs > 0) {
    refreshTimer = setInterval(refreshDashboard, cfg.refreshMs);
  }
}

/// "Bonjour", "Bon après-midi" ou "Bonsoir" selon l'heure locale.
function _greetingLabel() {
  const h = new Date().getHours();
  if (h < 12) return 'Bonjour';
  if (h < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

// ── Formulaire login ───────────────────────────────────────────────────
document.getElementById('login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const btn = document.getElementById('login-btn');
  const errBox = document.getElementById('login-error');
  errBox.classList.add('hidden');
  errBox.textContent = '';
  btn.disabled = true;
  btn.textContent = 'Connexion…';
  try {
    const login = document.getElementById('login').value;
    const pwd = document.getElementById('password').value;
    // Plus de bcrypt dans le navigateur : le serveur compare et répond.
    const user = await login_(login, pwd);
    saveSession(user);
    showDashboard(user);
  } catch (err) {
    errBox.textContent = err.message || String(err);
    errBox.classList.remove('hidden');
  } finally {
    btn.disabled = false;
    btn.textContent = 'Se connecter';
  }
});


document.getElementById('logout-btn').addEventListener('click', () => {
  clearSession();
  showLogin();
});

// ── Sélecteur de période ───────────────────────────────────────────────
// ─── Fuseau horaire ────────────────────────────────────────────────────
//
// Toutes les bornes de journée sont calculées à l'heure de LUBUMBASHI
// (UTC+2, sans heure d'été), jamais à celle de l'appareil.
//
// Sans ça, le tableau de bord change de résultat selon où se trouve
// celui qui le consulte : Pamela en voyage verrait une « journée » qui
// commence à un autre moment que la caisse, et les montants ne
// correspondraient plus à ce que le poste a encaissé. Un écart de deux
// heures suffit à faire basculer les ventes de fin de soirée dans le
// mauvais jour.
const DECALAGE_LUBUMBASHI_MIN = 120; // UTC+2

/// Minuit à Lubumbashi, pour le jour contenant [ref], en instant absolu.
function minuitLubumbashi(ref = new Date()) {
  // On décale vers l'heure locale de Lubumbashi, on tronque au jour,
  // puis on revient en temps absolu.
  const decale = new Date(ref.getTime() + DECALAGE_LUBUMBASHI_MIN * 60000);
  const minuitDecale = Date.UTC(
      decale.getUTCFullYear(), decale.getUTCMonth(), decale.getUTCDate());
  return new Date(minuitDecale - DECALAGE_LUBUMBASHI_MIN * 60000);
}

const PERIODS = [
  { key: 'today', label: 'Aujourd\'hui', days: 0 },
  { key: '7d', label: '7 jours', days: 7 },
  { key: '30d', label: '30 jours', days: 30 },
  { key: '90d', label: '90 jours', days: 90 },
  { key: 'all', label: 'Tout', days: 3650 },
];
function renderPeriodSelector() {
  const wrap = document.getElementById('period-selector');
  wrap.innerHTML = '';
  for (const p of PERIODS) {
    const btn = document.createElement('button');
    btn.textContent = p.label;
    btn.className =
      'period-btn ' +
      (p.days === currentPeriodDays ? 'bg-ink text-white' : '');
    btn.addEventListener('click', () => {
      currentPeriodDays = p.days;
      renderPeriodSelector();
      refreshDashboard();
    });
    wrap.appendChild(btn);
  }
}

function updateTodayLabel() {
  const now = new Date();
  const opts = { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' };
  document.getElementById('today-label').textContent =
    'Mise à jour : ' +
    new Intl.DateTimeFormat('fr-FR', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    }).format(now) +
    ' · ' +
    new Intl.DateTimeFormat('fr-FR', opts).format(now);
}

document.getElementById('refresh-btn').addEventListener('click', refreshDashboard);

// ── Pagination ─────────────────────────────────────────────────────────
//
// Supabase ne renvoie jamais plus de 1000 lignes par requête (max_rows),
// et le fait SANS erreur. Toute lecture qui peut dépasser ce chiffre
// passe donc par ici. La même règle existe côté application Windows
// (lib/services/supabase_pages.dart).
const TAILLE_PAGE = 1000;

/**
 * Lit toutes les pages d'une requête. `fabrique` doit reconstruire la
 * requête à chaque appel et la trier sur une colonne unique, sinon deux
 * pages peuvent se chevaucher. Renvoie { data, error } comme supabase-js.
 */
async function toutesLesPages(fabrique) {
  const tout = [];
  for (let debut = 0; ; debut += TAILLE_PAGE) {
    const { data, error } = await fabrique().range(debut, debut + TAILLE_PAGE - 1);
    if (error) return { data: null, error };
    const lot = data || [];
    tout.push(...lot);
    if (lot.length < TAILLE_PAGE) return { data: tout, error: null };
  }
}

/** Même chose pour un filtre `in` sur une longue liste d'ids. */
async function toutesLesPagesParIds(ids, fabrique, taillePaquet = 100) {
  const tout = [];
  for (let i = 0; i < ids.length; i += taillePaquet) {
    const res = await toutesLesPages(() => fabrique(ids.slice(i, i + taillePaquet)));
    if (res.error) return res;
    tout.push(...res.data);
  }
  return { data: tout, error: null };
}

// ── Fetch + agrégations ────────────────────────────────────────────────
async function fetchPeriod() {
  // days=0 → aujourd'hui à partir de minuit local.
  let sinceIso;
  // Début de la période affichée, à l'heure de Lubumbashi.
  let debut = minuitLubumbashi();
  if (currentPeriodDays > 0) {
    debut = new Date(debut.getTime() - currentPeriodDays * 86400000);
  }
  sinceIso = debut.toISOString();

  // On remonte deux fois plus loin pour ramener AUSSI la période
  // précédente, dans la même requête. Sans point de comparaison, un
  // chiffre ne dit pas s'il est bon : c'est ce qui manquait le plus.
  const dureeJours = currentPeriodDays === 0 ? 1 : currentPeriodDays;
  const debutPrecedent = new Date(debut);
  debutPrecedent.setDate(debutPrecedent.getDate() - dureeJours);
  const depuisIsoAvecPrecedent = debutPrecedent.toISOString();
  // Tout est paginé (cf. toutesLesPages). Les lignes d'articles étaient
  // lues d'un bloc, TOUTE la table : 1000 lignes reçues sur 2792, et les
  // ventes récentes arrivaient sans leurs articles.
  const [salesRes, articlesRes, usersRes, staysRes] = await Promise.all([
    toutesLesPages(() => supa
        .from('mirror_sales')
        .select('*')
        .gte('sold_at', depuisIsoAvecPrecedent)
        .order('sold_at', { ascending: false })
        .order('id', { ascending: false })),
    // Sélection étendue : les colonnes stock sont nécessaires pour
    // afficher la carte "Stock à ravitailler".
    toutesLesPages(() => supa
        .from('mirror_articles')
        .select(
            'id, name, category, track_stock, stock_qty, threshold, unit, active')
        .order('id')),
    toutesLesPages(() => supa
        .from('mirror_users')
        .select('id, full_name')
        .order('id')),
    // Séjours facturés : le chiffre d'affaires hôtel, invisible
    // jusqu'ici faute d'être miroité.
    toutesLesPages(() => supa
        .from('mirror_stays')
        .select(
            'id, checkout_at, guest_full_name, subtotal_cents, remise_cents, payer_name')
        .gte('checkout_at', depuisIsoAvecPrecedent)
        .order('checkout_at', { ascending: false })
        .order('id', { ascending: false })),
  ]);
  if (salesRes.error) throw new Error(salesRes.error.message);

  // Seulement les lignes des ventes de la période (et de la précédente),
  // plus toute la table à chaque rafraîchissement.
  const linesRes = await toutesLesPagesParIds(
      (salesRes.data || []).map((s) => s.id),
      (paquet) => supa
          .from('mirror_sale_lines')
          .select('*')
          .in('sale_id', paquet)
          .order('id'));
  if (linesRes.error) throw new Error(linesRes.error.message);

  const allLines = linesRes.data || [];
  const articles = articlesRes.data || [];
  const users = usersRes.data || [];

  // Séparation des deux périodes. `sales` reste STRICTEMENT la période
  // affichée : le graphique, les ventes récentes et les indicateurs
  // continuent de travailler exactement comme avant.
  //
  // Comparaison sur des TIMESTAMPS, jamais sur les chaînes. PostgREST
  // renvoie « 2026-09-16T06:00:00+00:00 » là où toISOString() écrit
  // « …Z » : comparer ces deux textes donne un résultat faux dès que le
  // format diffère d'un caractère, et toutes les ventes basculaient du
  // mauvais côté. C'est ce qui cassait le sélecteur de période.
  const toutes = salesRes.data || [];
  const debutMs = debut.getTime();
  const ms = (v) => new Date(v).getTime();
  const sales = toutes.filter((s) => ms(s.sold_at) >= debutMs);
  const ventesPrecedentes = toutes.filter((s) => ms(s.sold_at) < debutMs);

  const saleIds = new Set(sales.map((s) => s.id));
  const lines = allLines.filter((l) => saleIds.has(l.sale_id));
  const idsPrecedents = new Set(ventesPrecedentes.map((s) => s.id));
  const lignesPrecedentes = allLines.filter((l) => idsPrecedents.has(l.sale_id));

  // mirror_stays peut ne pas exister tant que le SQL n'est pas passé :
  // le tableau de bord doit continuer à fonctionner sans, plutôt que de
  // tomber en panne sur une table absente.
  const toutSejours = staysRes && !staysRes.error ? staysRes.data || [] : [];
  const stays = toutSejours.filter((s) => ms(s.checkout_at) >= debutMs);
  const sejoursPrecedents =
      toutSejours.filter((s) => ms(s.checkout_at) < debutMs);

  return {
    sales,
    lines,
    articles,
    users,
    stays,
    sejoursPrecedents,
    ventesPrecedentes,
    lignesPrecedentes,
  };
}

/// Chiffre d'affaires hôtel d'une liste de séjours facturés.
///
/// Net réellement facturé : sous-total MOINS la remise accordée. C'est
/// ce que Pamela veut voir — pas le tarif catalogue, mais ce qui est
/// entré en caisse.
function caHotel(stays) {
  return (stays || []).reduce(
    (acc, s) => acc + ((s.subtotal_cents || 0) - (s.remise_cents || 0)), 0);
}

function computeKpis({ sales, lines }) {
  const totalCents = sales.reduce((acc, s) => {
    const sLines = lines.filter((l) => l.sale_id === s.id);
    return acc + sLines.reduce((a, l) => a + l.qty * l.unit_price_cents, 0);
  }, 0);
  const count = sales.length;
  const avg = count > 0 ? Math.round(totalCents / count) : 0;
  // Ce qui reste VRAIMENT dû.
  //
  // Depuis les règlements partiels, une dette non soldée n'est plus
  // forcément due en entier : le client a pu verser un acompte. On
  // retranche donc `paid_cents`, sans quoi l'encours serait toujours
  // surévalué — la pire direction pour un chiffre qui sert à décider
  // s'il faut relancer quelqu'un.
  //
  // Une vente dont les acomptes couvrent tout mais que le poste n'a pas
  // encore marquée soldée ne compte plus : reste = 0.
  const openCredits = sales
    .filter((s) => s.on_credit && !s.settled_at)
    .map((s) => {
      const sLines = lines.filter((l) => l.sale_id === s.id);
      const total = sLines.reduce((a, l) => a + l.qty * l.unit_price_cents, 0);
      const paye = s.paid_cents || 0;
      return { vente: s, total, paye, reste: Math.max(0, total - paye) };
    })
    .filter((d) => d.reste > 0);
  const openCreditsTotal = openCredits.reduce((a, d) => a + d.reste, 0);
  const openCreditsPartiels = openCredits.filter((d) => d.paye > 0).length;
  return {
    totalCents,
    count,
    avg,
    openCreditsTotal,
    openCreditsCount: openCredits.length,
    openCreditsPartiels,
    openCreditsDetail: openCredits,
  };
}

/// Compare la période affichée à la précédente.
///
/// Retourne null quand la comparaison n'a pas de sens — pas d'historique,
/// ou période précédente vide. Afficher « +100 % » parce qu'on part de
/// zéro serait trompeur.
function calculerTendance(actuel, precedent) {
  if (!precedent || precedent <= 0) return null;
  const ecart = ((actuel - precedent) / precedent) * 100;
  if (Math.abs(ecart) < 3) return { sens: 'stable', pct: 0 };
  return { sens: ecart > 0 ? 'hausse' : 'baisse', pct: Math.abs(Math.round(ecart)) };
}

/// La phrase que Pamela lit en premier.
///
/// Elle répond à ses deux questions réelles — « combien j'ai fait, et
/// est-ce que ça va » puis « qu'est-ce qui m'attend » — au lieu de la
/// laisser assembler quatre tuiles dans sa tête.
function renderResume(k, tendance, data) {
  const el = document.getElementById('daily-summary');
  if (!el) return;

  const periode = PERIODS.find((p) => p.days === currentPeriodDays);
  const quand = currentPeriodDays === 0
    ? "aujourd'hui"
    : `ces ${periode ? periode.label.toLowerCase() : currentPeriodDays + ' jours'}`;

  let phrase;
  if (k.count === 0) {
    phrase = `Aucune vente enregistrée ${quand}.`;
  } else {
    const hotel = caHotel(data.stays);
    phrase = hotel > 0
      ? `${money(k.totalCents + hotel)} encaissés ${quand}, dont ` +
        `${money(hotel)} sur l'hôtel`
      : `${money(k.totalCents)} encaissés ${quand}`;
    if (tendance) {
      if (tendance.sens === 'stable') {
        phrase += ", au même niveau que la période précédente.";
      } else {
        const mot = tendance.sens === 'hausse' ? 'de plus' : 'de moins';
        phrase += `, ${tendance.pct} % ${mot} que la période précédente.`;
      }
    } else {
      phrase += '.';
    }
  }

  // Ce qui attend une décision d'elle, et rien d'autre.
  const enAttente = [];
  if (k.openCreditsCount > 0) {
    enAttente.push(
      k.openCreditsCount === 1
        ? '1 client doit encore payer'
        : `${k.openCreditsCount} clients doivent encore payer`);
  }
  const epuises = (data.articles || []).filter(
    (a) => a.track_stock && a.active && (a.stock_qty || 0) <= 0).length;
  if (epuises > 0) {
    enAttente.push(
      epuises === 1 ? '1 article est épuisé' : `${epuises} articles sont épuisés`);
  }

  el.innerHTML =
    `<span class="text-ink font-semibold">${phrase}</span>` +
    (enAttente.length
      ? ` <span class="text-slate">${enAttente.join(' et ')}.</span>`
      : '');
}

/// Le chiffre d'affaires hôtel, que Pamela ne voyait pas du tout.
function renderHotel(data) {
  const carte = document.getElementById('hotel-card');
  const corps = document.getElementById('hotel-body');
  const titre = document.getElementById('hotel-title');
  if (!carte || !corps || !titre) return;

  const stays = data.stays || [];
  if (stays.length === 0) {
    // Tant que le miroir des séjours n'est pas alimenté, la carte reste
    // masquée : un bloc vide ferait croire à une panne.
    carte.classList.add('hidden');
    return;
  }
  carte.classList.remove('hidden');

  const ca = caHotel(stays);
  const caPrec = caHotel(data.sejoursPrecedents);
  const t = calculerTendance(ca, caPrec);

  titre.textContent =
    `${money(ca)} sur ${stays.length} séjour${stays.length > 1 ? 's' : ''}`;

  const evolution = t
    ? (t.sens === 'stable'
        ? '<span class="text-slate">Stable vs période précédente</span>'
        : `<span class="${t.sens === 'hausse' ? 'text-success' : 'text-danger'} font-semibold">` +
          `${t.sens === 'hausse' ? '▲ +' : '▼ −'}${t.pct} % vs période précédente</span>`)
    : '';

  corps.innerHTML =
    (evolution ? `<p class="mb-3">${evolution}</p>` : '') +
    stays.slice(0, 8).map((s) => {
      const net = (s.subtotal_cents || 0) - (s.remise_cents || 0);
      const qui = s.payer_name || s.guest_full_name || '—';
      return `<div class="flex items-center gap-3 py-2.5 border-b border-line last:border-0">
        <div class="flex-1 min-w-0">
          <p class="font-semibold text-ink truncate">${qui}</p>
          <p class="text-xs text-slate">${dateCourte(s.checkout_at)}</p>
        </div>
        <span class="font-mono font-bold text-ink shrink-0">${money(net)}</span>
      </div>`;
    }).join('');
}

function dateCourte(iso) {
  try {
    return new Date(iso).toLocaleDateString('fr-FR',
        { day: 'numeric', month: 'short', timeZone: 'Africa/Lubumbashi' });
  } catch (_) {
    return '';
  }
}

function renderKpis(k, tendance) {
  const grid = document.getElementById('kpi-grid');
  const cards = [
    {
      label: 'Chiffre d\'affaires',
      value: money(k.totalCents),
      // La comparaison remplace la conversion en dollars sur cette tuile :
      // elle renseigne davantage. Le dollar reste sur les autres.
      sub: tendance
        ? tendance.sens === 'stable'
          ? 'Stable vs période précédente'
          : (tendance.sens === 'hausse' ? '▲ +' : '▼ −') +
            tendance.pct +
            ' % vs période précédente'
        : '≈ ' + moneyUsd(k.totalCents),
      subColor: tendance
        ? tendance.sens === 'hausse'
          ? 'text-success'
          : tendance.sens === 'baisse'
            ? 'text-danger'
            : 'text-slate'
        : 'text-slate',
      color: 'text-ink',
    },
    {
      label: 'Ventes',
      value: nfFc.format(k.count),
      sub: k.count === 0 ? 'Aucune vente' : k.count === 1 ? '1 transaction' : `${k.count} transactions`,
      color: 'text-sky',
    },
    {
      label: 'Dépense moyenne par vente',
      value: money(k.avg),
      sub: k.count > 0 ? '≈ ' + moneyUsd(k.avg) : '—',
      color: 'text-success',
    },
    {
      label: 'Reste à encaisser',
      value: money(k.openCreditsTotal),
      sub:
        k.openCreditsCount === 0
          ? 'Rien à recouvrer'
          : k.openCreditsPartiels > 0
            ? `${k.openCreditsCount} impayé(s), dont ` +
              `${k.openCreditsPartiels} déjà entamé(s)`
            : `${k.openCreditsCount} ticket(s) impayé(s)`,
      color: k.openCreditsTotal > 0 ? 'text-danger' : 'text-slate',
    },
  ];
  grid.innerHTML = cards
    .map(
      (c) => `
        <div class="fade-in">
          <p class="eyebrow">${c.label}</p>
          <p class="kpi-value mt-1 ${c.color}">${c.value}</p>
          <p class="text-xs sm:text-sm mt-1 font-medium ${c.subColor || 'text-slate'}">${c.sub}</p>
        </div>
      `,
    )
    .join('');
}

// ── Graphique CA par jour ──────────────────────────────────────────────
function renderRevenueChart({ sales, lines }) {
  // Bucket par jour (yyyy-mm-dd).
  const totalsByDay = {};
  for (const s of sales) {
    const day = s.sold_at.slice(0, 10);
    const sLines = lines.filter((l) => l.sale_id === s.id);
    const total = sLines.reduce((a, l) => a + l.qty * l.unit_price_cents, 0);
    totalsByDay[day] = (totalsByDay[day] || 0) + total;
  }
  const days = Object.keys(totalsByDay).sort();
  const values = days.map((d) => totalsByDay[d]);
  const total = values.reduce((a, b) => a + b, 0);
  document.getElementById('chart-total-label').textContent =
    money(total) + '   ·   ≈ ' + moneyUsd(total);

  const ctx = document.getElementById('revenue-chart');
  if (revenueChart) revenueChart.destroy();
  revenueChart = new window.Chart(ctx, {
    type: 'bar',
    data: {
      labels: days.map((d) => {
        const [y, m, dd] = d.split('-');
        return `${dd}/${m}`;
      }),
      datasets: [
        {
          label: 'CA (FC)',
          data: values,
          backgroundColor: PALETTE.sky,
          borderRadius: 6,
          maxBarThickness: 32,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            callback: (v) => nfFc.format(v),
            color: PALETTE.slate,
            font: { size: 10 },
          },
          grid: { color: PALETTE.line },
        },
        x: {
          ticks: { color: PALETTE.slate, font: { size: 11 } },
          grid: { display: false },
        },
      },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: (ctx) => money(ctx.parsed.y),
          },
        },
      },
    },
  });
}

// ── Top articles ───────────────────────────────────────────────────────
function renderTopArticles({ lines, articles }) {
  const byName = {};
  for (const l of lines) {
    byName[l.article_name] = (byName[l.article_name] || 0) + l.qty * l.unit_price_cents;
  }
  const top = Object.entries(byName)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5);
  const max = top.length > 0 ? top[0][1] : 1;
  const box = document.getElementById('top-articles');
  if (top.length === 0) {
    box.innerHTML =
      '<p class="text-sm text-slateSoft italic">Aucune vente sur la période.</p>';
    return;
  }
  box.innerHTML = top
    .map(([name, total]) => {
      const pct = Math.round((total / max) * 100);
      return `
        <div class="mb-3">
          <div class="flex items-baseline justify-between">
            <span class="text-sm font-medium text-ink">${name}</span>
            <span class="font-mono text-xs font-semibold text-slate">${money(total)}</span>
          </div>
          <div class="mt-1 h-2 rounded-full bg-papyrus overflow-hidden">
            <div class="h-full bg-sky rounded-full" style="width: ${pct}%;"></div>
          </div>
        </div>
      `;
    })
    .join('');
}

// ── Ventes récentes ────────────────────────────────────────────────────
function renderRecentSales({ sales, lines, users }) {
  const usersById = Object.fromEntries(users.map((u) => [u.id, u.full_name]));
  const rows = sales.slice(0, 15).map((s) => {
    const sLines = lines.filter((l) => l.sale_id === s.id);
    const total = sLines.reduce((a, l) => a + l.qty * l.unit_price_cents, 0);
    const itemsCount = sLines.reduce((a, l) => a + l.qty, 0);
    const d = new Date(s.sold_at);
    const dt = new Intl.DateTimeFormat('fr-FR', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    }).format(d);
    const serverName =
      s.server_user_id != null ? usersById[s.server_user_id] || '—' : '—';
    const locLabel = LOCATION_LABEL[s.location] || '—';
    const creditBadge = s.on_credit
      ? (s.settled_at
          ? '<span class="ml-2 text-[10px] px-1.5 py-0.5 rounded bg-success/10 text-success font-semibold">RÉGLÉE</span>'
          : '<span class="ml-2 text-[10px] px-1.5 py-0.5 rounded bg-danger/10 text-danger font-semibold">CRÉDIT</span>')
      : '';
    // Ligne compacte "carte" — sans tableau : deux zones (info gauche +
    // total droit). Aucun scroll horizontal, meme sur mobile.
    return `
      <div class="py-2.5 flex items-center gap-3">
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2 flex-wrap">
            <span class="font-mono text-[11px] text-slateSoft">#${String(s.numero_local ?? s.id).padStart(4, '0')}</span>
            <span class="font-mono text-xs text-ink font-semibold">${dt}</span>
            ${creditBadge}
          </div>
          <p class="mt-0.5 text-xs text-slate truncate">
            ${escapeHtml(locLabel)} · ${itemsCount} art. · ${escapeHtml(serverName)}
          </p>
        </div>
        <div class="font-mono text-sm font-bold shrink-0">${money(total)}</div>
      </div>
    `;
  });
  document.getElementById('recent-sales-body').innerHTML =
    rows.length > 0
      ? rows.join('')
      : '<p class="py-6 text-center text-sm text-slateSoft italic">Aucune vente sur la période.</p>';
}

// ── Alertes stock ──────────────────────────────────────────────────────
let _stockFilter = 'all';

function renderStockAlerts({ articles }) {
  // On ne prend que les articles suivis, actifs, sous ou égal au seuil.
  const tracked = (articles || []).filter(
    (a) =>
      a.track_stock === true &&
      a.active !== false &&
      (a.threshold ?? 0) > 0 &&
      (a.stock_qty ?? 0) <= a.threshold,
  );

  // Tri : les plus urgents (ratio bas + épuisés) en tête.
  tracked.sort((a, b) => {
    const ra = a.threshold > 0 ? a.stock_qty / a.threshold : 0;
    const rb = b.threshold > 0 ? b.stock_qty / b.threshold : 0;
    return ra - rb;
  });

  const out = tracked.filter((a) => a.stock_qty === 0);
  const critical = tracked.filter(
    (a) => a.stock_qty > 0 && a.stock_qty * 2 <= a.threshold,
  );

  let filtered = tracked;
  if (_stockFilter === 'out') filtered = out;
  else if (_stockFilter === 'critical') filtered = critical;

  // Titre récap au dessus.
  const title = document.getElementById('stock-title');
  if (tracked.length === 0) {
    title.textContent = 'Tout est en stock';
  } else {
    title.textContent =
      `${tracked.length} article(s) sous le seuil` +
      (out.length > 0 ? ` · ${out.length} épuisé(s)` : '');
  }

  const body = document.getElementById('stock-alerts-body');
  if (filtered.length === 0) {
    body.innerHTML =
      '<p class="py-6 text-center text-sm text-slateSoft italic">Rien à ravitailler dans cette catégorie.</p>';
    return;
  }

  body.innerHTML = filtered
    .map((a) => {
      const catLabel = CATEGORY_LABEL[a.category] || '—';
      const catColor = CATEGORY_COLOR[a.category] || PALETTE.slate;
      const ratio =
        a.threshold > 0 ? Math.max(0, Math.min(1, a.stock_qty / a.threshold)) : 0;
      const pct = Math.round(ratio * 100);
      const barColor = a.stock_qty === 0
        ? PALETTE.danger
        : a.stock_qty * 2 <= a.threshold
          ? PALETTE.sunrise
          : PALETTE.sky;
      const suggest = Math.max(0, a.threshold * 2 - a.stock_qty);
      const badge =
        a.stock_qty === 0
          ? '<span class="ml-1 text-[10px] px-1.5 py-0.5 rounded bg-danger/10 text-danger font-semibold">ÉPUISÉ</span>'
          : '';
      // Ligne compacte, sans tableau : nom + catégorie + barre + chiffres.
      return `
        <div class="py-3">
          <div class="flex items-center gap-3">
            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-2 flex-wrap">
                <span class="text-sm font-semibold text-ink truncate">${escapeHtml(a.name)}</span>
                <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded" style="background:${catColor}20;color:${catColor}">${escapeHtml(catLabel)}</span>
                ${badge}
              </div>
              <div class="mt-1.5 h-1.5 rounded-full bg-papyrus overflow-hidden">
                <div class="h-full rounded-full" style="width:${Math.max(pct, 4)}%;background:${barColor}"></div>
              </div>
              <p class="mt-1 text-[11px] text-slate">
                <span class="font-mono font-bold" style="color:${barColor}">${a.stock_qty}</span> / ${a.threshold} ${escapeHtml(a.unit || '')} · ${pct}%
              </p>
            </div>
            <div class="shrink-0 text-right">
              <p class="text-[10px] text-slateSoft uppercase">À cmd.</p>
              <p class="font-mono text-base font-bold text-success">+${suggest}</p>
            </div>
          </div>
        </div>
      `;
    })
    .join('');
}

// Boutons de filtre (Tout / Critique / Épuisé).
document.getElementById('stock-filters').addEventListener('click', (e) => {
  const btn = e.target.closest('.stock-filter-btn');
  if (!btn) return;
  _stockFilter = btn.dataset.filter;
  document.querySelectorAll('.stock-filter-btn').forEach((b) => {
    if (b.dataset.filter === _stockFilter) {
      // La taille et l'espacement vivent dans le CSS (.stock-filter-btn) :
      // les réécrire ici ferait changer les boutons d'aspect au premier clic.
      b.className = 'stock-filter-btn bg-ink text-white';
    } else {
      b.className = 'stock-filter-btn';
    }
  });
  // Re-rendu avec les données courantes en cache.
  if (_lastData) renderStockAlerts(_lastData);
});

// ── Refresh global ─────────────────────────────────────────────────────
let _lastData = null;

async function refreshDashboard() {
  updateTodayLabel();
  try {
    const data = await fetchPeriod();
    _lastData = data;
    const k = computeKpis(data);
    // La période précédente passe par le MÊME calcul : une seule façon
    // de compter, donc une comparaison honnête.
    const precedent = computeKpis({
      sales: data.ventesPrecedentes || [],
      lines: data.lignesPrecedentes || [],
    });
    const tendance = calculerTendance(k.totalCents, precedent.totalCents);
    renderKpis(k, tendance);
    renderResume(k, tendance, data);
    renderHotel(data);
    renderRevenueChart(data);
    renderTopArticles(data);
    renderStockAlerts(data);
    renderRecentSales(data);
  } catch (err) {
    console.error('Refresh failed:', err);
    // On garde l'ancien état affiché, pas d'écran vide.
  }
  // Charge les demandes de ravitaillement en parallèle du reste (les
  // erreurs de ce fetch ne doivent PAS invalider le dashboard entier).
  try {
    await refreshSupplyRequests();
  } catch (err) {
    console.error('Supply requests refresh failed:', err);
  }
  try {
    await refreshRooms();
  } catch (err) {
    console.error('Rooms refresh failed:', err);
  }
  try {
    await refreshSentReports();
  } catch (err) {
    console.error('Sent reports refresh failed:', err);
  }
}

// ── Rapports envoyés depuis l'app ──────────────────────────────────────
// Table `sent_reports` : chaque ligne = un PDF uploadé dans le bucket.
// On affiche les 20 derniers avec un bouton "Télécharger".
async function refreshSentReports() {
  const { data, error } = await supa
    .from('sent_reports')
    .select('*')
    .order('generated_at', { ascending: false })
    .limit(20);
  if (error) throw error;

  const card = document.getElementById('sent-reports-card');
  const title = document.getElementById('sent-reports-title');
  const body = document.getElementById('sent-reports-body');
  const list = data || [];

  if (list.length === 0) {
    card.classList.add('hidden');
    return;
  }
  card.classList.remove('hidden');
  const unread = list.filter((r) => !r.read_at).length;
  title.textContent = unread > 0
    ? `${unread} non lu(s) · ${list.length} au total`
    : `${list.length} rapport(s) reçus`;

  body.innerHTML = list.map(renderSentReportRow).join('');
  body.querySelectorAll('a[data-report-id]').forEach((a) => {
    a.addEventListener('click', () => markReportRead(a.dataset.reportId));
  });
  body.querySelectorAll('button[data-delete-report-id]').forEach((b) => {
    b.addEventListener('click', () =>
      handleDeleteReport(b.dataset.deleteReportId, b.dataset.storagePath));
  });
}

async function handleDeleteReport(id, storagePath) {
  const yes = window.confirm(
    'Supprimer ce rapport ?\n\n' +
      'Le PDF sera retiré du site et du stockage. Cette action est définitive.',
  );
  if (!yes) return;
  try {
    // 1. Supprime le fichier du bucket. storage_path est de la forme
    //    "bucket/chemin/complet.pdf" (nouveau format) ou juste "reports/..."
    //    (ancien format — bucket=reports par défaut).
    if (storagePath && storagePath !== 'null') {
      let bucket = 'reports';
      let path = storagePath;
      const slashIdx = storagePath.indexOf('/');
      if (slashIdx > 0 &&
          (storagePath.startsWith('reports/') ||
           storagePath.startsWith('articles/'))) {
        // Détecter si le préfixe est un nom de bucket connu
        const prefix = storagePath.substring(0, slashIdx);
        if (prefix === 'articles' || prefix === 'reports') {
          bucket = prefix;
          path = storagePath.substring(slashIdx + 1);
        }
      }
      try {
        await supa.storage.from(bucket).remove([path]);
      } catch (_) { /* fichier peut-être déjà absent */ }
    }
    // 2. Supprime la ligne en base.
    const { error } = await supa.from('sent_reports').delete().eq('id', id);
    if (error) throw error;
    await refreshSentReports();
  } catch (e) {
    alert('Suppression impossible : ' + (e.message || e));
  }
}

function renderSentReportRow(r) {
  const when = r.generated_at ? relativeTime(r.generated_at) : '';
  const size = r.size_bytes > 0
    ? `${Math.round(r.size_bytes / 1024)} Ko`
    : '';
  const kindBadge = r.kind === 'detailed' ? 'DÉTAILLÉ' : 'SYNTHÉTIQUE';
  const kindColor =
    r.kind === 'detailed' ? 'bg-slate/10 text-slate' : 'bg-sky/10 text-sky';
  const unreadPill = r.read_at
    ? ''
    : '<span class="ml-2 inline-block px-2 py-0.5 text-[10px] font-bold rounded bg-sunrise/20 text-sunrise">NOUVEAU</span>';
  const url = r.public_url || '#';
  return `
    <div class="flex items-center justify-between gap-3 py-2 border-b border-line last:border-0">
      <div class="min-w-0 flex-1">
        <div class="flex items-center flex-wrap gap-2">
          <span class="inline-block px-2 py-0.5 text-[10px] font-bold rounded ${kindColor}">${kindBadge}</span>
          <p class="text-sm font-semibold text-ink truncate">${escapeHtml(r.name || 'Rapport')}</p>
          ${unreadPill}
        </div>
        <p class="text-xs text-slate mt-1">
          ${escapeHtml(r.period || '')}${r.period ? ' · ' : ''}
          par ${escapeHtml(r.generated_by_login || 'inconnu')} · ${when}${size ? ' · ' + size : ''}
        </p>
      </div>
      <div class="shrink-0 flex items-center gap-1.5">
        <a href="${url}"
           target="_blank" rel="noopener"
           data-report-id="${r.id}"
           class="px-3 py-1.5 text-xs font-semibold rounded-md bg-sky text-white hover:opacity-90 transition inline-flex items-center gap-1">
           <span class="hidden sm:inline">Télécharger</span>
        </a>
        <button
           data-delete-report-id="${r.id}"
           data-storage-path="${escapeHtml(r.storage_path || '')}"
           title="Supprimer"
           class="px-2 py-1.5 text-xs font-semibold rounded-md border border-danger text-danger hover:bg-danger hover:text-white transition">
           Supprimer
        </button>
      </div>
    </div>
  `;
}

async function markReportRead(id) {
  try {
    await supa
      .from('sent_reports')
      .update({ read_at: new Date().toISOString() })
      .eq('id', id)
      .is('read_at', null);
  } catch (_) { /* best-effort */ }
}

// ── Chambres — activité temps réel ─────────────────────────────────────
// Statuts identiques à DbRoomStatus dans lib/data/schema.dart :
//   0=libre, 1=occupee, 2=nettoyage, 3=maintenance
const ROOM_STATUS = { 0: 'libre', 1: 'occupée', 2: 'nettoyage', 3: 'maintenance' };
const ROOM_STATUS_COLOR = {
  0: PALETTE.success,
  1: PALETTE.sky,
  2: PALETTE.warning,
  3: PALETTE.slate,
};

async function refreshRooms() {
  const { data, error } = await toutesLesPages(() => supa
    .from('mirror_rooms')
    .select('*')
    .order('number', { ascending: true }));
  if (error) throw error;
  const rooms = data || [];
  majTauxDepuisChambres(rooms);
  const card = document.getElementById('rooms-card');
  if (rooms.length === 0) {
    card.classList.add('hidden');
    return;
  }
  card.classList.remove('hidden');

  const total = rooms.length;
  const occupied = rooms.filter((r) => Number(r.status) === 1);
  const free = rooms.filter((r) => Number(r.status) === 0).length;
  const cleaning = rooms.filter((r) => Number(r.status) === 2).length;

  // Départs en retard : occupée + date de départ passée. Les journées se
  // comparent à l'heure de Lubumbashi, pas à celle de l'appareil — sinon
  // un départ du soir apparaîtrait « en retard » pour qui consulte le
  // tableau depuis un autre fuseau.
  const today = minuitLubumbashi();
  const overdue = [];
  const todayOut = [];
  const upcoming = [];
  for (const r of occupied) {
    if (!r.checkout_date) continue;
    const c = minuitLubumbashi(new Date(r.checkout_date));
    if (c < today) overdue.push(r);
    else if (c.getTime() === today.getTime()) todayOut.push(r);
    else upcoming.push(r);
  }

  const pct = Math.round((occupied.length / total) * 100);

  document.getElementById('rooms-title').textContent =
    `${occupied.length}/${total} chambres occupées (${pct}%)`;

  const stats = document.getElementById('rooms-stats');
  const badges = [
    { l: `${free} libres`, c: PALETTE.success },
    { l: `${cleaning} à nettoyer`, c: PALETTE.warning },
  ];
  if (overdue.length > 0) {
    badges.push({ l: `${overdue.length} en retard`, c: PALETTE.danger });
  }
  stats.innerHTML = badges
    .map(
      (b) => `<span class="text-xs font-semibold px-2 py-1 rounded"
                     style="background:${b.c}20;color:${b.c}">${b.l}</span>`,
    )
    .join('');

  // Corps : listes départs (retard rouge → aujourd'hui orange → à venir).
  const sections = [];
  if (overdue.length > 0) {
    sections.push(renderRoomSection('Départs en retard', overdue, true));
  }
  if (todayOut.length > 0) {
    sections.push(renderRoomSection('Départs aujourd\'hui', todayOut, false));
  }
  if (upcoming.length > 0) {
    sections.push(renderRoomSection('Départs à venir', upcoming, false));
  }
  if (sections.length === 0) {
    document.getElementById('rooms-body').innerHTML =
      '<p class="text-sm text-slate italic">Aucune chambre occupée en ce moment.</p>';
    return;
  }
  document.getElementById('rooms-body').innerHTML = sections.join('');
}

function renderRoomSection(title, rooms, danger) {
  const color = danger ? PALETTE.danger : PALETTE.slate;
  const rows = rooms
    .map((r) => {
      const dt = r.checkout_date
        ? new Date(r.checkout_date).toLocaleDateString('fr-FR', {
            timeZone: 'Africa/Lubumbashi',
            weekday: 'short',
            day: '2-digit',
            month: 'short',
          })
        : '—';
      const badge = danger
        ? '<span class="text-xs font-semibold px-1.5 py-0.5 rounded bg-danger/10 text-danger">EN RETARD</span>'
        : '';
      return `
        <div class="py-2 flex items-center gap-3">
          <span class="font-mono text-sm font-bold shrink-0" style="color:${ROOM_STATUS_COLOR[1]}">Ch. ${escapeHtml(r.number)}</span>
          <div class="min-w-0 flex-1">
            <p class="text-sm font-medium text-ink truncate">${escapeHtml(r.current_guest || '—')}</p>
            <p class="text-[11px] text-slate truncate">${escapeHtml(r.type || '')} · Départ : ${dt}</p>
          </div>
          ${badge}
        </div>
      `;
    })
    .join('');
  return `
    <div class="mt-3">
      <p class="text-xs font-bold uppercase tracking-widest mb-1" style="color:${color}">${title}</p>
      <div class="divide-y divide-line">${rows}</div>
    </div>
  `;
}

// ── Demandes de ravitaillement ─────────────────────────────────────────
// Emplacement libellé + icône SVG inline (aucune dep).
const SUPPLY_LOC_LABEL = { 0: 'Restaurant', 1: 'Terrasse', 2: 'Hôtel' };
const SUPPLY_LOC_ICON = {
  0: 'Restaurant',
  1: 'Terrasse',
  2: 'Hôtel',
};

async function refreshSupplyRequests() {
  const { data, error } = await toutesLesPages(() => supa
    .from('supply_requests')
    .select('*')
    .eq('status', 'pending')
    .order('requested_at', { ascending: false })
    .order('id', { ascending: false }));
  if (error) throw error;

  const list = (data || []).map((r) => ({
    id: r.id,
    articleName: r.article_name,
    location: Number(r.location),
    qtyRequested: r.qty_requested,
    qtyAtRequest: r.qty_at_request,
    thresholdAtRequest: r.threshold_at_request,
    requestedBy: r.requested_by_login,
    requestedAt: r.requested_at,
    note: r.review_note,
  }));

  const card = document.getElementById('supply-requests-card');
  const title = document.getElementById('supply-requests-title');
  const body = document.getElementById('supply-requests-body');

  if (list.length === 0) {
    card.classList.add('hidden');
    return;
  }
  card.classList.remove('hidden');
  title.textContent = list.length === 1
    ? '1 demande en attente'
    : `${list.length} demandes en attente`;

  // Groupé par emplacement.
  const groups = { 0: [], 1: [], 2: [] };
  for (const r of list) groups[r.location].push(r);

  const html = [];
  for (const locKey of Object.keys(groups)) {
    const arr = groups[locKey];
    if (arr.length === 0) continue;
    const locName = SUPPLY_LOC_LABEL[locKey] || 'Autre';
    const locIcon = SUPPLY_LOC_ICON[locKey] || 'Autre';
    html.push(`
      <div class="border border-line rounded-lg p-3 sm:p-4">
        <p class="text-xs font-bold text-slate tracking-widest uppercase mb-2">${locIcon} ${locName}</p>
        <div class="space-y-2">
          ${arr.map(renderSupplyRow).join('')}
        </div>
      </div>
    `);
  }
  body.innerHTML = html.join('');

  // Cablage clic sur boutons.
  body.querySelectorAll('button[data-action]').forEach((btn) => {
    btn.addEventListener('click', () => handleSupplyAction(btn));
  });
}

function renderSupplyRow(r) {
  const when = r.requestedAt ? relativeTime(r.requestedAt) : '';
  const noteHtml = r.note
    ? `<p class="mt-1 text-xs text-slate italic">« ${escapeHtml(r.note)} »</p>`
    : '';
  return `
    <div class="flex items-center justify-between gap-3 flex-wrap py-2">
      <div class="min-w-0 flex-1">
        <p class="text-sm font-semibold text-ink">${escapeHtml(r.articleName)}</p>
        <p class="text-xs text-slate">
          <span class="font-mono">${r.qtyRequested}</span> demandé(s) ·
          stock à ${r.qtyAtRequest}/${r.thresholdAtRequest} ·
          par ${escapeHtml(r.requestedBy)} · ${when}
        </p>
        ${noteHtml}
      </div>
      <div class="flex items-center gap-2 shrink-0">
        <button data-action="reject" data-id="${r.id}"
                class="px-3 py-1.5 text-xs font-semibold rounded-md border border-danger text-danger hover:bg-danger hover:text-white transition">
          Rejeter
        </button>
        <button data-action="approve" data-id="${r.id}"
                class="px-3 py-1.5 text-xs font-semibold rounded-md bg-success text-white hover:opacity-90 transition">
          Approuver
        </button>
      </div>
    </div>
  `;
}

async function handleSupplyAction(btn) {
  const id = parseInt(btn.dataset.id, 10);
  const action = btn.dataset.action;
  if (!id || !action) return;
  const newStatus = action === 'approve' ? 'approved' : 'rejected';
  btn.disabled = true;
  btn.textContent = '...';
  try {
    const { error } = await supa
      .from('supply_requests')
      .update({
        status: newStatus,
        reviewed_by_login: currentUser?.login ?? 'proprietaire',
        reviewed_at: new Date().toISOString(),
      })
      .eq('id', id);
    if (error) throw error;
    // Rafraîchit la liste (la ligne disparaît).
    await refreshSupplyRequests();
  } catch (e) {
    console.error(e);
    alert('Action impossible : ' + (e.message || e));
    btn.disabled = false;
    btn.textContent = action === 'approve' ? 'Approuver' : 'Rejeter';
  }
}

function relativeTime(iso) {
  const d = new Date(iso);
  const diff = Date.now() - d.getTime();
  const min = Math.floor(diff / 60000);
  if (min < 1) return "à l'instant";
  if (min < 60) return `il y a ${min} min`;
  const h = Math.floor(min / 60);
  if (h < 24) return `il y a ${h} h`;
  const days = Math.floor(h / 24);
  return `il y a ${days} j`;
}

function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── Auto-connect si session valide ─────────────────────────────────────
const existing = loadSession();
if (existing) {
  showDashboard(existing.user);
} else {
  showLogin();
}

// ─── PWA + Web Push ────────────────────────────────────────────────────

// Enregistrement du service worker.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register('./service-worker.js')
      .catch((e) => console.warn('SW register failed:', e));
  });
}

// Conversion base64url → Uint8Array (format attendu par PushManager).
function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const raw = atob(base64);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

// État visuel du bouton "activer les alertes".
function setPushBtn(label, disabled = false) {
  const b = document.getElementById('push-btn');
  document.getElementById('push-btn-label').textContent = label;
  if (b) b.disabled = disabled;
}

async function currentPushSubscription() {
  if (!('serviceWorker' in navigator)) return null;
  const reg = await navigator.serviceWorker.ready;
  return await reg.pushManager.getSubscription();
}

async function subscribePush() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
    alert('Ce navigateur ne supporte pas les notifications push.');
    return;
  }
  if (!currentUser) {
    alert('Connecte-toi d\'abord.');
    return;
  }
  const perm = await Notification.requestPermission();
  if (perm !== 'granted') {
    alert('Permission refusée. Tu peux réactiver dans les réglages du navigateur.');
    return;
  }
  const reg = await navigator.serviceWorker.ready;
  const sub = await reg.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(cfg.vapidPublicKey),
  });
  const json = sub.toJSON();
  // Enregistre l'abonnement côté Supabase (table push_subscriptions).
  const { error } = await supa.from('push_subscriptions').upsert(
    {
      endpoint: json.endpoint,
      p256dh: json.keys.p256dh,
      auth: json.keys.auth,
      user_login: currentUser.login,
      user_agent: navigator.userAgent,
      created_at: new Date().toISOString(),
    },
    { onConflict: 'endpoint' },
  );
  if (error) {
    console.error(error);
    alert('Impossible d\'enregistrer l\'abonnement : ' + error.message);
    return;
  }
  setPushBtn('Alertes actives ✓', false);
  // Notification de test locale pour confirmer visuellement.
  new Notification('Skyblue', {
    body: 'Alertes activées sur cet appareil.',
    icon: './icons/icon-192.png',
  });
}

async function unsubscribePush() {
  const sub = await currentPushSubscription();
  if (!sub) return;
  const endpoint = sub.endpoint;
  await sub.unsubscribe();
  await supa.from('push_subscriptions').delete().eq('endpoint', endpoint);
  setPushBtn('Activer les alertes', false);
}

document.getElementById('push-btn').addEventListener('click', async () => {
  const sub = await currentPushSubscription();
  if (sub) {
    if (confirm('Désactiver les alertes stock sur cet appareil ?')) {
      await unsubscribePush();
    }
  } else {
    await subscribePush();
  }
});

// À l'ouverture du dashboard, mets à jour l'étiquette du bouton selon
// l'état actuel de l'abonnement.
(async () => {
  if (!('serviceWorker' in navigator)) return;
  try {
    const sub = await currentPushSubscription();
    if (sub) setPushBtn('Alertes actives ✓');
  } catch (_) {
    /* ignore */
  }
})();
