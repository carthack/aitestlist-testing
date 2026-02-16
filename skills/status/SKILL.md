---
name: status
description: Verifie l'etat de la connexion AITestList, du token API, de MCP Playwright, et de la configuration d'execution. Affiche un tableau de diagnostic.
argument-hint:
disable-model-invocation: true
---

# Status Check

Diagnostic complet de la connexion AITestList et des dependances.

## Etape 1: Resoudre l'URL

```bash
echo ${AITESTLIST_URL:-http://localhost:8001}
```

Variable interne: `URL` = valeur retournee

## Etape 2: Verifier le token

```bash
echo $AITESTLIST_TOKEN
```

Si vide: marquer Token = FAIL

## Etape 3: Tester la connexion API

```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "${URL}/api/status"
```

- Reponse `{"status": "connected"}` → API = OK
- 401 → Token invalide
- Timeout/connection refused → Serveur inaccessible

## Etape 4: Detecter la langue

```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "${URL}/api/language"
```

Retourne `fr` ou `en`.

## Etape 5: Verifier MCP Playwright

Tenter un appel `browser_snapshot()` ou `browser_navigate` simple.

- Disponible → Playwright = OK
- Erreur → Playwright = MISSING ("Installez avec: /mcp add playwright")

## Etape 6: Mode d'execution et payment config

```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "${URL}/api/settings/exec-mode"
```

Afficher: exec_mode, payment_testing (enabled/disabled, stripe_mode, paypal_mode)

## Etape 7: Mode teams

```bash
cat ~/.claude/settings.json 2>/dev/null
```

Chercher `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` dans la cle `env`.

## Affichage

Afficher un tableau de diagnostic:

```
=== AI TestList Status ===

| Component       | Status | Detail                          |
|-----------------|--------|---------------------------------|
| URL             | OK     | http://localhost:8001            |
| Token           | OK     | at_xxxx...xxxx (defined)         |
| API             | OK     | Connected                        |
| Language        | OK     | fr                               |
| Playwright      | OK     | Available                        |
| Exec Mode       | OK     | interactive_browser_minimal      |
| Payment Testing | OFF    | Not enabled                      |
| Teams Mode      | OFF    | Not configured                   |
```

Utiliser des icones de statut:
- OK = vert
- FAIL/MISSING = rouge
- OFF = gris (pas une erreur, juste desactive)
