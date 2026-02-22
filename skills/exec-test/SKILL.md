---
name: exec-test
description: Telecharge une file d'execution approuvee depuis AITestList et execute les tests localement via MCP Playwright dans Claude Code. Skill core du plugin aitestlist-testing.
user-invocable: false
---

# Execute Tests

Skill core pour executer les tests AI TestList via MCP Playwright.

## IMPORTANT: Status Output (Live Progress)

**Tu DOIS afficher des messages de status a chaque etape.**
Ces messages sont visibles en temps reel dans le terminal Claude Code.
Ils donnent un effet professionnel et montrent la progression au client.

**Format obligatoire — afficher en texte brut (PAS dans un bloc de code).**

**Verification MCP Playwright:**
```
🎭 Checking MCP Playwright...
✅ Playwright ready
```

**Mode d'execution:**
```
👤 Execution mode: interactive_browser_minimal (1280x720)
```

**Download queue:**
```
📥 Downloading execution queue #42...
✅ Queue #42 loaded
   → Project: "Mon Application" (id: 5)
   → Tests: 3 tests, 24 tasks total
   → Auto-fix: OFF
```

**Rules:**
```
📜 Loading execution rules...
   ┌─────────────────────────────────────────────────┐
   │  GLOBAL RULES                                   │
   │  [security] Always check CSRF tokens on forms   │
   │  [general] Test in both FR and EN               │
   │                                                 │
   │  PROJECT RULES                                  │
   │  [general] Login page is at /login              │
   │  [a11y] All forms must be keyboard navigable    │
   └─────────────────────────────────────────────────┘
```

**Avant chaque test:**
```
═══════════════════════════════════════════════════
  📋 Test 1/3: Authentication - Login Page
  Tasks: 8
═══════════════════════════════════════════════════
```

**Pour chaque tache — afficher les actions Playwright en temps reel:**
```
  🔄 [1/8] Login with valid credentials...
     → Creating test email: POST /api/email-testing/aliases
     → Got: test_login_042@testmail.aitestlist.com
     → Navigate to /login
     → Snapshot: found email field, password field, Login button
     → Fill email: test_login_042@testmail.aitestlist.com
     → Fill password: ********
     → Click "Login" button
     → Snapshot: URL=/dashboard, "Welcome" text found
     → ✅ PASSED
     → 📤 Result pushed live
```

En cas d'echec:
```
  🔄 [3/8] Login with empty fields...
     → Navigate to /login
     → Snapshot: found form fields
     → Leave fields empty
     → Click "Login" button
     → Expected: "Required field" message
     → Got: Form submitted without validation
     → ❌ FAILED — No client-side validation
     → 📤 Result pushed live
```

En cas d'erreur:
```
  🔄 [5/8] Login with expired session...
     → Navigate to /dashboard
     → ⚠️ ERROR — Timeout after 10s
     → 📤 Result pushed live
```

Auto-fix:
```
  🔧 Auto-fix triggered for task [N]...
     → Analyzing: website/templates/auth/login.html
     → Found: missing 'required' on email input (line 23)
     → Applying fix...
     → Re-testing...
     → ✅ FIXED — Validation now works
```

**Apres chaque test:**
```
  ── Test complete: 7/8 passed, 1 failed ──
```

**Finalize:**
```
📤 Finalizing execution queue #42...
✅ Queue finalized
```

**Rapport final:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📊 EXECUTION REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Tests:    3
  Tasks:    24 total
  ✅ Passed: 20
  ❌ Failed: 3
  ⚠️  Errors: 1

  Success rate: 83%

  ❌ Failed tasks:
     → [Login] Login with empty fields — Missing validation
     → [Login] SQL injection — Server returned 500
     → [Register] Duplicate email — No error message

  ⚠️  Errors:
     → [Profile] Update avatar — Timeout after 10s

  📤 Results sent to AITestList
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Variables disponibles

Ce skill est prechage dans l'agent test-executor via le champ `skills:`.
Les variables suivantes sont disponibles via preflight (egalement prechage):
- `URL` — URL du serveur AITestList
- `AITESTLIST_TOKEN` — Token API valide
- `USER_LANG` — Langue de l'utilisateur (fr/en)

**IMPORTANT:** Tous les commentaires de resultats et le rapport final doivent etre rediges
dans la langue `USER_LANG`.

## Etape 1: Verifications prealables

### Etape 1A: Verifier MCP Playwright

Verifier que MCP Playwright est disponible en tentant un appel simple.
Si MCP Playwright n'est pas disponible, informer l'utilisateur:
"MCP Playwright n'est pas configure. Ajoutez-le avec: /mcp add playwright"

### Etape 1B: Detecter le mode d'execution

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

## Etape 3b - Delegation aux instructions specialisees

Avant d'executer chaque tache, verifier si elle necessite des instructions specialisees
(prechargees dans l'agent via `skills:`):

| Condition | Instructions | Action |
|-----------|-------------|--------|
| Description contient `[PAYMENT_TEST]` | exec-payment | Verifie toggle + execute avec cartes test |
| Description contient `[CREATE_TEST_EMAIL:...]` | exec-email | Cree alias, attend email, extrait liens |
| Tache echoue par restriction plan/role | exec-db-elevation | Eleve permissions BD, re-teste, restaure |

## Etape 3c: Verifier la connectivite du serveur cible

Avant d'executer les tests, verifier que le serveur cible (`target_url` du projet) est accessible.

1. Naviguer vers `target_url` avec Playwright
2. **Si la page repond** (meme avec une erreur HTTP comme 404):
```
🌐 Checking target server: http://localhost:8005
✅ Target server reachable
```
3. **Si `ERR_CONNECTION_REFUSED` ou timeout:**
```
🌐 Checking target server: http://localhost:8005
❌ Target server unreachable: http://localhost:8005
   All tasks will be marked as error.
```
→ Marquer toutes les taches en `erreur`, envoyer les resultats, afficher le rapport, **STOP**.

## Etape 4: Executer les tests via MCP Playwright

Pour chaque test:
1. Afficher le nom du test
2. Pour chaque tache du test (ordonnee par position):
   a. Lire le titre et la description de la tache
   b. La description contient: Preconditions, Steps (etapes), Expected (resultat attendu)
   c. Verifier si delegation necessaire (voir tableau etape 3)
   d. Interpreter les etapes et les executer via MCP Playwright
   e. Verifier le resultat attendu
   f. Capturer: passed/failed/error avec message si echec
   g. **Reporter le resultat live** (instructions report-live dans le contexte de l'agent)
   h. **Si auto_fix_enabled ET la tache a echoue:**
      1. Analyser le code source du projet pour trouver la cause
      2. Appliquer le fix dans le code
      3. Re-tester la meme tache
      4. Si passe: mettre a jour le resultat, ajouter "Fixed: [description]"
      5. Si echoue encore: garder echec, ajouter "Fix attempted but failed"
   i. **Verification post-action (si auto_fix_enabled):**
      Apres toute tache qui modifie l'etat du systeme (INSERT BD, creation de compte,
      modification de code, auto-fix), verifier que les pages affectees ne crashent pas.
      Voir section "Verification post-action" ci-dessous.
3. Passer au test suivant

### Verification post-action (max 3 tentatives)

**Quand:** Apres toute tache qui modifie l'etat du systeme, SI `auto_fix_enabled` est `true`.

**Taches concernees:**
- Taches `[SETUP]` (creation de comptes, projets, donnees de test via BD)
- Taches ou un auto-fix a ete applique (modification de code ou de BD)
- Taches qui inserent/modifient des donnees directement en BD

**Procedure:**
1. Identifier les pages affectees par l'action (ex: si INSERT dans `projects` → `/projects`)
2. Naviguer vers chaque page affectee avec Playwright
3. Prendre un snapshot et verifier qu'il n'y a pas d'erreur (500, UndefinedError, crash)
4. **Si la page crashe:**
   - Analyser l'erreur (ex: champ NULL, attribut manquant)
   - Corriger la donnee ou le code source
   - Re-verifier la page
   - **Maximum 3 tentatives** par page. Apres 3 echecs, logger un warning et continuer.

**Affichage:**
```
  🔍 Post-action check: /projects
     → Snapshot: page OK
```

En cas de correction:
```
  🔍 Post-action check: /projects
     → ❌ Page error: UndefinedError 'None' has no attribute 'strftime'
     → Fix attempt 1/3: UPDATE projects SET date_creation=CURDATE() WHERE id=15
     → Re-check: /projects
     → ✅ Page OK after fix
```

En cas d'echec apres 3 tentatives:
```
  🔍 Post-action check: /projects
     → ❌ Page error after 3 attempts — continuing execution
```

**IMPORTANT:** Cette verification ne change PAS le statut de la tache en cours.
Elle sert uniquement a detecter et corriger les effets de bord avant de continuer.

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

Les resultats sont deja envoyes live (etape 4g).

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

```
=== RESUME ===
Tests: 5
Taches: 45 total, 40 succes, 3 echecs, 1 erreur, 1 suggestion
Taux de reussite: 89%
Resultats envoyes a AITestList.
```

**IMPORTANT:** Le rapport ci-dessus est la DERNIERE chose affichee. Ne JAMAIS ajouter
de texte supplementaire apres le rapport (pas de liste de ✅, pas de resume additionnel).
Le rapport EST le resume final.

## Gestion d'erreurs

### Erreurs fatales — ARRET IMMEDIAT

Ces erreurs arretent TOUTE l'execution. Ne JAMAIS continuer apres une erreur fatale.
Ne JAMAIS tenter de contourner le probleme (ex: chercher un autre token, deviner une URL).

- **MCP Playwright pas configure** → Afficher ❌ + "Ajoutez-le avec: /mcp add playwright" → **STOP**
- **Token invalide/revoque** → Afficher ❌ + "Token invalide. Generez-en un dans Settings > Integration." → **STOP**
- **API AITestList down** → Afficher ❌ + "Serveur AITestList injoignable" → **STOP**
- **File pas trouvee** → Afficher ❌ + "File #ID non trouvee." → **STOP**
- **File pas approuvee** → Afficher ❌ + "Approuvez-la dans AITestList." → **STOP**
- **Serveur cible injoignable** (voir ci-dessous) → **STOP**

### Serveur cible injoignable — Detection et arret

Apres le telechargement de la queue (etape 2), AVANT d'executer les tests:
1. Tenter une navigation vers `target_url` avec Playwright
2. Si `ERR_CONNECTION_REFUSED` ou timeout:
   a. Afficher: `❌ Target server unreachable: {target_url}`
   b. Marquer TOUTES les taches comme `erreur` avec commentaire "Target server unreachable: {target_url}"
   c. Envoyer les resultats a AITestList (toutes les taches en erreur)
   d. Afficher le rapport final
   e. **STOP** — ne pas essayer chaque tache individuellement

### Erreurs de tache — Continuer l'execution

Ces erreurs concernent une tache individuelle. On marque la tache en erreur et on continue.

- Element non trouve dans le snapshot → `erreur` + description
- Timeout sur une action specifique (click, fill) → `erreur` + description
- Erreur JavaScript dans la page → `erreur` + description

## Regle auto-fix

- Ne JAMAIS modifier le code source sauf si `auto_fix_enabled` est `true`
- Toujours reporter le probleme AVANT de tenter un fix
- Toujours re-tester apres un fix
- Documenter le fix dans le commentaire de la tache
- Apres toute modification (BD ou code), effectuer la verification post-action (max 3 tentatives)
- Les verifications post-action ne changent pas le statut de la tache
