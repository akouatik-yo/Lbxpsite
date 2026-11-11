#!/usr/bin/env bash
# Recette du site après déploiement (P-Q10, audit n° 1), dérivée du script de Constance (revue/audit-1/recette-site.sh).
# GET et HEAD ordinaires uniquement, sur nos seuls domaines. Usage : outils/recette.sh <racine du dépôt lbxpsite>
# Sortie : une ligne OK ou ÉCART par contrôle ; code 1 s'il y a au moins un écart.
set -u; D="${1:?racine du dépôt}"; H=https://legeekdesbois.fr; ok=0; ko=0
chk(){ if eval "$2"; then echo "OK    $1"; ok=$((ok+1)); else echo "ÉCART $1"; echo "::warning::Recette : $1"; ko=$((ko+1)); fi; }
# 1. Chaque fichier publié (hors .htaccess, illisible de l'extérieur) est identique en ligne et dans le dépôt.
while IFS= read -r f; do
  u="$H/$f"; [ "$f" = index.html ] && u="$H/"
  chk "$f en ligne = dépôt" "[ \"\$(curl --retry 2 -fsS '$u' | sha256sum | cut -c1-64)\" = \"\$(sha256sum '$D/public/$f' | cut -c1-64)\" ]"
done < <(cd "$D/public" && find . -type f ! -name .htaccess | sed 's|^\./||' | LC_ALL=C sort)
# 2. En-têtes et redirections.
hdr=$(curl --retry 2 -fsSI "$H/")
chk "HSTS"                   "grep -qi '^strict-transport-security' <<<\"\$hdr\""
chk "X-Content-Type-Options" "grep -qi '^x-content-type-options' <<<\"\$hdr\""
chk "http → https (301)"     "[ \"\$(curl --retry 2 -s -o /dev/null -w '%{http_code}' http://legeekdesbois.fr/)\" = 301 ]"
chk "www → apex"             "curl --retry 2 -s -o /dev/null -w '%{redirect_url}' https://www.legeekdesbois.fr/ | grep -q '^https://legeekdesbois.fr/'"
# 3. Page absente : vrai 404 (pas de 200 trompeur).
chk "page absente → 404"     "[ \"\$(curl --retry 2 -s -o /dev/null -w '%{http_code}' $H/absente-$RANDOM$RANDOM)\" = 404 ]"
# 4. Zones voisines toujours fermées.
chk "Univers protégé (401)"  "[ \"\$(curl --retry 2 -s -o /dev/null -w '%{http_code}' https://univers.legeekdesbois.fr/)\" = 401 ]"
chk "Matomo muré (403)"      "[ \"\$(curl --retry 2 -s -o /dev/null -w '%{http_code}' https://stats.legeekdesbois.fr/)\" = 403 ]"
# 5. Aucun traceur non annoncé : la balise mesure-audience de la page de confidentialité dit la vérité.
trac=$(cat "$D"/public/*.html | grep -ciE 'matomo\.js|_paq|googletagmanager|google-analytics|plausible|gtag\(')
annonce=$(grep -oE 'name="mesure-audience" content="[a-z]+"' "$D/public/confidentialite.html" | grep -oE '(in)?active"' | tr -d '"')
chk "traceurs ($trac) cohérents avec la confidentialité ($annonce)" "{ [ $trac -eq 0 ] && [ '$annonce' = inactive ]; } || { [ $trac -gt 0 ] && [ '$annonce' = active ]; }"
echo "--- $ok conformes, $ko écarts ($(TZ=Europe/Paris date '+%d/%m/%Y %H:%M %Z'))"
[ "$ko" -eq 0 ]
