# Plan Refactor V2 - Simplification agents/skills

> Date: 2026-02-15
> Branche: feature/refactor-agents-skills

## Contexte

Le plugin a des commands legacy, des agents orphelins jamais appeles, et des skills
qui appellent d'autres skills (pattern fragile, issue #17351). On simplifie tout.

## Principe

- 4 points d'entree seulement
- Les agents prechargent les skills via le champ `skills:` dans leur frontmatter
- Les skills ne s'appellent jamais entre eux
- Les commands sont supprimees (legacy)
- Un seul skill user-invocable: status

## Architecture cible

```
Points d'entree utilisateur:
  /aitestlist-plugin:status     →  skill status (seul visible)
  @test-creator                  →  agent (analyse projet + creation tests)
  @test-executor                 →  agent (execution tests via Playwright)
  @test-reporter                 →  agent (rapport d'erreurs PDF)
```

## Etapes

### Etape 1 - Supprimer commands/

Supprimer les 4 fichiers:
- commands/create.md
- commands/exec.md
- commands/report.md
- commands/status.md

Supprimer le dossier commands/

### Etape 2 - Creer le skill status

Creer `skills/status/SKILL.md` avec:
- Frontmatter: `disable-model-invocation: true` (invocable manuellement seulement)
- Auth inline (pas d'appel a preflight)
- Resout URL via $AITESTLIST_URL ou defaut localhost:8001
- 7 checks: URL, token, API status, langue, Playwright, exec-mode, teams mode
- Affiche tableau de statut

### Etape 3 - Marquer tous les skills comme non user-invocable

Ajouter `user-invocable: false` dans le frontmatter de:
- skills/preflight/SKILL.md
- skills/create-test/SKILL.md
- skills/create-payment/SKILL.md
- skills/exec-test/SKILL.md
- skills/exec-payment/SKILL.md
- skills/exec-email/SKILL.md
- skills/exec-db-elevation/SKILL.md
- skills/report-live/SKILL.md
- skills/error-report/SKILL.md

### Etape 4 - Modifier les agents pour precharger les skills

**agents/test-creator.md:**
- Ajouter `skills:` field avec: preflight, create-test, create-payment
- Retirer la reference a "appeler /aitestlist-plugin:create-test"
- Retirer la reference a .aitestlist/project-analysis.md (on scan fresh a chaque fois)
- L'agent fait: scan projet → genere tests → soumet via API (tout inline)

**agents/test-executor.md:**
- Ajouter `skills:` field avec: preflight, exec-test, exec-payment, exec-email, exec-db-elevation, report-live
- Retirer la reference a "appeler /aitestlist-plugin:exec-test"
- En mode sequentiel: l'agent execute tout directement
- En mode teams: spawne test-reporter + exec agents en parallele

**agents/test-reporter.md:**
- Ajouter `skills:` field avec: preflight, report-live, error-report
- Role inchange: hub de reporting en mode teams + analyse post-mortem

### Etape 5 - Nettoyer les skills

Dans chaque skill qui dit "Appeler /aitestlist-plugin:preflight en premiere etape":
- Retirer cette instruction
- Remplacer par un commentaire: "Variables URL, AITESTLIST_TOKEN, USER_LANG disponibles via preflight prechage dans l'agent"
- Les skills deviennent des "instructions pures" sans logique d'appel

Skills a modifier:
- skills/create-test/SKILL.md (retirer etape preflight + retirer ref project-analysis.md)
- skills/exec-test/SKILL.md (retirer etape preflight)
- skills/error-report/SKILL.md (retirer etape preflight)

### Etape 6 - Nettoyer marketplace.json

Retirer la liste explicite de skills (auto-discovery suffit):
```json
// AVANT
"skills": ["./skills/preflight", "./skills/create-test", ...]

// APRES
(pas de champ skills, auto-discovery du dossier skills/)
```

### Etape 7 - Mettre a jour docs/ARCHITECTURE.md

Mettre a jour la documentation pour refleter:
- Suppression des commands
- Nouveau flow via agents
- Skills precharges dans les agents
- 4 points d'entree

## Fichiers touches (resume)

| Action | Fichier |
|--------|---------|
| SUPPRIMER | commands/create.md |
| SUPPRIMER | commands/exec.md |
| SUPPRIMER | commands/report.md |
| SUPPRIMER | commands/status.md |
| CREER | skills/status/SKILL.md |
| MODIFIER | skills/preflight/SKILL.md (user-invocable: false) |
| MODIFIER | skills/create-test/SKILL.md (user-invocable: false, retirer preflight call, retirer project-analysis) |
| MODIFIER | skills/create-payment/SKILL.md (user-invocable: false) |
| MODIFIER | skills/exec-test/SKILL.md (user-invocable: false, retirer preflight call) |
| MODIFIER | skills/exec-payment/SKILL.md (user-invocable: false) |
| MODIFIER | skills/exec-email/SKILL.md (user-invocable: false) |
| MODIFIER | skills/exec-db-elevation/SKILL.md (user-invocable: false) |
| MODIFIER | skills/report-live/SKILL.md (user-invocable: false) |
| MODIFIER | skills/error-report/SKILL.md (user-invocable: false, retirer preflight call) |
| MODIFIER | agents/test-creator.md (skills: field, retirer project-analysis) |
| MODIFIER | agents/test-executor.md (skills: field) |
| MODIFIER | agents/test-reporter.md (skills: field) |
| MODIFIER | .claude-plugin/marketplace.json (retirer liste skills explicite) |
| MODIFIER | docs/ARCHITECTURE.md (mettre a jour) |

## Verification

1. `commands/` n'existe plus
2. `/aitestlist-plugin:status` fonctionne (seul skill visible dans le menu)
3. `@test-creator` est invocable et a les instructions preflight + create-test dans son contexte
4. `@test-executor` est invocable et a les instructions preflight + exec-test + report-live dans son contexte
5. `@test-reporter` est invocable et a les instructions preflight + report-live + error-report dans son contexte
6. Aucun skill n'appelle un autre skill
7. Aucun skill n'est visible dans le menu / sauf status
8. Aucune URL hardcodee en dehors de preflight et status
