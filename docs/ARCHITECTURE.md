# aitestlist-testing - Architecture et Documentation

> Plugin Claude Code pour creer, executer et reporter des tests QA via AI TestList.
> Version: 1.1.0 | Auteur: 9524-2426 Quebec Inc.

## Table des matieres

1. [Vue d'ensemble](#vue-densemble)
2. [Structure du plugin](#structure-du-plugin)
3. [Configuration requise](#configuration-requise)
4. [Points d'entree utilisateur](#points-dentree-utilisateur)
5. [Flow d'execution complet](#flow-dexecution-complet)
6. [Agents (points d'entree principaux)](#agents-points-dentree-principaux)
7. [Skills (instructions prechargees)](#skills-instructions-prechargees)
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
    |-- @test-creator      → Agent (analyse projet + creation tests)
    |-- @test-executor     → Agent (execution tests via Playwright)
    |-- @test-reporter     → Agent (rapport d'erreurs PDF)
    |-- /status            → Skill (diagnostic connexion)
    |
    v
Agents prechargent les skills via le champ `skills:` dans leur frontmatter.
Les skills ne s'appellent jamais entre eux.
    |
    v
API REST AITestList ($AITESTLIST_URL)
```

**Architecture:**
- Les **agents** sont les points d'entree principaux (3 agents)
- Les **skills** sont des instructions prechargees dans les agents (14 skills)
- Un seul skill est user-invocable: `/status`
- Aucun skill n'appelle un autre skill — tout est prechage via `skills:` field

---

## Structure du plugin

```
aitestlist-testing/
|
|-- .claude-plugin/
|   |-- plugin.json              # Metadata du plugin (nom, version, auteur)
|   |-- marketplace.json         # Configuration marketplace (auto-discovery)
|
|-- agents/                      # Points d'entree principaux (3 agents)
|   |-- test-creator.md          # Analyse projet + creation tests
|   |-- test-executor.md         # Execution tests via Playwright
|   |-- test-reporter.md         # Reporting + rapport d'erreurs
|
|-- skills/                      # Instructions prechargees (14 skills)
|   |-- status/SKILL.md          # Diagnostic connexion (seul user-invocable)
|   |-- preflight/SKILL.md       # Auth centralisee (token, langue, URL)
|   |-- create-test/SKILL.md     # Creation de tests QA
|   |-- create-payment/SKILL.md  # Creation de tests payment (Stripe/PayPal)
|   |-- exec-test/SKILL.md       # Execution de tests via Playwright
|   |-- exec-payment/SKILL.md    # Execution de tests payment (iframes Stripe)
|   |-- exec-email/SKILL.md      # Gestion des emails de test (alias Zoho)
|   |-- exec-db-elevation/SKILL.md # Elevation temporaire de permissions BD
|   |-- report-live/SKILL.md     # Push des resultats en temps reel
|   |-- error-report/SKILL.md    # Analyse des echecs + rapport PDF
|   |-- pdf/SKILL.md             # Generation/manipulation de PDF (+ scripts)
|   |-- docx/SKILL.md            # Creation/edition de documents Word (+ scripts)
|   |-- xlsx/SKILL.md            # Creation/edition de spreadsheets Excel (+ scripts)
|   |-- pptx/SKILL.md            # Creation/edition de presentations PowerPoint (+ scripts)
|
|-- docs/                        # Documentation
|   |-- ARCHITECTURE.md          # Ce fichier
|   |-- PLAN-REFACTOR-V2.md      # Plan du refactor v2
|
|-- install.sh                   # Installeur Linux/macOS
|-- install.ps1                  # Installeur Windows
```

### Comment les agents prechargent les skills

Chaque agent declare les skills dont il a besoin dans son frontmatter.
Le contenu des skills est injecte dans le system prompt de l'agent au demarrage.
L'agent n'a pas besoin d'"appeler" les skills — il connait deja toutes les instructions.

```yaml
# Exemple: agents/test-creator.md
---
name: test-creator
skills:
  - preflight        # → Auth, URL, langue
  - create-test      # → Generation + soumission tests
  - create-payment   # → Tests payment si detecte
---
```

| Agent | Skills precharges |
|-------|-------------------|
| test-creator | preflight, create-test, create-payment |
| test-executor | preflight, exec-test, exec-payment, exec-email, exec-db-elevation, report-live |
| test-reporter | preflight, report-live, error-report |

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
| MCP Playwright | @test-executor | `/mcp add playwright` dans Claude Code |
| Serveur AITestList | Tout | `py app.py` (port 8001) |

---

## Points d'entree utilisateur

| Entree | Type | Modele | Usage |
|--------|------|--------|-------|
| `@test-creator` | Agent | Opus | Analyser un projet et creer des tests QA |
| `@test-executor` | Agent | Opus | Executer une queue de tests via Playwright |
| `@test-reporter` | Agent | Sonnet | Generer un rapport d'erreurs PDF |
| `/aitestlist-testing:status` | Skill | - | Diagnostic connexion et configuration |

Tous les autres skills sont `user-invocable: false` et ne sont pas visibles dans le menu `/`.

---

## Flow d'execution complet

### Flow 1: Creer des tests (`@test-creator`)

```
Utilisateur: @test-creator analyse ce projet et cree les tests
    |
    v
[agent test-creator]
    | skills precharges: preflight, create-test, create-payment
    |
    | 1. PREFLIGHT (instructions dans son contexte)
    |    - Resout URL ($AITESTLIST_URL ou defaut)
    |    - Verifie $AITESTLIST_TOKEN
    |    - Valide via GET ${URL}/api/status
    |    - Detecte langue via GET ${URL}/api/language
    |
    | 2. ANALYSE DU PROJET (scan fresh, pas de cache)
    |    - Detecte stack (package.json, requirements.txt, etc.)
    |    - Analyse: architecture, auth, data, services, UI, API
    |    - Detecte specialites (Stripe, PayPal)
    |
    | 3. GENERATION DES TESTS
    |    - GET ${URL}/api/categories?lang=${USER_LANG}
    |    - Genere taches dans USER_LANG
    |    - Si payment detecte: utilise instructions create-payment
    |    - POST ${URL}/api/tests/submit
    |
    | 4. CONFIRMATION
    |    - Nombre de taches creees
    |    - Lien vers ${URL}/import-queue
    v
[Serveur AITestList]
    | @require_api_token valide chaque appel
    | Test place dans la queue d'import
```

### Flow 2: Executer des tests (`@test-executor`)

```
Utilisateur: @test-executor execute la queue 42
    |
    v
[agent test-executor]
    | skills precharges: preflight, exec-test, exec-payment,
    |                    exec-email, exec-db-elevation, report-live
    |
    | 1. PREFLIGHT + VERIFICATIONS
    |    - URL, token, langue (preflight)
    |    - MCP Playwright disponible?
    |    - Mode teams active?
    |    - GET ${URL}/api/settings/exec-mode → mode Playwright
    |
    | 2. TELECHARGER LA QUEUE
    |    - GET ${URL}/api/execution-queue/42/download
    |    - Lit rules globales + projet + flag auto_fix
    |
    | 3. EXECUTER CHAQUE TACHE
    |    Pour chaque tache:
    |    |
    |    |-- Delegation si necessaire:
    |    |   [PAYMENT_TEST] → instructions exec-payment (prechargees)
    |    |   [CREATE_TEST_EMAIL] → instructions exec-email (prechargees)
    |    |   Echec plan/role → instructions exec-db-elevation (prechargees)
    |    |
    |    |-- Executer via MCP Playwright
    |    |   browser_navigate → browser_snapshot → browser_click/type
    |    |
    |    |-- Reporter live (instructions report-live prechargees)
    |    |   POST ${URL}/api/execution-queue/42/result
    |    |   1er appel: cree le Run + queue → 'running'
    |    |
    |    |-- Si auto_fix ET echec:
    |    |   Analyse code source → fix → re-teste
    |
    | 4. FINALISER
    |    - POST ${URL}/api/execution-queue/42/finalize
    |    - Queue passe de 'running' a 'executed'
    |
    | 5. RAPPORT FINAL (dans USER_LANG)
    v
[Frontend AITestList]
    | Poll toutes les 3s → resultats en direct
    | Badge "Live" → "Completed"
```

### Flow 2b: Mode teams (multi-agent)

```
[agent test-executor] (leader)
    |
    | 1. Telecharge la queue
    | 2. Spawne test-reporter en background
    | 3. Divise les tests en batches
    | 4. Spawne N exec agents
    |
    |-- [test-reporter] (Sonnet)
    |       skills: preflight, report-live, error-report
    |       ^  ^  ^
    |       |  |  |  (SendMessage: resultats)
    |       |  |  |
    |-- [exec-agent-1] (batch 1) --+
    |-- [exec-agent-2] (batch 2) --+
    |-- [exec-agent-3] (batch 3) --+
    |
    | test-reporter:
    |   - Recoit resultats → POST /result (live)
    |   - Maintient compteur
    |   - Apres execution: analyse echecs → rapport PDF
    |
    | 5. Shutdown tous les agents
```

### Flow 3: Rapport d'erreurs (`@test-reporter`)

```
Utilisateur: @test-reporter genere un rapport pour le projet X
    |
    v
[agent test-reporter]
    | skills precharges: preflight, report-live, error-report
    |
    | 1. PREFLIGHT: URL, token, langue
    | 2. GET ${URL}/api/projects → choisir un projet
    | 3. GET ${URL}/api/projects/{id}/failed-tasks
    | 4. Analyser chaque echec:
    |    - error: description concise
    |    - cause: cause racine
    |    - solutions: 3 solutions actionnables
    | 5. POST ${URL}/api/reports/error-analysis
    | 6. Confirmer la disponibilite du rapport
```

### Flow 4: Diagnostic (`/aitestlist-testing:status`)

```
Utilisateur: /aitestlist-testing:status
    |
    v
[skill status] (seul skill user-invocable)
    | Auth inline (pas de preflight, skill autonome)
    | 1. Resout URL ($AITESTLIST_URL ou defaut)
    | 2. echo $AITESTLIST_TOKEN → defini?
    | 3. curl /api/status → serveur accessible?
    | 4. curl /api/language → langue?
    | 5. browser_snapshot → Playwright disponible?
    | 6. curl /api/settings/exec-mode → mode + payment?
    | 7. cat ~/.claude/settings.json → teams?
    v
Tableau de diagnostic avec icones de statut
```

---

## Agents (points d'entree principaux)

### test-creator

| Propriete | Valeur |
|-----------|--------|
| Fichier | `agents/test-creator.md` |
| Modele | Opus |
| Max turns | 25 |
| Tools | Read, Write, Glob, Grep, Bash |
| Skills | preflight, create-test, create-payment |
| Invocation | `@test-creator` |

**Role:** Analyser un projet en profondeur et creer des tests QA complets.

L'agent scanne toujours le projet fresh (pas de cache `.aitestlist/project-analysis.md`).
Il detecte le stack, l'architecture, l'auth, les services externes, et genere
des tests adaptes dans la langue de l'utilisateur.

---

### test-executor

| Propriete | Valeur |
|-----------|--------|
| Fichier | `agents/test-executor.md` |
| Modele | Opus |
| Tools | Bash, Read, Task, SendMessage, tous MCP Playwright |
| Skills | preflight, exec-test, exec-payment, exec-email, exec-db-elevation, report-live |
| Invocation | `@test-executor` |

**Role:** Executer une queue de tests approuvee via MCP Playwright.

Supporte deux modes:
- **Sequentiel:** execute tout directement, reporte live
- **Teams:** spawne test-reporter + N exec agents en parallele

---

### test-reporter

| Propriete | Valeur |
|-----------|--------|
| Fichier | `agents/test-reporter.md` |
| Modele | Sonnet |
| Tools | Bash, Read, SendMessage |
| Skills | preflight, report-live, error-report |
| Invocation | `@test-reporter` ou spawne par test-executor en mode teams |

**Deux modes d'utilisation:**
1. **Invocation directe:** genere un rapport d'erreurs PDF sur un projet
2. **Mode teams:** hub de reporting — recoit les resultats des exec agents,
   pousse live au serveur, genere le rapport final

Sonnet car le travail est simple: recevoir, poster, compter, analyser.

---

## Skills (instructions prechargees)

Tous les skills sauf `status` sont `user-invocable: false`.
Ils ne sont pas visibles dans le menu `/`.
Leurs instructions sont prechargees dans les agents via le champ `skills:`.

### status

| Fichier | `skills/status/SKILL.md` |
|---------|--------------------------|
| Visible dans menu `/` | Oui (`disable-model-invocation: true`) |
| Prechage dans | Aucun agent (skill autonome) |

Diagnostic complet: URL, token, API, langue, Playwright, exec-mode, payment, teams.
Auth inline (ne depend pas de preflight).

---

### preflight

| Fichier | `skills/preflight/SKILL.md` |
|---------|------------------------------|
| Visible dans menu `/` | Non |
| Prechage dans | test-creator, test-executor, test-reporter |

Centralise: resolution URL (`$AITESTLIST_URL` ou defaut `http://localhost:8001`),
validation token (`GET /api/status`), detection langue (`GET /api/language`).

Variables produites: `URL`, `AITESTLIST_TOKEN` (valide), `USER_LANG`.

---

### create-test

| Fichier | `skills/create-test/SKILL.md` |
|---------|--------------------------------|
| Visible dans menu `/` | Non |
| Prechage dans | test-creator |

Generation et soumission de tests QA. Categories recuperees via API (jamais hardcodees).
Emails via `[CREATE_TEST_EMAIL:{context}]`. Ordre: SETUP → tests → TEARDOWN.

---

### create-payment

| Fichier | `skills/create-payment/SKILL.md` |
|---------|-----------------------------------|
| Visible dans menu `/` | Non |
| Prechage dans | test-creator |

Tests de paiement Stripe/PayPal. Detecte les providers dans le code.
Cartes test (4242...), scenarios: checkout, upgrade, downgrade, decline.
Marqueur `[PAYMENT_TEST]` dans chaque description.

---

### exec-test

| Fichier | `skills/exec-test/SKILL.md` |
|---------|------------------------------|
| Visible dans menu `/` | Non |
| Prechage dans | test-executor |

Execution via MCP Playwright. 4 modes: batch, headless, browser 1280x720, fullscreen.
Download queue, lire rules, executer, reporter live, finaliser.

---

### exec-payment

| Fichier | `skills/exec-payment/SKILL.md` |
|---------|---------------------------------|
| Visible dans menu `/` | Non |
| Prechage dans | test-executor |

Verifie toggle `payment_testing.enabled`. Refuse si cles live detectees.
Gere iframes Stripe Elements et Stripe Checkout. Cartes test.

---

### exec-email

| Fichier | `skills/exec-email/SKILL.md` |
|---------|-------------------------------|
| Visible dans menu `/` | Non |
| Prechage dans | test-executor |

Aliases email via API AITestList → Zoho. Convention: `claude.{role}_queue{id}@aitestlist.com`.
Cycle: creer → utiliser → attendre → lire → nettoyer.

---

### exec-db-elevation

| Fichier | `skills/exec-db-elevation/SKILL.md` |
|---------|--------------------------------------|
| Visible dans menu `/` | Non |
| Prechage dans | test-executor |

Elevation temporaire de permissions BD quand une tache echoue par restriction plan/role.
Lit etat → eleve → re-teste → restaure. Supporte MySQL, PostgreSQL, SQLite, SQL Server, MongoDB.

---

### report-live

| Fichier | `skills/report-live/SKILL.md` |
|---------|--------------------------------|
| Visible dans menu `/` | Non |
| Prechage dans | test-executor, test-reporter |

Push un resultat individuel via `POST /api/execution-queue/{id}/result`.
1er appel cree le Run. Retry 1x si timeout.

---

### error-report

| Fichier | `skills/error-report/SKILL.md` |
|---------|---------------------------------|
| Visible dans menu `/` | Non |
| Prechage dans | test-reporter |

Analyse taches echouees. Diagnostic: error, cause, 3 solutions actionnables.
Envoie au serveur qui genere le PDF.

---

### Document generation skills (pdf, docx, xlsx, pptx)

4 skills utilitaires pour la generation de documents. Non precharges dans les agents actuellement
(trop volumineux). Disponibles pour usage futur: rapports custom, exports client, etc.

| Skill | Fichier | Contenu |
|-------|---------|---------|
| pdf | `skills/pdf/SKILL.md` | pypdf, pdfplumber, reportlab + 8 scripts (forms, OCR) |
| docx | `skills/docx/SKILL.md` | docx-js, XML editing + office toolkit (pack/unpack/validate) |
| xlsx | `skills/xlsx/SKILL.md` | openpyxl, pandas + office toolkit + recalc.py |
| pptx | `skills/pptx/SKILL.md` | pptxgenjs, editing + office toolkit + thumbnail.py |

Chaque skill inclut ses propres `scripts/` et `LICENSE.txt`.
Aucun n'est visible dans le menu `/` (`user-invocable: false`).

---

## API AITestList utilisee

### Authentification

Header `Authorization: Bearer $AITESTLIST_TOKEN` sur chaque requete.
Decorateur `@require_api_token` cote serveur valide en BD.

### Endpoints

| Methode | Endpoint | Usage |
|---------|----------|-------|
| GET | `/api/status` | Verification connexion + token |
| GET | `/api/language` | Langue de l'utilisateur |
| GET | `/api/categories` | Categories hierarchiques |
| GET | `/api/projects` | Liste des projets |
| POST | `/api/tests/submit` | Soumettre un test |
| GET | `/api/settings/exec-mode` | Mode d'execution + config payment |
| GET | `/api/execution-queue/{id}/download` | Telecharger queue + taches + rules |
| GET | `/api/execution-queue/{id}/status` | Statut queue + progression run |
| POST | `/api/execution-queue/{id}/result` | Push un resultat (live) |
| POST | `/api/execution-queue/{id}/results` | Push resultats (batch) |
| POST | `/api/execution-queue/{id}/finalize` | Marquer execution terminee |
| GET | `/api/projects/{id}/failed-tasks` | Taches echouees d'un projet |
| POST | `/api/reports/error-analysis` | Envoyer diagnostics pour PDF |
| POST | `/api/email-testing/aliases` | Creer alias email |
| POST | `/api/email-testing/aliases/{alias}/wait` | Attendre reception email |
| GET | `/api/email-testing/emails/{id}` | Lire contenu email |
| DELETE | `/api/email-testing/aliases/{alias}` | Supprimer alias |

### Cycle de vie d'une queue

```
draft → pending → approved → running → executed
                                ^           ^
                                |           |
                          1er POST /result   POST /finalize
```

---

## Modes d'execution

### Sequentiel vs Teams

| Aspect | Sequentiel | Teams |
|--------|-----------|-------|
| Activation | Par defaut | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| Agents | test-executor seul | test-executor + test-reporter + N exec agents |
| Parallelisme | Non | Oui (tests divises en batches) |
| Reporting | test-executor → API direct | exec-agents → reporter → API |

### Modes Playwright

| Mode | Headless | Resolution | Usage |
|------|----------|-----------|-------|
| `batch` | Oui | N/A | CI/CD, `claude -p` |
| `interactive_headless` | Oui | N/A | Terminal sans browser |
| `interactive_browser_minimal` | Non | 1280x720 | Defaut |
| `interactive_browser_fullscreen` | Non | Maximisee | Tests visuels |

Configure dans AITestList > Settings > Execution.

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

### Configuration post-installation

```bash
# Token (obligatoire)
export AITESTLIST_TOKEN=at_xxxxxxxxxxxxx

# URL custom (optionnel, defaut: http://localhost:8001)
export AITESTLIST_URL=https://aitestlist.com

# MCP Playwright (requis pour @test-executor)
/mcp add playwright
```

---

> Derniere mise a jour: 2026-02-15
