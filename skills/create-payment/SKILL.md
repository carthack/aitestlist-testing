---
name: create-payment
description: Genere des taches de test pour les systemes de paiement (Stripe, PayPal). Detecte automatiquement les providers et cree des scenarios de test billing. Appele par create-test quand un systeme de paiement est detecte.
user-invocable: false
---

# Create Payment Tests

Skill specialise pour la creation de tests de paiement Stripe et PayPal.
Appele par le skill core `create-test` quand un systeme de paiement est detecte dans le projet.

## Detection de systemes de paiement

Lors de l'analyse du projet, detecter les systemes de paiement:

**Indicateurs Stripe:**
- `import stripe` ou `stripe.` dans le code Python/JS
- Routes `/pricing`, `/billing`, `/checkout`, `/subscribe`
- Templates avec `stripe-elements`, `card-element`, `stripe.js`

**Indicateurs PayPal:**
- `paypalrestsdk` ou `paypal` dans le code Python
- SDK PayPal JS (`paypal-js`, `paypal.Buttons`)
- Routes contenant `paypal`

## Donnees de test payment

| Type | Pattern | Usage |
|------|---------|-------|
| Carte succes | 4242 4242 4242 4242 | Visa test - paiement reussi |
| Carte decline | 4000 0000 0000 0002 | Carte refusee |
| Carte 3D Secure | 4000 0025 0000 3155 | Requiert authentification 3DS |
| Carte fonds insuffisants | 4000 0000 0000 9995 | Insufficient funds |
| Expiry | MM/AA futur | 12/30 |
| CVC | 3 chiffres | 123 |
| ZIP/Postal | 5 chiffres | 12345 |

## Scenarios de test a generer

Quand un systeme de paiement est detecte, generer un test dedie "Payment/Billing test"
avec les scenarios suivants. **Toutes les taches payment doivent inclure le marqueur
`[PAYMENT_TEST]` au debut de la description** pour que exec-test verifie le toggle
avant execution.

1. `[SETUP]` Creer un compte via [CREATE_TEST_EMAIL:billing_test] + se connecter
2. Verifier la page pricing - plans affiches, prix corrects, boutons CTA
3. Checkout Stripe avec carte test 4242 - completer le paiement
4. Verifier la souscription active dans le profil/billing apres paiement
5. Upgrade de plan - verifier la proration et le changement
6. Downgrade de plan - verifier le credit et le changement
7. Annulation de souscription - verifier la confirmation et le statut
8. Checkout avec carte decline (4000 0000 0000 0002) - verifier le message d'erreur
9. (Si PayPal detecte) Checkout PayPal sandbox - completer le flow
10. `[TEARDOWN]` Annuler toute souscription active + supprimer le compte de test

## Format de description pour les taches payment

```
[PAYMENT_TEST]
Preconditions: Connecte avec [CREATE_TEST_EMAIL:billing_test]
Steps:
1. Go to /pricing
2. Click "Subscribe" on Pro plan
3. Fill card: 4242 4242 4242 4242, Exp: 12/30, CVC: 123
4. Submit payment
Expected: Payment succeeds, redirect to success page, subscription active
```

## Exemple complet (lang=en)

```json
{
  "name": "Payment and billing test",
  "tasks": [
    {
      "title": "[SETUP] Register billing test account",
      "category": "Behavioral > Functionality > Workflow",
      "description": "Preconditions: None\nSteps:\n1. Go to registration page\n2. Use email: [CREATE_TEST_EMAIL:billing_test]\n3. Fill name: Billing Test User\n4. Fill password: TestBilling123!\n5. Submit\nExpected: Account created"
    },
    {
      "title": "Verify pricing page displays plans correctly",
      "category": "Behavioral > Functionality > Display",
      "description": "[PAYMENT_TEST]\nPreconditions: Logged in with [CREATE_TEST_EMAIL:billing_test]\nSteps:\n1. Navigate to /pricing\n2. Check all plans are displayed with prices\n3. Verify CTA buttons are visible and clickable\nExpected: All plans visible with correct prices"
    },
    {
      "title": "Complete Stripe checkout with test card",
      "category": "Behavioral > Functionality > Workflow",
      "description": "[PAYMENT_TEST]\nPreconditions: Logged in with [CREATE_TEST_EMAIL:billing_test]\nSteps:\n1. Go to /pricing\n2. Click Subscribe on Pro plan\n3. Fill card: 4242 4242 4242 4242\n4. Exp: 12/30, CVC: 123\n5. Submit payment\nExpected: Payment succeeds, redirect to success page"
    },
    {
      "title": "Verify subscription is active after payment",
      "category": "Behavioral > Functionality > Display",
      "description": "[PAYMENT_TEST]\nPreconditions: Payment completed\nSteps:\n1. Navigate to account/billing page\n2. Check subscription status\n3. Verify plan name matches selected plan\nExpected: Subscription shows as active with correct plan"
    },
    {
      "title": "Checkout with declined card shows error",
      "category": "Technical > Security > Authentication",
      "description": "[PAYMENT_TEST]\nPreconditions: Logged in with [CREATE_TEST_EMAIL:billing_test]\nSteps:\n1. Go to /pricing\n2. Click Subscribe on a plan\n3. Fill card: 4000 0000 0000 0002\n4. Exp: 12/30, CVC: 123\n5. Submit payment\nExpected: Error message displayed, no subscription created"
    },
    {
      "title": "[TEARDOWN] Cancel subscription and clean up",
      "category": "Behavioral > Functionality > Workflow",
      "description": "[PAYMENT_TEST]\nPreconditions: Logged in\nSteps:\n1. Cancel any active subscription\n2. Delete test account if possible\n3. Verify no billing artifacts remain\nExpected: All test data cleaned up"
    }
  ]
}
```

## Integration avec create-test

Ce skill est appele par `create-test` (etape 5 - Detecter les specialites).
Il retourne une liste de taches a ajouter au test principal ou comme test separe.
Les categories doivent utiliser celles recuperees par create-test (etape 3).
