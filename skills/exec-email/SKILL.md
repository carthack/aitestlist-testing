---
name: exec-email
description: Gere les aliases email temporaires pour les tests (creation, attente, lecture, nettoyage). Utilise l'API AITestList comme proxy vers Zoho. Appele par exec-test quand une tache contient [CREATE_TEST_EMAIL].
---

# Execute Email Testing

Skill specialise pour la gestion des emails de test via l'API AITestList.
Appele par le skill core `exec-test` quand une tache contient `[CREATE_TEST_EMAIL:...]`.

**Ne jamais acceder a Zoho directement.** Toujours passer par l'API AITestList.

## Convention de nommage des aliases

`claude.{role}_queue{id}@aitestlist.com`

Exemples:
- `claude.user1_queue4@aitestlist.com`
- `claude.billing_queue12@aitestlist.com`

## 1. Creer un alias email

```bash
curl -s -X POST -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prefix": "user1_queue4"}' \
  "${URL}/api/email-testing/aliases"
```
Reponse: `{"success": true, "alias": "claude.user1_queue4@aitestlist.com"}`

Utiliser l'adresse retournee dans les formulaires d'inscription/invitation.

## 2. Attendre la reception d'un courriel

```bash
curl -s -X POST -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"subject_contains": "Verify", "timeout": 30}' \
  "${URL}/api/email-testing/aliases/claude.user1_queue4@aitestlist.com/wait"
```
Reponse: `{"found": true, "email": {"id": "...", "subject": "...", "from": "...", "date": "..."}}`

Si `found: false`, le courriel n'est pas arrive dans le delai. Reporter comme echec.

## 3. Lire le contenu et extraire les liens

```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  "${URL}/api/email-testing/emails/{message_id}"
```
Reponse: `{"subject": "...", "html": "...", "text": "...", "links": ["https://..."]}`

Les liens sont extraits automatiquement du body HTML.
Utiliser Playwright pour naviguer vers le lien de validation/reset.

## 4. Nettoyer les aliases (OBLIGATOIRE)

```bash
curl -s -X DELETE -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  "${URL}/api/email-testing/aliases/claude.user1_queue4@aitestlist.com"
```

**IMPORTANT:** Toujours nettoyer les aliases apres les tests, meme en cas d'echec.
Le nettoyage doit etre fait dans le [TEARDOWN] ou a la fin de l'execution.

## Mapping [CREATE_TEST_EMAIL:context] → alias

Quand le skill recoit un contexte (ex: `login_test`), il:
1. Cree l'alias avec prefix = `{context}_queue{queue_id}`
2. Stocke le mapping `context → alias` pour reutilisation
3. Les taches suivantes qui referent au meme contexte reutilisent le meme alias

## Retour au skill exec-test

Apres chaque operation, retourner:
- L'adresse email creee (pour la tache SETUP)
- Le contenu de l'email recu (pour les taches de verification)
- Les liens extraits (pour la navigation Playwright)
