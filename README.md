# legeekdesbois.fr

Le site de Yoann, hébergé chez EX2 (mutualisé vert Ultra).

- `public/` : ce qui est en ligne. Tout push sur `main` qui touche `public/` le déploie automatiquement vers `public_html` (workflow `.github/workflows/deploy.yml`).
- Le dépôt est public : **aucun secret** n'y entre. Les accès SSH sont dans les secrets du dépôt (`EX2_HOST`, `EX2_USER`, `EX2_PORT`, `EX2_SSH_KEY`, `EX2_SSH_PASSPHRASE`).
- Tenu par le CTO de Yoann Corp ; l'apparence vient de la session Design du site.

## Licences

- La page d'attente (`public/index.html`) dérive du moteur « Le Mycélium » de Fascinations (`akouatik-yo/Fascination`), de Yoann, sous **GNU GPL v3** : elle est publiée sous la même licence (en-tête du fichier).
- Police du masque des lettres : Archivo ExtraBold, sous-ensemble embarqué, **SIL OFL 1.1** (`public/polices/Archivo-OFL.txt`).
