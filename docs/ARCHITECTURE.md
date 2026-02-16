# aitestlist-testing - Architecture et Documentation

> Plugin Claude Code pour creer, executer et reporter des tests QA via AI TestList.
> Version: 1.0.0 | Auteur: 9524-2426 Quebec Inc.

## Table des matieres

1. [Vue d'ensemble](#vue-densemble)
2. [Structure du plugin](#structure-du-plugin)
3. [Configuration requise](#configuration-requise)
4. [Flow d'execution complet](#flow-dexecution-complet)
5. [Commands (points d'entree)](#commands-points-dentree)
6. [Skills (logique metier)](#skills-logique-metier)
7. [Agents (orchestration)](#agents-orchestration)
8. [API AITestList utilisee](#api-aitestlist-utilisee)
9. [Modes d'execution](#modes-dexecution)
10. [Installation](#installation)

---

## Vue d'ensemble

Le plugin `aitestlist-testing` connecte Claude Code a la plateforme AI TestList.
Il permet de:

- **Creer** des tests QA intelligents a partir de l'analyse d'un projet
- **Executer** ces tests automatiquement via MCP Playwright
- **Reporter** les resultats en temps reel au serveur AITestList
- **Analyser** les echecs et generer des rapports d'erreurs PDF

### Principe de fonctionnement

```
Utilisateur
    |
    v
Commands (/create, /exec, /report, /status)    <-- Points d'entree
    |
    v
Agents (test-creator, test-executor)            <-- Orchestration (optionnel)
    |
    v
Skills (create-test, exec-test, etc.)           <-- Logique metier
    |
    v
API REST AITestList (localhost:8001)             <-- Serveur
```

Les **commands** sont les points d'entree utilisateur. Elles invoquent les **skills**
qui contiennent la logique. Les **agents** sont optionnels et servent a orchestrer
des workflows complexes (analyse de projet, execution multi-agent).

---

## Structure du plugin

```
aitestlist-testing/
|
|-- .claude-plugin/
|   |-- plugin.json              # Metadata du plugin (nom, version, auteur)
|   |-- marketplace.json         # Configuration marketplace (skills exposes)
|
|-- skills/                      # Logique metier (9 skills)
|   |-- preflight/SKILL.md       # Verification centralisee (token, langue, URL)
|   |-- create-test/SKILL.md     # Creation de tests QA
|   |-- create-payment/SKILL.md  # Creation de tests payment (Stripe/PayPal)
|   |-- exec-test/SKILL.md       # Execution de tests via Playwright
|   |-- exec-payment/SKILL.md    # Execution de tests payment (iframes Stripe)
|   |-- exec-email/SKILL.md      # Gestion des emails de test (alias Zoho)
|   |-- exec-db-elevation/SKILL.md # Elevation temporaire de permissions BD
|   |-- report-live/SKILL.md     # Push des resultats en temps reel
|   |-- error-report/SKILL.md    # Analyse des echecs + rapport PDF
|
|-- agents/                      # Orchestrateurs (3 agents)
|   |-- test-creator.md          # Orchestre l'analyse de projet + creation
|   |-- test-executor.md         # Orchestre l'execution (sequentiel ou teams)
|   |-- test-reporter.md         # Hub de reporting en mode teams
|
|-- commands/                    # Points d'entree utilisateur (4 commands)
|   |-- create.md                # /aitestlist-testing:create
|   |-- exec.md                  # /aitestlist-testing:exec
|   |-- report.md                # /aitestlist-testing:report
|   |-- status.md                # /aitestlist-testing:status
|
|-- docs/                        # Documentation
|   |-- ARCHITECTURE.md          # Ce fichier
|
|-- install.sh                   # Installeur Linux/macOS
|-- install.ps1                  # Installeur Windows
```

### Hierarchie des composants

```
Commands (entree utilisateur)
  |
  |-- /create  --> skill create-test
  |                   |-- skill preflight (token, langue, URL)
  |                   |-- skill create-payment (si paiement detecte)
  |
  |-- /exec    --> skill exec-test
  |                   |-- skill preflight (token, langue, URL)
  |                   |-- skill exec-payment (si [PAYMENT_TEST])
  |                   |-- skill exec-email (si [CREATE_TEST_EMAIL])
  |                   |-- skill exec-db-elevation (si restriction plan/role)
  |                   |-- skill report-live (apres chaque tache)
  |
  |-- /report  --> skill error-report
  |                   |-- skill preflight (token, langue, URL)
  |
  |-- /status  --> (inline, pas de skill)
```

---

## Configuration requise

### Variables d'environnement

| Variable | Requis | Description |
|----------|--------|-------------|
| `AITESTLIST_TOKEN` | Oui | Token API Bearer (genere dans Settings > Integration) |
| `AITESTLIST_URL` | Non | URL du serveur (defaut: `http://localhost:8001`) |

### Dependances

| Composant | Requis pour | Installation |
|-----------|-------------|-------------|
| MCP Playwright | /exec | `/mcp add playwright` dans Claude Code |
| Serveur AITestList | Tout | `py app.py` (port 8001) |

---

## Flow d'execution complet

### Flow 1: Creation de tests (`/aitestlist-testing:create`)

```
Utilisateur: /aitestlist-testing:create "tester la page login"
    |
    v
[command create.md]
    | Invoque skill create-test
    v
[skill preflight]                       <-- ETAPE 1
    | 1. Resout URL ($AITESTLIST_URL ou defaut)
    | 2. Verifie $AITESTLIST_TOKEN existe
    | 3. Valide token via GET /api/status
    | 4. Detecte langue via GET /api/language
    | Retourne: URL, TOKEN valide, USER_LANG
    v
[skill create-test]                     <-- ETAPES 2-7
    | 2. GET /api/categories?lang={USER_LANG}
    | 3. Analyse le projet (code source, .aitestlist/project-analysis.md)
    | 4. Detecte specialites (Stripe? PayPal?)
    |     |-- Si oui: [skill create-payment] genere taches [PAYMENT_TEST]
    | 5. Genere les taches de test (dans USER_LANG)
    | 6. POST /api/tests/submit {name, tasks, project_id}
    | 7. Confirme: "Test soumis, voir /import-queue"
    v
[Serveur AITestList]
    | @require_api_token valide chaque appel
    | Test place dans la queue d'import
    | L'utilisateur approuve dans l'UI web
```

**Qui verifie le token a chaque etape:**
- Etape 1 (preflight): verifie que le token existe + `GET /api/status` pour validation serveur
- Etapes 2-7 (create-test): chaque `curl` envoie `Bearer $AITESTLIST_TOKEN`, le decorateur `@require_api_token` cote serveur valide

### Flow 2: Execution de tests (`/aitestlist-testing:exec 42`)

```
Utilisateur: /aitestlist-testing:exec 42
    |
    v
[command exec.md]
    | Invoque skill exec-test avec queue_id=42
    v
[skill preflight]                           <-- ETAPE 1A
    | URL, TOKEN, USER_LANG
    v
[skill exec-test]                           <-- ETAPES 1B-6
    | 1B. Verifie MCP Playwright disponible
    | 1C. Verifie mode teams (settings.json)
    | 1D. Detecte mode d'execution (GET /api/settings/exec-mode)
    |     → headless, headed 1280x720, ou fullscreen
    |
    | 2. Telecharge la queue (GET /api/execution-queue/42/download)
    |     → tests, taches, rules globales, rules projet, auto_fix
    |
    | 3. Lit les rules et le flag auto-fix
    |
    | 4. Pour chaque tache (sequentiel):
    |     |
    |     |-- Verifie delegation necessaire:
    |     |   [PAYMENT_TEST] --> [skill exec-payment]
    |     |       | Verifie toggle payment_testing.enabled
    |     |       | Utilise cartes test Stripe (4242...)
    |     |       | Gere iframes Stripe Elements
    |     |
    |     |   [CREATE_TEST_EMAIL:ctx] --> [skill exec-email]
    |     |       | POST /api/email-testing/aliases (cree alias)
    |     |       | POST .../wait (attend reception)
    |     |       | GET .../emails/{id} (lit contenu + liens)
    |     |       | DELETE .../aliases/... (cleanup)
    |     |
    |     |   Echec restriction plan --> [skill exec-db-elevation]
    |     |       | Lit etat user en BD
    |     |       | Eleve permissions (UPDATE)
    |     |       | Re-teste la tache
    |     |       | Restaure permissions originales
    |     |
    |     |-- Execute via MCP Playwright:
    |     |   browser_navigate → browser_snapshot → browser_click/type
    |     |   → browser_snapshot → verifie resultat attendu
    |     |
    |     |-- Reporte le resultat live:
    |     |   [skill report-live]
    |     |       | POST /api/execution-queue/42/result
    |     |       | {task_id, status, comment}
    |     |       | 1er appel: cree le Run + queue → 'running'
    |     |       | Appels suivants: ajoute au Run actif
    |     |
    |     |-- Si auto_fix ET echec:
    |     |   Analyse le code source → applique fix → re-teste
    |
    | 5. POST /api/execution-queue/42/finalize
    |     → Queue passe de 'running' a 'executed'
    |     → Met a jour statuts agreges des tests
    |
    | 6. Affiche rapport final (dans USER_LANG)
    v
[Frontend AITestList]
    | La page execution-detail poll toutes les 3s
    | Les resultats apparaissent en temps reel
    | Badge "Live" → "Completed" quand termine
```

### Flow 3: Rapport d'erreurs (`/aitestlist-testing:report`)

```
Utilisateur: /aitestlist-testing:report
    |
    v
[command report.md]
    | Invoque skill error-report
    v
[skill preflight]                       <-- ETAPE 1
    | URL, TOKEN, USER_LANG
    v
[skill error-report]                    <-- ETAPES 2-6
    | 2. GET /api/projects → liste des projets
    |    L'utilisateur choisit un projet
    | 3. GET /api/projects/{id}/failed-tasks
    | 4. Analyse chaque tache echouee:
    |    - error: description concise
    |    - cause: cause racine
    |    - solutions: 3 solutions actionnables
    | 5. POST /api/reports/error-analysis {project_id, diagnoses}
    |    → Le serveur genere le PDF
    | 6. Confirme: "Rapport disponible dans AITestList > Reports"
```

### Flow 4: Status (`/aitestlist-testing:status`)

```
Utilisateur: /aitestlist-testing:status
    |
    v
[command status.md]  (inline, pas de skill)
    | 1. echo $AITESTLIST_TOKEN → defini?
    | 2. curl /api/status → serveur accessible?
    | 3. curl /api/language → langue configuree?
    | 4. browser_navigate test → Playwright disponible?
    | 5. curl /api/settings/exec-mode → mode + payment config?
    | 6. cat ~/.claude/settings.json → teams mode?
    v
Affiche un tableau avec icones de statut
```

---

## Commands (points d'entree)

Les commands sont les raccourcis que l'utilisateur tape. Elles sont minimalistes
et delegent immediatement aux skills.

### /aitestlist-testing:create

| Propriete | Valeur |
|-----------|--------|
| Fichier | `commands/create.md` |
| Description | Cree des tests QA pour un projet |
| Skill invoque | `aitestlist-testing:create-test` |
| Arguments | Description du test a creer (texte libre) |
| Exemple | `/aitestlist-testing:create tester la page d'inscription` |

### /aitestlist-testing:exec

| Propriete | Valeur |
|-----------|--------|
| Fichier | `commands/exec.md` |
| Description | Execute une queue de tests approuvee via Playwright |
| Skill invoque | `aitestlist-testing:exec-test` |
| Arguments | ID de la queue (requis) |
| Exemple | `/aitestlist-testing:exec 42` |

### /aitestlist-testing:report

| Propriete | Valeur |
|-----------|--------|
| Fichier | `commands/report.md` |
| Description | Genere un rapport d'analyse des erreurs |
| Skill invoque | `aitestlist-testing:error-report` |
| Arguments | (optionnel) project_id |
| Exemple | `/aitestlist-testing:report` |

### /aitestlist-testing:status

| Propriete | Valeur |
|-----------|--------|
| Fichier | `commands/status.md` |
| Description | Verifie l'etat de la connexion et des dependances |
| Skill invoque | Aucun (logique inline) |
| Arguments | Aucun |
| Exemple | `/aitestlist-testing:status` |

---

## Skills (logique metier)

Les skills contiennent les instructions detaillees que Claude execute.
Chaque skill est un fichier SKILL.md dans son propre dossier.

### preflight

| Propriete | Valeur |
|-----------|--------|
| Fichier | `skills/preflight/SKILL.md` |
| Role | Verification centralisee avant tout autre skill |
| Appele par | create-test, exec-test, error-report |
| Appelle | Aucun autre skill |
| API utilisee | `GET /api/status`, `GET /api/language` |

**Ce qu'il fait:**
1. Resout l'URL du serveur (`$AITESTLIST_URL` ou defaut `http://localhost:8001`)
2. Verifie que `$AITESTLIST_TOKEN` est defini
3. Valide le token contre `/api/status`
4. Detecte la langue via `/api/language`

**Variables produites:** `URL`, `AITESTLIST_TOKEN` (valide), `USER_LANG`

**Pourquoi il existe:** Centralise la logique d'authentification et de detection
pour eviter la duplication dans chaque skill. Un seul endroit a modifier si
l'URL ou le mecanisme d'auth change.

---

### create-test

| Propriete | Valeur |
|-----------|--------|
| Fichier | `skills/create-test/SKILL.md` |
| Role | Generer et soumettre des tests QA a AITestList |
| Appele par | command /create, agent test-creator |
| Appelle | preflight, create-payment (si paiement detecte) |
| API utilisee | `GET /api/categories`, `GET /api/projects`, `POST /api/tests/submit` |

**Ce qu'il fait:**
1. Appelle preflight (token, langue, URL)
2. Recupere les categories dans la langue de l'utilisateur
3. Analyse le contexte du projet (code source, `.aitestlist/project-analysis.md`)
4. Detecte les specialites (Stripe, PayPal) → delegue a create-payment si besoin
5. Genere les taches de test dans `USER_LANG`
6. Soumet via `POST /api/tests/submit`

**Regles importantes:**
- Tous les textes (titres, descriptions) sont dans `USER_LANG`, pas la langue de la conversation
- Les categories viennent de l'API (jamais hardcodees)
- Les emails utilisent `[CREATE_TEST_EMAIL:{context}]` (jamais d'adresses reelles)
- Chaque test commence par `[SETUP]` et finit par `[TEARDOWN]`
- Ordre logique: SETUP → happy path → fonctionnalites → validation → edge cases → securite → TEARDOWN

---

### create-payment

| Propriete | Valeur |
|-----------|--------|
| Fichier | `skills/create-payment/SKILL.md` |
| Role | Generer des taches de test specifiques aux paiements |
| Appele par | create-test (quand Stripe/PayPal detecte) |
| Appelle | Aucun |
| API utilisee | Aucune (retourne des taches au caller) |

**Ce qu'il fait:**
- Detecte les systemes de paiement dans le code (Stripe, PayPal)
- Genere des scenarios: checkout, upgrade, downgrade, annulation, carte decline
- Toutes les taches ont le marqueur `[PAYMENT_TEST]` dans la description
- Utilise les cartes test Stripe (4242..., 4000...0002, etc.)

---

### exec-test

| Propriete | Valeur |
|-----------|--------|
| Fichier | `skills/exec-test/SKILL.md` |
| Role | Executer les tests via MCP Playwright + reporter live |
| Appele par | command /exec, agent test-executor |
| Appelle | preflight, exec-payment, exec-email, exec-db-elevation, report-live |
| API utilisee | `GET /api/settings/exec-mode`, `GET /api/execution-queue/{id}/download`, `POST /api/execution-queue/{id}/finalize` |

**Ce qu'il fait:**
1. Appelle preflight (token, langue, URL)
2. Verifie MCP Playwright
3. Verifie mode teams (multi-agent)
4. Detecte le mode d'execution (headless, headed, fullscreen)
5. Telecharge la queue (tests, taches, rules)
6. Execute chaque tache via Playwright (snapshot/click/type/verify)
7. Delegue aux skills specialises si necessaire
8. Reporte chaque resultat live via report-live
9. Finalise la queue (`POST /finalize`)
10. Affiche le rapport final

**Modes Playwright:**

| Mode | Browser | Fenetre |
|------|---------|---------|
| `batch` | headless | Aucune |
| `interactive_headless` | headless | Terminal visible |
| `interactive_browser_minimal` | headed | 1280x720 |
| `interactive_browser_fullscreen` | headed | Maximisee |

**Delegation aux skills specialises:**

| Condition dans la tache | Skill delegue | Action |
|-------------------------|---------------|--------|
| `[PAYMENT_TEST]` dans description | exec-payment | Verifie toggle + cartes test |
| `[CREATE_TEST_EMAIL:ctx]` dans description | exec-email | Cree alias email, attend, lit |
| Echec par restriction plan/role | exec-db-elevation | Eleve permissions BD |

---

### exec-payment

| Propriete | Valeur |
|-----------|--------|
| Fichier | `skills/exec-payment/SKILL.md` |
| Role | Executer les tests de paiement (Stripe Elements, Checkout, PayPal) |
| Appele par | exec-test (quand tache contient `[PAYMENT_TEST]`) |
| Appelle | Aucun |
| API utilisee | `GET /api/settings/exec-mode` (pour `payment_testing` config) |

**Verifications de securite avant execution:**
- `payment_testing.enabled` doit etre `true` sinon SKIP
- `stripe_mode` ne doit pas etre `live` sinon ERREUR
- `paypal_mode` ne doit pas etre `live` sinon ERREUR

**Cartes test Stripe:**

| Carte | Resultat |
|-------|----------|
| `4242 4242 4242 4242` | Paiement reussi |
| `4000 0000 0000 0002` | Carte declinee |
| `4000 0025 0000 3155` | 3D Secure requis |
| `4000 0000 0000 9995` | Fonds insuffisants |

**Gestion des iframes Stripe Elements:**
Les champs de carte Stripe sont dans des iframes. Le skill utilise
`page.frameLocator('iframe[name*="__privateStripeFrame"]')` pour y acceder.

---

### exec-email

| Propriete | Valeur |
|-----------|--------|
| Fichier | `skills/exec-email/SKILL.md` |
| Role | Gerer les emails de test (creation, attente, lecture, nettoyage) |
| Appele par | exec-test (quand tache contient `[CREATE_TEST_EMAIL]`) |
| Appelle | Aucun |
| API utilisee | `/api/email-testing/aliases` (CRUD), `/api/email-testing/emails/{id}` |

**Convention de nommage:** `claude.{role}_queue{id}@aitestlist.com`

**Cycle de vie d'un email de test:**
1. `POST /aliases` → cree l'alias (ex: `claude.user1_queue4@aitestlist.com`)
2. Utilise l'alias dans un formulaire d'inscription via Playwright
3. `POST /aliases/{alias}/wait` → attend la reception (timeout 30s)
4. `GET /emails/{message_id}` → lit le contenu + extrait les liens
5. Navigue vers le lien de verification via Playwright
6. `DELETE /aliases/{alias}` → nettoyage (obligatoire, meme en cas d'echec)

**Mapping contexte → alias:** Le meme `[CREATE_TEST_EMAIL:login_test]` reutilise
toujours le meme alias a travers toutes les taches du test.

---

### exec-db-elevation

| Propriete | Valeur |
|-----------|--------|
| Fichier | `skills/exec-db-elevation/SKILL.md` |
| Role | Elever temporairement les permissions d'un user de test en BD |
| Appele par | exec-test (quand une tache echoue par restriction plan/role) |
| Appelle | Aucun |
| API utilisee | Aucune API AITestList (acces direct BD du projet teste) |

**Workflow:**
1. Lit l'etat actuel du user de test en BD (`SELECT * FROM users WHERE email=...`)
2. Identifie le champ a modifier (`role`, `plan`, `is_admin`, etc.)
3. Eleve les permissions (`UPDATE users SET role='admin'`)
4. Re-teste la tache via Playwright
5. Restaure l'etat original
6. Reporte le resultat avec mention de l'elevation

**Prerequis:** La queue doit contenir `database_config` (non null).
Configure dans AITestList > Settings > Execution > Database.

**Drivers supportes:** MySQL, PostgreSQL, SQLite, SQL Server, MongoDB

---

### report-live

| Propriete | Valeur |
|-----------|--------|
| Fichier | `skills/report-live/SKILL.md` |
| Role | Pousser un resultat individuel au serveur en temps reel |
| Appele par | exec-test (apres chaque tache), agent test-reporter (en mode teams) |
| Appelle | Aucun |
| API utilisee | `POST /api/execution-queue/{id}/result` |

**Endpoint singulier vs batch:**
- `/result` (ce skill) — une tache a la fois, temps reel
- `/results` (batch final) — toutes les taches d'un coup, backup

**Comportement cote serveur:**
- 1er appel: cree automatiquement un `ExecutionQueueRun` + queue → `running`
- Appels suivants: ajoute les resultats au Run actif
- Met a jour le statut de la tache en BD

**Effet cote client:**
Le frontend de la page execution-detail poll toutes les 3s.
Les resultats apparaissent progressivement: gris → vert/rouge/orange.

**Retry:** Si timeout ou erreur 500, retry 1x apres 2 secondes.
Si retry echoue, stocker localement et continuer.

---

### error-report

| Propriete | Valeur |
|-----------|--------|
| Fichier | `skills/error-report/SKILL.md` |
| Role | Analyser les taches echouees et generer un rapport PDF |
| Appele par | command /report, agent test-reporter |
| Appelle | preflight |
| API utilisee | `GET /api/projects`, `GET /api/projects/{id}/failed-tasks`, `POST /api/reports/error-analysis` |

**Ce qu'il fait:**
1. Appelle preflight
2. Liste les projets, l'utilisateur choisit
3. Recupere les taches echouees
4. Pour chaque tache, produit un diagnostic:
   - `error`: description concise (1-2 phrases)
   - `cause`: cause racine (2-3 phrases)
   - `solutions`: 3 solutions actionnables ordonnees par priorite
5. Envoie les diagnostics au serveur qui genere le PDF
6. Confirme la disponibilite du rapport

**Qualite des diagnostics:** Le skill contient des exemples de bons et mauvais
diagnostics pour guider l'IA. Les diagnostics generiques ("verifier le code")
sont explicitement interdits.

---

## Agents (orchestration)

Les agents sont des processus Claude specialises. Ils orchestrent les skills
mais ne communiquent **jamais directement avec l'API** — ce sont les skills qui le font.

### test-creator

| Propriete | Valeur |
|-----------|--------|
| Fichier | `agents/test-creator.md` |
| Modele | Opus |
| Max turns | 25 |
| Tools | Read, Write, Glob, Grep, Skill, Bash |
| Quand l'utiliser | Pour une analyse approfondie de projet avant creation |

**Role:** Analyser un projet en profondeur avant de creer les tests.

**Workflow:**
1. Cherche `.aitestlist/project-analysis.md` (analyse existante)
2. Si absent: scanne le projet (stack, architecture, auth, data, services, UI, API, business logic, permissions)
3. Cree `.aitestlist/project-analysis.md` avec l'analyse complete
4. Appelle `/aitestlist-testing:create-test` avec le contexte

**Quand utiliser l'agent vs le skill directement:**
- **Skill seul** (`/create`): pour un test rapide sur un sujet specifique
- **Agent** (`@test-creator`): pour une analyse complete du projet et la generation de tests couvrant toutes les fonctionnalites

---

### test-executor

| Propriete | Valeur |
|-----------|--------|
| Fichier | `agents/test-executor.md` |
| Modele | Opus |
| Tools | Bash, Read, Skill, Task, SendMessage, tous les outils MCP Playwright |
| Quand l'utiliser | Surtout en mode teams pour l'execution parallele |

**Role:** Orchestrer l'execution des tests, en mode sequentiel ou teams.

**Mode sequentiel:**
1. Appelle `/aitestlist-testing:exec-test <queue_id>`
2. Le skill gere tout seul

**Mode teams (multi-agent):**
1. Telecharge la queue via l'API
2. Spawne l'agent `test-reporter` en background
3. Divise les tests en batches
4. Spawne N exec agents, chacun avec un batch
5. Chaque exec agent execute ses tests et envoie les resultats au reporter
6. Le reporter pousse chaque resultat live au serveur
7. Quand tout est fini, le reporter genere le rapport final
8. Shutdown de tous les agents

```
test-executor (leader)
    |
    |-- test-reporter (Sonnet, hub de reporting)
    |       ^  ^  ^
    |       |  |  |
    |-- exec-agent-1 (batch 1) --+
    |-- exec-agent-2 (batch 2) --+
    |-- exec-agent-3 (batch 3) --+
```

---

### test-reporter

| Propriete | Valeur |
|-----------|--------|
| Fichier | `agents/test-reporter.md` |
| Modele | Sonnet (leger, son travail est simple) |
| Tools | Bash, Read, Skill, SendMessage |
| Quand il existe | Uniquement en mode teams |

**Role:** Point central de reporting en mode multi-agent.

**Phase 1 — Pendant l'execution:**
- Recoit les resultats des exec agents via `SendMessage`
- Appelle `/aitestlist-testing:report-live` pour chaque resultat
- Maintient un compteur running (total, succes, echecs, erreurs)
- Affiche la progression periodiquement

**Phase 2 — Apres l'execution:**
- Verifie s'il y a des taches en echec
- Si oui: appelle `/aitestlist-testing:error-report` pour le rapport PDF
- Affiche le resume final

**Pourquoi Sonnet:** Son travail est mecanique (recevoir → poster → compter).
Pas besoin de la puissance d'Opus pour ca.

**Pourquoi un agent dedie:** En mode teams, plusieurs exec agents postent des
resultats en parallele. Sans hub central, ils se marcheraient sur les pieds
en postant tous directement a l'API.

---

## API AITestList utilisee

Resume de tous les endpoints API utilises par le plugin.

### Authentification

Toutes les requetes utilisent le header `Authorization: Bearer $AITESTLIST_TOKEN`.
Le decorateur `@require_api_token` cote serveur:
1. Extrait le token du header
2. Cherche dans la table `api_tokens` en BD
3. Si valide: met le user dans `g.api_user`
4. Si invalide: retourne 401

### Endpoints

| Methode | Endpoint | Skill(s) | Description |
|---------|----------|----------|-------------|
| GET | `/api/status` | preflight | Verification connexion + token |
| GET | `/api/language` | preflight | Langue de l'utilisateur |
| GET | `/api/categories` | create-test | Categories hierarchiques |
| GET | `/api/projects` | create-test, error-report | Liste des projets |
| POST | `/api/tests/submit` | create-test | Soumettre un test |
| GET | `/api/settings/exec-mode` | exec-test, exec-payment | Mode d'execution + config payment |
| GET | `/api/execution-queue/{id}/download` | exec-test | Telecharger queue + taches + rules |
| GET | `/api/execution-queue/{id}/status` | exec-test | Statut queue + progression run |
| POST | `/api/execution-queue/{id}/result` | report-live | Push un resultat (singulier, live) |
| POST | `/api/execution-queue/{id}/results` | exec-test | Push resultats (batch, backup) |
| POST | `/api/execution-queue/{id}/finalize` | exec-test | Marquer execution terminee |
| GET | `/api/projects/{id}/failed-tasks` | error-report | Taches echouees d'un projet |
| POST | `/api/reports/error-analysis` | error-report | Envoyer diagnostics pour PDF |
| POST | `/api/email-testing/aliases` | exec-email | Creer alias email |
| POST | `/api/email-testing/aliases/{alias}/wait` | exec-email | Attendre reception email |
| GET | `/api/email-testing/emails/{id}` | exec-email | Lire contenu email |
| DELETE | `/api/email-testing/aliases/{alias}` | exec-email | Supprimer alias |

### Cycle de vie d'une queue

```
draft → pending → approved → running → executed
                                ^           ^
                                |           |
                          1er POST /result   POST /finalize
```

---

## Modes d'execution

### Mode sequentiel vs teams

| Aspect | Sequentiel | Teams (multi-agent) |
|--------|-----------|---------------------|
| Activation | Par defaut | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| Agents | 0 (skill seul) | 1 reporter + N exec agents |
| Parallelisme | Non | Oui (tests divises en batches) |
| Reporting | exec-test → report-live | exec-agents → reporter → report-live |
| Modele reporter | N/A | Sonnet |
| Modele exec | Opus (courant) | Opus (par agent) |

### Mode Playwright

| Mode | Headless | Resolution | Utilisation |
|------|----------|-----------|-------------|
| `batch` | Oui | N/A | CI/CD, `claude -p` |
| `interactive_headless` | Oui | N/A | Terminal interactif sans browser |
| `interactive_browser_minimal` | Non | 1280x720 | Defaut, fenetre compacte |
| `interactive_browser_fullscreen` | Non | Maximisee | Tests visuels, screenshots |

---

## Installation

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/carthack/aitestlist-testing/main/install.ps1 | iex
```

### Linux / macOS (Bash)

```bash
curl -sSL https://raw.githubusercontent.com/carthack/aitestlist-testing/main/install.sh | bash
```

### Ce que fait l'installeur

1. Clone le repo dans `~/.claude/plugins/cache/aitestlist/aitestlist-testing/1.0.0/`
2. Enregistre le plugin dans `~/.claude/plugins/installed_plugins.json`
3. Supprime les anciens fichiers standalone s'ils existent:
   - `~/.claude/agents/test-creator.md`
   - `~/.claude/agents/test-exec.md`
   - `~/.claude/skills/checklist-test-creator/`
   - `~/.claude/skills/exec-test/`
   - `~/.claude/skills/aitestlist-error-report/`

### Configuration post-installation

```bash
# Definir le token (obligatoire)
export AITESTLIST_TOKEN=at_xxxxxxxxxxxxx

# Optionnel: URL custom (defaut: http://localhost:8001)
export AITESTLIST_URL=https://aitestlist.com

# Optionnel: ajouter MCP Playwright (requis pour /exec)
/mcp add playwright
```

---

> Derniere mise a jour: 2026-02-15
