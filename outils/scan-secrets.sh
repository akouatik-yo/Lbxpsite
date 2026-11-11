#!/usr/bin/env bash
# Scan de secrets avant tout push vers un dépôt public (P-S11, audit n° 1 ; leçon de S-20 : la clé Android
# publiée avec son mot de passe). Deux familles : des MOTIFS dans le contenu, des NOMS et extensions de fichiers.
# Usage : outils/scan-secrets.sh [plage git, ex. origin/main..HEAD]   (sans plage : tout l'arbre de HEAD)
# Crochet : ln -s ../../outils/scan-secrets.sh .git/hooks/pre-push   (le crochet lit stdin et scanne ce qui part)
# Faux positif assumé : ajouter « scan-secrets: ignorer » sur la ligne concernée.
set -u
noms='\.(p12|pfx|jks|keystore|pem|key|ppk|kdbx|sqlite3?|db|sql|env|b64)$|(^|/)(id_(rsa|ed25519|ecdsa)[^/]*|\.htpasswd|\.env\..*|credentials[^/]*|secrets?\.[a-z]+)$' # scan-secrets: ignorer
motifs='-----BEGIN [A-Z ]*PRIVATE KEY-----|PuTTY-User-Key-File-[0-9]+: |gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|sk-(ant-|proj-)[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.' # scan-secrets: ignorer
# Mots-clés suivis d'une valeur littérale (insensible à la casse) : pass: 'x', storepass="x", token = 'x'…
motscles='(pass(word|wd|phrase)?|storepass|keypass|secret|token|api[_-]?key)["'"'"' ]*[:=] *["'"'"'][^"'"'"' ]{4,}' # scan-secrets: ignorer
plages=()
if [ $# -eq 1 ]; then plages=("$1")
elif [ $# -eq 2 ]; then  # appelé en crochet pre-push (arguments : dépôt distant, adresse) : « <réf locale> <sha local> <réf distante> <sha distant> » par ligne
  while read -r _ loc _ dist; do
    case "$loc" in 0000000000000000000000000000000000000000) continue;; esac
    case "$dist" in 0000000000000000000000000000000000000000) plages+=("$loc");; *) plages+=("$dist..$loc");; esac
  done
fi
trouve=0
signale(){ echo "SECRET POSSIBLE : $1"; trouve=1; }
if [ ${#plages[@]} -eq 0 ]; then
  while IFS= read -r f; do signale "nom de fichier $f"; done < <(git ls-files | grep -iE "$noms")
  sortie=$(git grep -nIE -e "$motifs" HEAD -- .); rc=$?
  [ $rc -le 1 ] || { echo "scan-secrets : ERREUR de git grep (code $rc), push refusé par prudence"; exit 2; }
  sortie2=$(git grep -nIiE -e "$motscles" HEAD -- .); rc=$?
  [ $rc -le 1 ] || { echo "scan-secrets : ERREUR de git grep (code $rc), push refusé par prudence"; exit 2; }
  sortie=$(printf '%s\n%s' "$sortie" "$sortie2")
  while IFS= read -r l; do [ -n "$l" ] && signale "$l"; done < <(printf '%s\n' "$sortie" | grep -v 'scan-secrets: ignorer' | cut -c1-160)
else
  for p in "${plages[@]}"; do
    while IFS= read -r f; do signale "nom de fichier $f (dans $p)"; done < <(git log --format= --name-only --diff-filter=AM "$p" | sort -u | grep -iE "$noms")
    journal=$(git log -p --format= "$p") || { echo "scan-secrets : ERREUR de git log sur $p, push refusé par prudence"; exit 2; }
    while IFS= read -r l; do [ -n "$l" ] && signale "$l (dans $p)"; done < <(printf '%s\n' "$journal" | grep -E '^\+' | { grep -E -e "$motifs"; printf '%s\n' "$journal" | grep -E '^\+' | grep -iE -e "$motscles"; } | grep -v 'scan-secrets: ignorer' | cut -c1-160)
  done
fi
[ $trouve -eq 0 ] && echo "scan-secrets : rien trouvé" || { echo "scan-secrets : push refusé. Retirer le secret, ou marquer un faux positif."; exit 1; }
