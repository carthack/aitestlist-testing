---
name: exec-db-elevation
description: Eleve les permissions d'un utilisateur de test dans la base de donnees du projet quand une tache echoue a cause d'une restriction de plan/role. Restaure l'etat original apres le re-test.
---

# Execute DB Permission Elevation

Skill specialise pour l'elevation temporaire de permissions en base de donnees.
Appele par le skill core `exec-test` quand une tache echoue a cause d'une restriction
de plan ou de role (redirect vers /pricing, "upgrade your plan", "access denied", etc.).

## Prerequis

La reponse de download de la queue doit contenir `database_config` (non null).
Si `database_config` est null, ce skill ne peut pas etre utilise — retourner echec.

## Workflow

### 1. Lire l'etat actuel du user de test

```bash
py -c "
import mysql.connector
conn = mysql.connector.connect(host='HOST', user='USER', password='PASS', database='DB')
cursor = conn.cursor(dictionary=True)
cursor.execute('SELECT * FROM users WHERE email = %s', ('TEST_EMAIL',))
print(cursor.fetchone())
conn.close()
"
```

### 2. Identifier le champ a modifier

Champs courants: `role`, `plan`, `is_admin`, `subscription_tier`, `account_type`

### 3. Elever les permissions

```bash
py -c "
import mysql.connector
conn = mysql.connector.connect(host='HOST', user='USER', password='PASS', database='DB')
cursor = conn.cursor()
cursor.execute('UPDATE users SET role = %s WHERE email = %s', ('admin', 'TEST_EMAIL'))
conn.commit()
conn.close()
"
```

### 4. Re-tester la tache via Playwright

Retourner au contexte d'execution et re-executer la meme tache.

### 5. Restaurer l'etat original

```bash
py -c "
import mysql.connector
conn = mysql.connector.connect(host='HOST', user='USER', password='PASS', database='DB')
cursor = conn.cursor()
cursor.execute('UPDATE users SET role = %s WHERE email = %s', ('free', 'TEST_EMAIL'))
conn.commit()
conn.close()
"
```

### 6. Reporter

Status "succes", comment "Permission elevated: changed role from 'free' to 'admin'"

## Multi-driver BD

Adapter la commande au type de base de donnees:

| Type | Module Python | Connection |
|------|--------------|------------|
| MySQL/MariaDB | `mysql.connector` | `mysql.connector.connect(host, user, password, database)` |
| PostgreSQL | `psycopg2` | `psycopg2.connect(host, user, password, dbname)` |
| SQLite | `sqlite3` | `sqlite3.connect('path/to/db.sqlite')` |
| SQL Server | `pyodbc` | `pyodbc.connect('DRIVER={SQL Server};SERVER=...;DATABASE=...')` |
| MongoDB | `pymongo` | `MongoClient('mongodb://host:27017').db` |

Si le driver n'est pas installe, l'installer: `pip install psycopg2-binary`

## Securite

- Toujours noter l'etat AVANT modification
- Toujours restaurer l'etat APRES le re-test
- Ne modifier que le user de test, jamais d'autres comptes
- Logger chaque modification dans le commentaire de la tache
