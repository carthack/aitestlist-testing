---
name: error-report
description: Analyse les taches echouees d'un projet AI TestList avec l'IA et genere un rapport d'erreurs detaille. Le rapport PDF est envoye automatiquement au serveur et devient disponible pour telechargement. Appele par test-reporter apres execution ou manuellement.
---

# Error Analysis Report

Skill pour analyser les taches echouees et generer un rapport d'erreurs PDF.
Peut etre appele automatiquement par l'agent `test-reporter` apres une execution,
ou manuellement via `/aitestlist-testing:report`.

## Prerequis

Appeler `/aitestlist-testing:preflight` en premiere etape.
Ce skill fournit: `URL` (serveur), `AITESTLIST_TOKEN` (valide), `USER_LANG` (langue).

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
    "diagnoses": {
      "123": {
        "error": "Description courte de l erreur probable",
        "cause": "Explication de la cause racine",
        "solutions": ["Solution 1", "Solution 2", "Solution 3"]
      }
    }
  }'
```

## Workflow

1. **Preflight** - Appeler `/aitestlist-testing:preflight` (token, langue, URL)
2. **Lister les projets** - Appeler `/api/projects` et laisser l'utilisateur choisir (ou recevoir le project_id du caller)
3. **Recuperer les taches echouees** - Appeler `/api/projects/{id}/failed-tasks`
4. **Analyser chaque tache** - Pour chaque tache echouee, analyser en profondeur
5. **Envoyer les diagnostics** - Appeler `/api/reports/error-analysis`
6. **Confirmer** - Informer l'utilisateur que le rapport est disponible

## Analyse des taches echouees

Pour chaque tache echouee, produire un diagnostic structure:

### Champs du diagnostic

- **error**: Description concise de l'erreur probable (1-2 phrases)
- **cause**: Explication de la cause racine (2-3 phrases)
- **solutions**: Liste de 3 solutions ordonnees par priorite

### Methodologie d'analyse

1. **Lire la description** - Comprendre les preconditions, les etapes et le resultat attendu
2. **Analyser le commentaire** - Le testeur a souvent laisse des indices
3. **Considerer la categorie** - Un echec en securite n'a pas les memes causes qu'en UI
4. **Etre specifique** - Eviter les diagnostics generiques comme "verifier le code"
5. **Proposer des solutions actionnables** - Chaque solution doit etre assez precise pour etre implementee

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

## Apres envoi

Informer l'utilisateur:
1. Nombre de taches analysees
2. Le rapport PDF a ete genere et stocke sur AI TestList
3. Pour le telecharger: **${URL}/reports** → selectionner le projet → section "Rapports disponibles"
