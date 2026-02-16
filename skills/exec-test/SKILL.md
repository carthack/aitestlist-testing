---
name: exec-test
description: Telecharge une file d'execution approuvee depuis AITestList et execute les tests localement via MCP Playwright dans Claude Code. Skill core du plugin aitestlist-testing.
---

# Execute Tests

Skill core pour executer les tests AI TestList via MCP Playwright.

## Usage

/aitestlist-testing:exec <queue_id>

## Parametres

- queue_id: ID de la file d'execution approuvee (requis)

## Etape 1: Verifications prealables

### Etape 1A: Preflight

Appeler `/aitestlist-testing:preflight` pour obtenir `URL`, `AITESTLIST_TOKEN`, `USER_LANG`.

**IMPORTANT:** Tous les commentaires de resultats et le rapport final doivent etre rediges
dans la langue `USER_LANG`.

### Etape 1B: Verifier MCP Playwright

Verifier que MCP Playwright est disponible en tentant un appel simple.
Si MCP Playwright n'est pas disponible, informer l'utilisateur:
"MCP Playwright n'est pas configure. Ajoutez-le avec: /mcp add playwright"

### Etape 1C: Verifier le mode multi-agent (teams)

Verifier si le mode multi-agent est active dans les settings de Claude Code:

```bash
cat ~/.claude/settings.json 2>/dev/null
```

Chercher si la cle `env` contient `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"`.

**Si active:**
- Informer: "Mode multi-agent (teams) active. Les tests seront executes en parallele."
- Variable interne: `TEAMS_MODE=true`

**Si pas active:**
- Demander a l'utilisateur s'il veut l'activer pour executer en parallele
- Si oui: modifier `~/.claude/settings.json` pour ajouter la cle
- Variable interne: `TEAMS_MODE=true` ou `false`

### Etape 1D: Detecter le mode d'execution

```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "${URL}/api/settings/exec-mode"
```

Variable interne: `EXEC_MODE` = valeur retournee

**Modes et comportement:**

| Mode | Playwright | Comportement |
|---|---|---|
| `batch` | headless | Non-interactif (`claude -p`). Pas de browser visible. |
| `interactive_headless` | headless | Session interactive, terminal visible, pas de browser. |
| `interactive_browser_minimal` | headed, 1280x720 | Fenetre browser visible en taille compacte (defaut). |
| `interactive_browser_fullscreen` | headed, maximize | Fenetre browser maximisee via CDP apres navigation. |

**Pour le mode fullscreen:** Apres la premiere navigation, maximiser la fenetre via CDP:
```javascript
const cdp = await page.context().newCDPSession(page);
const { windowId } = await cdp.send('Browser.getWindowForTarget');
await cdp.send('Browser.setWindowBounds', { windowId, bounds: { windowState: 'maximized' } });
```

## Etape 2: Telecharger la file d'execution approuvee

```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" \
     "${URL}/api/execution-queue/${QUEUE_ID}/download"
```

La reponse contient:
- `project`: info du projet (id, name, path)
- `global_rules`: rules globales du compte
- `project_rules`: rules specifiques au projet
- `tests`: liste des tests avec toutes leurs taches

**Verifications:**
- "Queue is not approved" → informer l'utilisateur
- "Access denied" → verifier les permissions
- `tests` vide → informer l'utilisateur

## Etape 3: Lire les rules et le mode auto-fix

Verifier le flag `auto_fix_enabled` dans la reponse.
Afficher les rules a l'ecran pour que l'agent les connaisse avant d'executer.

**Ces rules sont des directives.** L'agent doit les respecter pendant l'execution.

## Etape 3 - Delegation aux skills specialises

Avant d'executer chaque tache, verifier si elle necessite un skill specialise:

| Condition | Skill a appeler | Action |
|-----------|-----------------|--------|
| Description contient `[PAYMENT_TEST]` | `/aitestlist-testing:exec-payment` | Verifie toggle + execute avec cartes test |
| Description contient `[CREATE_TEST_EMAIL:...]` | `/aitestlist-testing:exec-email` | Cree alias, attend email, extrait liens |
| Tache echoue par restriction plan/role | `/aitestlist-testing:exec-db-elevation` | Eleve permissions BD, re-teste, restaure |

Le skill specialise retourne le resultat (status + comment) que le core utilise pour reporter.

## Etape 4: Executer les tests via MCP Playwright

**Mode teams (TEAMS_MODE=true):** Utiliser le Task tool pour lancer plusieurs agents en parallele.
Chaque agent recoit un sous-ensemble de tests + les rules. Spawner aussi un agent `test-reporter`
pour le reporting live.

**Mode sequentiel (TEAMS_MODE=false):** Executer tous les tests un par un.
Apres chaque tache, appeler `/aitestlist-testing:report-live` pour push le statut.

Pour chaque test:
1. Afficher le nom du test
2. Pour chaque tache du test (ordonnee par position):
   a. Lire le titre et la description de la tache
   b. La description contient: Preconditions, Steps (etapes), Expected (resultat attendu)
   c. Verifier si delegation necessaire (voir tableau etape 3)
   d. Interpreter les etapes et les executer via MCP Playwright
   e. Verifier le resultat attendu
   f. Capturer: passed/failed/error avec message si echec
   g. **Reporter le resultat live** via `/aitestlist-testing:report-live`
   h. **Si auto_fix_enabled ET la tache a echoue:**
      1. Analyser le code source du projet pour trouver la cause
      2. Appliquer le fix dans le code
      3. Re-tester la meme tache
      4. Si passe: mettre a jour le resultat, ajouter "Fixed: [description]"
      5. Si echoue encore: garder echec, ajouter "Fix attempted but failed"
3. Passer au test suivant

### Outils MCP Playwright

| Action | Outil MCP |
|---|---|
| Naviguer | browser_navigate(url) |
| Cliquer | browser_click(ref, element) |
| Remplir un champ | browser_type(ref, text) ou browser_fill_form(fields) |
| Selectionner option | browser_select_option(ref, values) |
| Verifier texte | browser_snapshot() puis chercher le texte |
| Verifier URL | browser_snapshot() et lire l'URL de la page |
| Verifier visible | browser_snapshot() et chercher l'element |
| Screenshot | browser_take_screenshot() |
| Attendre | browser_wait_for(text) ou browser_wait_for(time) |
| Evaluer JS | browser_evaluate(function) |

**IMPORTANT:** Utiliser browser_snapshot() pour obtenir l'etat de la page et les refs des elements.
Les refs changent apres chaque action — toujours reprendre un snapshot avant d'interagir.

## Etape 5: Reporter les resultats a AITestList

En mode sequentiel, les resultats sont deja envoyes live (etape 4g).
En mode teams, l'agent test-reporter s'en charge.

Apres tous les tests, envoyer le batch final pour s'assurer que tout est enregistre:

```bash
curl -s -X POST -H "Authorization: Bearer $AITESTLIST_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "results": [
         {"task_id": 123, "status": "succes", "comment": null},
         {"task_id": 124, "status": "echec", "comment": "Expected error message, got success page"}
       ]
     }' \
     "${URL}/api/execution-queue/${QUEUE_ID}/results"
```

**Statuts valides:**

| Statut | Quand l'utiliser |
|---|---|
| `succes` | La fonctionnalite testee marche comme prevu |
| `succes` + Suggestion | La fonctionnalite marche mais amelioration nice-to-have absente |
| `echec` | La fonctionnalite existe mais ne marche pas correctement |
| `erreur` | Crash, erreur 500, exception Playwright, page inaccessible |

**Regle "Suggestion":** Si une tache decrit une fonctionnalite "nice-to-have"
qui n'existe pas encore, marquer comme `succes` avec commentaire "Suggestion : ...".
Reserver `echec` aux fonctionnalites qui EXISTENT mais sont CASSEES.

## Etape 6: Rapport final (dans USER_LANG)

En mode sequentiel: afficher le resume.
En mode teams: l'agent test-reporter genere le resume + appelle `/aitestlist-testing:error-report`
si il y a des echecs.

```
=== RESUME ===
Tests: 5
Taches: 45 total, 40 succes, 3 echecs, 1 erreur, 1 suggestion
Taux de reussite: 89%
Resultats envoyes a AITestList.
```

## Gestion d'erreurs

- MCP Playwright pas configure → informer + commande d'installation
- Token invalide → "Generez-en un dans Settings > Integration."
- File pas trouvee → "File #ID non trouvee."
- File pas approuvee → "Approuvez-la dans AITestList."
- Erreur Playwright → marquer la tache comme "erreur", continuer a la suivante
- API AITestList down → informer l'utilisateur, arreter l'execution

## Regle auto-fix

- Ne JAMAIS modifier le code source sauf si `auto_fix_enabled` est `true`
- Toujours reporter le probleme AVANT de tenter un fix
- Toujours re-tester apres un fix
- Documenter le fix dans le commentaire de la tache
