---
name: error-report
description: Analyse les taches echouees d'un projet AI TestList avec l'IA et genere un rapport d'erreurs detaille. Le rapport PDF est envoye automatiquement au serveur et devient disponible pour telechargement. Appele par test-reporter apres execution ou manuellement.
user-invocable: false
---

# Error Analysis Report

Skill pour analyser les taches echouees et generer un rapport d'erreurs PDF.
Prechage dans l'agent `test-reporter` via le champ `skills:`.
Utilise apres une execution ou invoque directement via `@test-reporter`.

## Variables disponibles

Ce skill est prechage dans l'agent test-reporter via le champ `skills:`.
Les variables suivantes sont disponibles via preflight (egalement prechage):
- `URL` — URL du serveur AITestList
- `AITESTLIST_TOKEN` — Token API valide
- `USER_LANG` — Langue de l'utilisateur (fr/en)

## API REST

### Obtenir les projets
```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  "${URL}/api/projects"
```

### Obtenir les taches echouees
```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  "${URL}/api/projects/{project_id}/failed-tasks"
```

### Envoyer les diagnostics
```bash
curl -s -X POST "${URL}/api/reports/error-analysis" \
  -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": 9,
    "task_index": {
      "123": "Page d accueil du portail affilies",
      "456": "Validation formulaire inscription"
    },
    "diagnoses": {
      "123": {
        "error": "Description courte de l erreur probable",
        "cause": "Explication de la cause racine",
        "solutions": ["Solution 1", "Solution 2", "Solution 3"]
      }
    }
  }'
```

**IMPORTANT**: `task_index` est un dictionnaire `{task_id: task_title}` pour toutes les taches
echouees. Il est utilise pour generer un lexique dans le rapport PDF.
Construire le task_index a partir des champs `task_id` et `title` retournes par `GET /failed-tasks`.

## Workflow

1. **Lister les projets** - `GET ${URL}/api/projects` et laisser l'utilisateur choisir (ou recevoir le project_id du caller)
2. **Recuperer les taches echouees** - `GET ${URL}/api/projects/{id}/failed-tasks`
3. **Analyser TOUTES les taches en un seul bloc** - Voir section "Analyse batch" ci-dessous
4. **Envoyer les diagnostics** - `POST ${URL}/api/reports/error-analysis`
5. **Confirmer** - Informer l'utilisateur que le rapport est disponible

## IMPORTANT: Analyse batch (pas une par une!)

**PERFORMANCE CRITIQUE** — Analyser toutes les taches echouees en UN SEUL passage.

**NE PAS FAIRE:** Boucler sur chaque tache individuellement avec un prompt par tache.
Cela genere N appels API et prend 30+ minutes pour 30 taches.

**FAIRE:** Lire toutes les taches echouees retournees par l'API, puis produire
tous les diagnostics dans une seule reponse. Le JSON de diagnostics complet
doit etre construit en un seul bloc puis envoye avec un seul POST.

### Etapes concretes:

1. `GET /api/projects/{id}/failed-tasks` → recevoir la liste complete
2. Lire TOUTES les taches d'un coup (elles sont dans la reponse JSON)
3. Produire le JSON `diagnoses` complet avec tous les task_id en UNE SEULE reponse
4. `POST /api/reports/error-analysis` avec le JSON complet → UN SEUL appel

Total: 2 appels API (1 GET + 1 POST). Pas de boucle.

## Champs du diagnostic (par tache)

- **error**: Description concise de l'erreur probable (1-2 phrases)
- **cause**: Explication de la cause racine (2-3 phrases)
- **solutions**: Liste de solutions ordonnees par priorite (1 a 5 selon la complexite du probleme — pas toujours 3)

## Methodologie d'analyse

Pour chaque tache dans le batch:
1. **Lire la description** - Comprendre les preconditions, les etapes et le resultat attendu
2. **Analyser le commentaire** - Le testeur a souvent laisse des indices
3. **Considerer la categorie** - Un echec en securite n'a pas les memes causes qu'en UI
4. **Etre specifique** - Eviter les diagnostics generiques comme "verifier le code"
5. **Proposer des solutions actionnables** - Chaque solution doit etre assez precise pour etre implementee
6. **Regrouper les erreurs similaires** - Si plusieurs taches echouent pour la meme raison, le mentionner
7. **Utiliser les IDs numeriques** - Dans les textes de diagnostic, referencer les taches par leur ID (ex: "resout taches 1973, 1989") plutot que par leur titre complet. Le lexique task_index en fin de rapport fournit la correspondance ID → titre

### Exemple de bon diagnostic

```json
{
  "error": "Le formulaire de login accepte des identifiants vides - la validation cote client est contournee quand JavaScript est desactive",
  "cause": "La validation est uniquement cote client (JavaScript). Il n'y a pas de validation cote serveur dans le controleur /auth/login.",
  "solutions": [
    "Ajouter une validation required sur les champs email et password dans le formulaire WTForms",
    "Ajouter une verification explicite dans la route /auth/login",
    "Implementer un middleware de validation globale"
  ]
}
```

### Exemple de MAUVAIS diagnostic (a eviter)

```json
{
  "error": "Le test a echoue",
  "cause": "Il y a un bug dans le code",
  "solutions": ["Corriger le bug", "Ajouter des tests", "Verifier le code"]
}
```

## Langue du rapport

Les diagnostics doivent etre rediges dans la langue de l'utilisateur (`USER_LANG` du preflight):
- Si `USER_LANG` = `fr` → diagnostics en francais
- Si `USER_LANG` = `en` → diagnostics en anglais

## Appel automatique par test-reporter

Quand appele par l'agent `test-reporter` apres une execution:
- Le project_id est fourni automatiquement
- Pas besoin de demander a l'utilisateur de choisir
- Le rapport est genere et envoye sans interaction
- En mode teams, le reporter a deja les taches echouees en memoire — utiliser
  `GET /failed-tasks` pour avoir le format complet si necessaire

## Apres envoi

Informer l'utilisateur:
1. Nombre de taches analysees
2. Le rapport PDF a ete genere et stocke sur AI TestList
3. Pour le telecharger: **${URL}/reports** → selectionner le projet → section "Rapports disponibles"
