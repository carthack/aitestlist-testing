---
name: report-live
description: Pousse les resultats de test a AITestList en temps reel, tache par tache. Le client voit les statuts se mettre a jour en direct. Appele par exec-test apres chaque tache ou par l'agent test-reporter en mode teams.
---

# Report Live

Skill pour le push en temps reel des resultats de test a AITestList.
Chaque resultat est envoye immediatement apres l'execution d'une tache,
permettant au client de voir son dashboard se mettre a jour en direct.

## API - Push un resultat unitaire

```bash
curl -s -X POST -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "task_id": 123,
    "status": "succes",
    "comment": null,
    "duration_ms": 342
  }' \
  "${URL}/api/execution-queue/${QUEUE_ID}/result"
```

**Note:** Endpoint singulier `/result` (une tache) vs `/results` (batch final).

## Statuts valides

| Statut | Usage |
|--------|-------|
| `succes` | La tache a passe |
| `echec` | La fonctionnalite existe mais ne marche pas |
| `erreur` | Crash, 500, exception Playwright |

## Commentaires (dans USER_LANG)

- `succes` sans remarque: `null`
- `succes` avec suggestion: `"Suggestion : [description]"` (FR) ou `"Suggestion: [description]"` (EN)
- `echec`: description de ce qui n'a pas fonctionne
- `erreur`: message d'erreur technique

## Workflow

1. Recevoir: task_id, status, comment, duration_ms, queue_id
2. Valider le status (succes/echec/erreur)
3. POST immediat a `/api/execution-queue/{queue_id}/result`
4. Si erreur API (timeout, 500): retry 1x apres 2 secondes
5. Si retry echoue: stocker le resultat localement, continuer
6. Retourner confirmation au caller

## Utilisation

**En mode sequentiel:** Le skill `exec-test` appelle `report-live` directement
apres chaque tache executee.

**En mode teams:** L'agent `test-reporter` recoit les resultats des exec agents
via SendMessage et appelle `report-live` pour chacun.

## Effet cote client

Quand le serveur recoit le POST:
1. Met a jour le statut de la tache en BD
2. Le frontend de la page execution-detail poll regulierement
3. La ligne de la tache passe de gris → vert (succes) / rouge (echec) / orange (erreur)
4. Le compteur de progression se met a jour
