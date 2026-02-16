---
name: preflight
description: Verification prealable centralisee pour tous les skills aitestlist-testing. Valide le token API, detecte la langue utilisateur, et resout l'URL du serveur. Doit etre appele en premiere etape par tous les autres skills.
---

# Preflight

Verification prealable centralisee. Tous les skills du plugin appellent ce skill
en premiere etape pour eviter la duplication du code d'authentification.

## Ce que ce skill fait

1. Resoudre l'URL du serveur AITestList
2. Verifier que le token API est defini
3. Valider le token contre le serveur
4. Detecter la langue de l'utilisateur

## Etape 1: Resoudre l'URL du serveur

```bash
echo ${AITESTLIST_URL:-http://localhost:8001}
```

Variable interne: `URL` = valeur retournee

**Priorite:**
1. Variable d'environnement `$AITESTLIST_URL` si definie
2. Sinon: `http://localhost:8001` par defaut

## Etape 2: Verifier le token

```bash
echo $AITESTLIST_TOKEN
```

Si vide ou non defini:
- Informer: "Token API non defini. Configurez-le avec: `export AITESTLIST_TOKEN=<votre_token>`"
- Indiquer: "Vous pouvez generer un token dans AITestList > Settings > Integration"
- **STOP** - ne pas continuer

## Etape 3: Valider le token contre le serveur

```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "${URL}/api/status"
```

**Reponses possibles:**
- `{"status": "ok", ...}` → Token valide, continuer
- `401` ou `{"error": "..."}` → Token invalide: "Token refuse par le serveur. Verifiez-le dans Settings > Integration."
- Timeout / connection refused → "Serveur AITestList non accessible a ${URL}. Verifiez qu'il est demarre."

Si erreur: **STOP** - ne pas continuer.

## Etape 4: Detecter la langue

```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" "${URL}/api/language"
```

Variable interne: `USER_LANG` = valeur retournee (`fr` ou `en`, defaut `fr` si erreur)

## Resultat

Apres execution, les variables suivantes sont disponibles pour le skill appelant:

| Variable | Exemple | Description |
|----------|---------|-------------|
| `URL` | `http://localhost:8001` | URL du serveur AITestList |
| `AITESTLIST_TOKEN` | `at_xxxx...` | Token API valide |
| `USER_LANG` | `fr` | Langue de l'utilisateur |

## Usage par les autres skills

Chaque skill du plugin doit commencer par:

```
Etape 1: Appeler /aitestlist-testing:preflight
```

Puis utiliser `${URL}` et `${USER_LANG}` dans toutes les requetes suivantes.
