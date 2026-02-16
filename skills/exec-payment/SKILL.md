---
name: exec-payment
description: Execute les taches de test payment (Stripe Elements, Stripe Checkout, PayPal sandbox). Verifie le toggle payment testing avant execution. Appele par exec-test quand une tache contient [PAYMENT_TEST].
user-invocable: false
---

# Execute Payment Tests

Skill specialise pour l'execution de tests de paiement via Playwright.
Appele par le skill core `exec-test` quand une tache contient `[PAYMENT_TEST]` dans sa description.

## Verification AVANT execution

L'API `/api/settings/exec-mode` retourne la config payment testing:
```json
{
  "exec_mode": "...",
  "payment_testing": {
    "enabled": false,
    "stripe_mode": "test",
    "paypal_mode": "sandbox"
  }
}
```

**Regles:**
- Si `payment_testing.enabled` est `false`: retourner status `echec` avec commentaire
  "Payment testing disabled in Settings > Execution. Enable it to run this test."
- Si `stripe_mode` est `live` ou `paypal_mode` est `live`: retourner status `erreur` avec
  commentaire "SAFETY: Live payment keys detected. Cannot execute payment tests."
- Si tout est OK (enabled + test/sandbox): executer normalement

## Cartes test Stripe

| Carte | Usage |
|-------|-------|
| `4242 4242 4242 4242` | Paiement reussi (Visa) |
| `4000 0000 0000 0002` | Carte declinee |
| `4000 0025 0000 3155` | Requiert 3D Secure |
| `4000 0000 0000 9995` | Fonds insuffisants |

- Expiry: toute date future (ex: `12/30`)
- CVC: tout nombre a 3 chiffres (ex: `123`)

## Interagir avec Stripe Elements (iframe)

Stripe Elements utilise des iframes pour les champs de carte. Pour remplir:

1. Trouver l'iframe Stripe:
   ```
   page.frameLocator('iframe[name*="__privateStripeFrame"]')
   ```
   ou `iframe[title*="Secure card"]`

2. Dans l'iframe, remplir les champs:
   - Numero: `input[name="cardnumber"]`
   - Expiry: `input[name="exp-date"]`
   - CVC: `input[name="cvc"]`

3. Revenir au contexte principal pour cliquer sur le bouton Submit

**Note:** Chaque champ Stripe peut etre dans son propre iframe.
Utiliser `browser_snapshot()` pour identifier les iframes disponibles.

## Stripe Checkout (page Stripe hebergee)

Si le client utilise Stripe Checkout (redirection vers checkout.stripe.com):
1. La page redirige vers `checkout.stripe.com`
2. Remplir directement les champs sur la page Stripe
3. Le numero de carte test fonctionne en mode test

## PayPal sandbox

Si le client utilise PayPal:
1. Un popup ou redirect vers `sandbox.paypal.com` s'ouvre
2. Utiliser les identifiants sandbox PayPal fournis dans la description de la tache
3. Completer le flow d'approbation PayPal

## SECURITE - NE JAMAIS

- Utiliser de vraies cartes de credit
- Executer des tests payment si les cles sont en mode live
- Continuer si le toggle payment testing est desactive
- Stocker des numeros de carte en clair dans les logs ou commentaires

## Retour au skill exec-test

Apres execution, retourner au core exec-test:
- `status`: succes / echec / erreur
- `comment`: description du resultat (dans USER_LANG)
- `duration_ms`: temps d'execution
