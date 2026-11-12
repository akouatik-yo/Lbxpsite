# Changements de la zone DNS de legeekdesbois.fr

Chaque modification est un fichier JSON de `dns/changements/`, relu, puis appliqué par le workflow « DNS (approbation de Yoann) ». Yoann approuve chaque passage, depuis l'application GitHub.

Format (corps de l'API EX2, sans le `serial`, que le workflow ajoute) :

```json
{
  "commentaire": "Pourquoi ce changement",
  "add": [{ "name": "sous-domaine", "type": "TXT", "ttl": 3600, "data": ["valeur"] }]
}
```

Clés permises : `add`, `delete`, `replace`, `commentaire`. Seul `add` a déjà été éprouvé sur l'API EX2 (le 09/11) ; `delete` et `replace` sont à vérifier dans la documentation d'EX2 avant leur premier usage.
Un même fichier, réappliqué, garde la même clé d'idempotence : EX2 ne l'applique pas deux fois.
