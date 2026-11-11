#!/usr/bin/env node
/* Outil de capture commun (P-E13, audit n° 1) — CTO, 11/11/2026. Proposé avec Fausta (Design).
   Donne les vues tablette et téléphone d'une page (adresse web ou fichier local), à des instants choisis,
   avec des aperçus légers et des extraits pour une revue « par morceaux » sans relire l'image entière.
   Usage :
     node outils/capture.js <adresse ou fichier> <dossier de sortie> [--vues tablette,telephone,pc]
                           [--temps 2,8] [--extrait x,y,l,h[;x,y,l,h…]]
   Sorties dans <dossier> :
     <vue>-<t>s.png          pleine définition (densité réelle de l'appareil)
     <vue>-<t>s-apercu.png   en pixels CSS (léger, pour une relecture par un modèle)
     <vue>-<t>s-extrait<i>.png  morceaux demandés, en pleine définition
     rapport.json            appareil, taille, densité, code HTTP, titre, erreurs de la console
   Garde-fous : aucune authentification (on ne capture jamais derrière un code, règle de Maud) ;
   GET seulement ; WebGL rendu par le processeur (SwiftShader) : la fluidité n'est PAS mesurable ici. */
const { chromium, devices } = require('playwright');
const path = require('path'), fs = require('fs');
const VUES = {
  tablette: { ...devices['Galaxy Tab S9 landscape'], nom: 'tablette Android, paysage' },
  telephone: { ...devices['Pixel 7'], nom: 'téléphone Android, portrait' },
  pc: { viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, nom: 'ordinateur 1440×900' },
};
const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf('--' + n); return i >= 0 ? args[i + 1] : d; };
const [cible, sortie] = args.filter((a, i) => !a.startsWith('--') && !(i > 0 && args[i - 1].startsWith('--')));
if (!cible || !sortie) { console.error('usage : node outils/capture.js <adresse ou fichier> <dossier> [--vues …] [--temps …] [--extrait …]'); process.exit(2); }
const url = /^https?:\/\//.test(cible) ? cible : 'file://' + path.resolve(cible);
const vues = opt('vues', 'tablette,telephone').split(',');
const temps = opt('temps', '3').split(',').map(Number);
const extraits = (opt('extrait', '') || '').split(';').filter(Boolean).map(s => s.split(',').map(Number));
fs.mkdirSync(sortie, { recursive: true });
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const rapport = { adresse: url, date: new Date().toISOString(), avertissement: 'WebGL rendu par le processeur : images fidèles, fluidité non mesurée', vues: [] };
  for (const v of vues) {
    const d = VUES[v]; if (!d) { console.error('vue inconnue : ' + v); continue; }
    const { nom, ...ctxOpts } = d;
    const ctx = await b.newContext(ctxOpts); const p = await ctx.newPage();
    const erreurs = [];
    p.on('console', m => { if (['error', 'warning'].includes(m.type())) erreurs.push(m.type() + ' : ' + m.text().slice(0, 300)); });
    p.on('pageerror', e => erreurs.push('exception : ' + e.message.slice(0, 300)));
    const rep = await p.goto(url, { waitUntil: 'load', timeout: 30000 }).catch(e => (erreurs.push('chargement : ' + e.message), null));
    const t0 = Date.now(); const images = [];
    for (const s of temps) {
      const reste = s * 1000 - (Date.now() - t0); if (reste > 0) await p.waitForTimeout(reste);
      const base = path.join(sortie, `${v}-${s}s`);
      await p.screenshot({ path: base + '.png' });
      await p.screenshot({ path: base + '-apercu.png', scale: 'css' });
      images.push(base + '.png', base + '-apercu.png');
      for (const [i, [x, y, l, h]] of extraits.entries()) {
        await p.screenshot({ path: `${base}-extrait${i + 1}.png`, clip: { x, y, width: l, height: h } });
        images.push(`${base}-extrait${i + 1}.png`);
      }
    }
    rapport.vues.push({ vue: v, appareil: nom, taille_css: ctxOpts.viewport, densite: ctxOpts.deviceScaleFactor, http: rep ? rep.status() : null, titre: await p.title().catch(() => ''), erreurs, images: images.map(f => path.basename(f)) });
    console.log(`${v} (${nom}, ${ctxOpts.viewport.width}×${ctxOpts.viewport.height} css, densité ${ctxOpts.deviceScaleFactor}) : HTTP ${rep ? rep.status() : '—'}, ${erreurs.length} erreur(s) de console, ${images.length} image(s)`);
    await ctx.close();
  }
  fs.writeFileSync(path.join(sortie, 'rapport.json'), JSON.stringify(rapport, null, 2));
  await b.close();
})();
