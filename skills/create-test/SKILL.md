---
name: create-test
description: Cree et soumet des tests a AI TestList via l'API REST. Genere des taches de test intelligentes avec categories appropriees. Skill core du plugin aitestlist-testing.
user-invocable: false
---

# Create Test

Skill core pour creer et soumettre des tests a AI TestList.

## Variables disponibles

Ce skill est prechage dans l'agent test-creator via le champ `skills:`.
Les variables suivantes sont disponibles via preflight (egalement prechage):
- `URL` — URL du serveur AITestList
- `AITESTLIST_TOKEN` — Token API valide
- `USER_LANG` — Langue de l'utilisateur (fr/en)

## API REST

### Obtenir les categories
```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  "${URL}/api/categories?lang=${USER_LANG}"
```

### Obtenir les projets
```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  "${URL}/api/projects"
```

### Soumettre un test
```bash
curl -s -X POST "${URL}/api/tests/submit" \
  -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Nom du test",
    "tasks": [
      {"title": "Tache 1", "category": "Categorie", "description": "Description"},
      {"title": "Tache 2", "category": "Categorie", "description": "Description"}
    ],
    "project_id": 123
  }'
```

## Workflow

1. **Obtenir les categories** - `GET ${URL}/api/categories?lang=${USER_LANG}`
2. **Analyser le contexte** - Comprendre ce qui doit etre teste (scanner le projet)
3. **Detecter les specialites** - Si paiement detecte, suivre aussi les instructions create-payment (prechargees dans l'agent)
4. **Generer les taches** - Creer des taches **DANS LA LANGUE DE L'UTILISATEUR** (`USER_LANG`), PAS la langue de la conversation
5. **Soumettre** - `POST ${URL}/api/tests/submit`
6. **Confirmer** - Informer que le test est dans la queue d'import

**IMPORTANT:** Toujours generer dans la langue configuree dans AITestList (`USER_LANG` du preflight), independamment de la langue de la conversation:
- **Nom du test** - dans la langue de l'utilisateur
- **Titres des taches** - dans la langue de l'utilisateur
- **Descriptions des taches** - dans la langue de l'utilisateur
- **Categories** - utiliser les categories de l'etape 2 (deja dans la bonne langue)

## Format des taches

```json
{
  "title": "[TYPE] Action a verifier",
  "category": "Principale > Sous-categorie > Detail",
  "description": "Preconditions: ...\nSteps:\n1. ...\n2. ...\nExpected: ..."
}
```

**Types de taches:**
- `[SETUP]` - Preparation (creer user, data, etc.)
- `[TEST]` - Test principal (optionnel, implicite)
- `[VERIFY]` - Verification/assertion
- `[TEARDOWN]` - Nettoyage

## Categories

**NE PAS utiliser de categories hardcodees.** Toujours les recuperer de l'API avec la langue de l'utilisateur:

```bash
curl -s -H "Authorization: Bearer $AITESTLIST_TOKEN" \
  "${URL}/api/categories?lang=${USER_LANG}"
```

L'API retourne les categories dans la bonne langue:
- **Anglais (lang=en)**: `Technical > Security > Authentication`
- **Francais (lang=fr)**: `Techniques > Securite > Authentification`

Utiliser les chemins de categories exacts retournes par l'API.

## Donnees de test

| Type | Pattern | Exemple |
|------|---------|---------|
| Email | [CREATE_TEST_EMAIL:{context}] | [CREATE_TEST_EMAIL:inscription] |
| Password | Test{Context}123! | TestLogin123! |
| Username | testuser_{context}_{num} | testuser_login_001 |
| Phone | +1555000{4 digits} | +15550001234 |

### Emails de test - REGLE CRITIQUE

**Ne JAMAIS assumer qu'un compte utilisateur existe deja sur l'application du client.**
L'agent de test ne connait PAS l'application du client. Il n'y a PAS de compte pre-existant.

**Pour CHAQUE test qui necessite un compte connecte:**
1. La premiere tache doit etre un [SETUP] qui cree le compte via inscription
2. Utiliser `[CREATE_TEST_EMAIL:{context}]` pour generer un vrai email via Zoho
3. S'inscrire sur l'app du client avec cet email
4. Puis se connecter avec cet email pour les taches suivantes

**Le contexte sert a identifier le meme email a travers plusieurs taches:**
- Tache 1: `[CREATE_TEST_EMAIL:login_test]` -> s'inscrit avec cet email
- Tache 3: `[CREATE_TEST_EMAIL:login_test]` -> meme email, l'agent sait le reutiliser

**INTERDIT:**
- Ne JAMAIS utiliser d'adresses hardcodees (claude@test.com, admin@example.com, etc.)
- Ne JAMAIS inventer d'adresses (@testmail.com, @example.com, etc.)
- Ne JAMAIS ecrire "Connecte avec X" en precondition sans un [SETUP] qui cree ce compte d'abord

## Ordre des taches - CRITIQUE

Les taches DOIVENT etre en ordre logique d'execution. L'agent exec-test les execute
sequentiellement, de la premiere a la derniere. Une tache peut dependre du resultat
d'une tache precedente.

1. **[SETUP]** - Creer les prerequis (compte, donnees, etc.)
2. **Happy path** - Le flow normal fonctionne (connexion, navigation de base)
3. **Fonctionnalites** - Tester les fonctionnalites principales
4. **Validation** - Les entrees invalides sont rejetees
5. **Edge cases** - Conditions limites
6. **Erreurs** - Le systeme gere les echecs
7. **Securite** - Injections, XSS, permissions
8. **[TEARDOWN]** - Nettoyage de tout ce qui a ete cree

**IMPORTANT:** Ne jamais mettre une tache qui necessite d'etre connecte AVANT
le [SETUP] qui cree et connecte le compte.

## Regle TEARDOWN - OBLIGATOIRE

**Chaque test DOIT se terminer par UNE tache [TEARDOWN] finale** qui verifie et nettoie
tout ce qui a ete cree pendant le test (comptes, projets, donnees, etc.).

## Delegation aux skills specialises

Lors de l'analyse du projet (etape 4), si des systemes specialises sont detectes,
appeler les skills de creation correspondants:

| Detection | Skill a appeler |
|-----------|-----------------|
| Stripe / PayPal detecte | `/aitestlist-testing:create-payment` |
| (futur) Auth complexe | `/aitestlist-testing:create-security` |
| (futur) UI riche | `/aitestlist-testing:create-accessibility` |

Les skills specialises retournent des taches supplementaires a ajouter au test.

## Exemples complets

### Exemple anglais (lang=en)

```json
{
  "name": "Login page test",
  "tasks": [
    {
      "title": "[SETUP] Register a test account",
      "category": "Behavioral > Functionality > Workflow",
      "description": "Preconditions: None\nSteps:\n1. Go to the app registration page\n2. Use email: [CREATE_TEST_EMAIL:login_test]\n3. Fill name: Test User\n4. Fill password: TestLogin123!\n5. Confirm password: TestLogin123!\n6. Submit the form\nExpected: Account created successfully"
    },
    {
      "title": "Login with valid credentials",
      "category": "Technical > Security > Authentication",
      "description": "Preconditions: Account [CREATE_TEST_EMAIL:login_test] created in SETUP\nSteps:\n1. Go to the app login page\n2. Enter email: [CREATE_TEST_EMAIL:login_test]\n3. Enter password: TestLogin123!\n4. Click Login\nExpected: Redirect to dashboard, user name visible"
    },
    {
      "title": "Login with wrong password",
      "category": "Technical > Security > Authentication",
      "description": "Preconditions: None\nSteps:\n1. Go to the app login page\n2. Enter email: [CREATE_TEST_EMAIL:login_test]\n3. Enter password: WrongPassword999!\n4. Click Login\nExpected: Generic error message, stay on login page"
    },
    {
      "title": "[TEARDOWN] Clean up all test data",
      "category": "Behavioral > Functionality > Workflow",
      "description": "Preconditions: Logged in\nSteps:\n1. Delete any accounts created during this test\n2. Delete any projects or data created during this test\n3. Verify nothing test-related remains in the application\nExpected: All test artifacts removed, application in clean state"
    }
  ]
}
```

### Exemple francais (lang=fr)

```json
{
  "name": "Test page de connexion",
  "tasks": [
    {
      "title": "[SETUP] Inscrire un compte de test",
      "category": "Comportementales > Fonctionnalite > Workflow",
      "description": "Preconditions: Aucune\nEtapes:\n1. Aller sur la page d'inscription de l'app\n2. Utiliser email: [CREATE_TEST_EMAIL:login_test]\n3. Remplir nom: Utilisateur Test\n4. Remplir mot de passe: TestLogin123!\n5. Confirmer mot de passe: TestLogin123!\n6. Soumettre le formulaire\nAttendu: Compte cree avec succes"
    },
    {
      "title": "Connexion avec identifiants valides",
      "category": "Techniques > Securite > Authentification",
      "description": "Preconditions: Compte [CREATE_TEST_EMAIL:login_test] cree au SETUP\nEtapes:\n1. Aller sur la page de connexion de l'app\n2. Entrer email: [CREATE_TEST_EMAIL:login_test]\n3. Entrer mot de passe: TestLogin123!\n4. Cliquer Connexion\nAttendu: Redirection vers tableau de bord, nom visible"
    },
    {
      "title": "Connexion avec mauvais mot de passe",
      "category": "Techniques > Securite > Authentification",
      "description": "Preconditions: Aucune\nEtapes:\n1. Aller sur la page de connexion de l'app\n2. Entrer email: [CREATE_TEST_EMAIL:login_test]\n3. Entrer mot de passe: MauvaisPass999!\n4. Cliquer Connexion\nAttendu: Message d'erreur generique, reste sur la page de connexion"
    },
    {
      "title": "[TEARDOWN] Nettoyer toutes les donnees de test",
      "category": "Comportementales > Fonctionnalite > Workflow",
      "description": "Preconditions: Connecte\nEtapes:\n1. Supprimer les comptes crees pendant ce test\n2. Supprimer les projets ou donnees crees pendant ce test\n3. Verifier qu'il ne reste rien lie aux tests dans l'application\nAttendu: Tous les artefacts de test supprimes, application propre"
    }
  ]
}
```

## Apres soumission

Informer l'utilisateur:
1. Nombre de taches creees
2. Categories utilisees
3. Le test est dans la queue d'import: **${URL}/import-queue**
4. L'utilisateur doit approuver l'import pour creer le test
