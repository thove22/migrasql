# migrasql

**Minimalist raw-SQL migration manager for MariaDB/MySQL, built for team collaboration.**

Written in pure Bash. Version your database with Git, the same way you version your code.

---

## The problem this solves

Imagine you and three classmates are building a project with a shared database.
One person adds a table. How do the others get that table?

The usual answer is painful. Someone exports the whole database to a `.sql`
dump, sends it over WhatsApp, and everyone else imports it, overwriting their
own data in the process. Do this ten times during a project and you get lost
dumps, "which version is the latest?" confusion, and people accidentally
erasing each other's work.

migrasql replaces that mess with something Git already does well: small,
ordered, versioned changes. Instead of passing around one giant dump, each
change to the database becomes a tiny `.sql` file committed to your repository.
Your teammates run `git pull`, run one command, and their database catches up
without losing anything.

## What is a "migration"?

A **migration** is a single file describing one change to your database.
For example, "create the `clients` table" is one migration. "Add a `phone`
column to `clients`" is another. Each is a plain `.sql` file with the SQL
commands to make that change.

You never edit the database by hand. Instead you write migrations, and migrasql
applies them **in order**, keeping track of which ones each database has already
seen. Think of it like a stack of numbered instructions: migrasql knows your
database is on instruction #5, so when you add #6 and #7, it applies only those
two, never repeating #1 through #5.

That record of "what has been applied" lives in a small table called
`schema_migrations` that migrasql creates inside your database automatically.
It is the tool's memory.

## Why raw SQL?

Big migration tools (Flyway, Liquibase) make you learn their own formats, XML,
or a specific programming framework. migrasql does not. **You write plain SQL**,
the same `CREATE TABLE` and `INSERT` you already write. If you know SQL, you
already know how to use migrasql. That makes it ideal for students and small
teams who just want their databases in sync without learning a new ecosystem.

---

## Requirements

- A Linux system (any distribution) or WSL on Windows
- **Bash 4+** (already installed on virtually every Linux system)
- The **`mariadb`** or **`mysql`** command-line client
- A running MariaDB or MySQL server

migrasql finds the client automatically, even for XAMPP, snap, and manual
installs. If it cannot find one, it tells you the exact command to install it
for your distribution.

## Installation

```bash
git clone https://github.com/<your-user>/migrasql.git
cd migrasql
chmod +x bin/migrasql.sh
```

Then create your personal configuration from the template:

```bash
cp migrate.conf.example migrate.conf
```

Open `migrate.conf` and set at least the database name:

```bash
DB_NAME="my_project"
DB_USER="root"
```

That is all you need. `migrate.conf` is personal to you and is ignored by Git,
so your settings never overwrite a teammate's.

---

## Your first migration (a walkthrough)

**1. Check the current state.** Nothing has been applied yet:

```bash
./bin/migrasql.sh status
```

**2. Create a migration file.** This makes an empty, timestamped `.sql` file
inside the `migrations/` folder:

```bash
./bin/migrasql.sh new create_clients_table
```

**3. Write your SQL.** Open the file that was just created in `migrations/`
and add your change:

```sql
CREATE TABLE clients (
    id   INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);
```

**4. Apply it.** migrasql runs every pending migration in order:

```bash
./bin/migrasql.sh up
```

You will see `Applying 'create_clients_table'... OK`. Your table now exists.

**5. Share it.** Commit the file like any other code:

```bash
git add migrations/
git commit -m "feat(db): add clients table"
git push
```

Your teammates run `git pull` then `./bin/migrasql.sh up`, and they get the
exact same table. No dumps, no overwrites.

---

## Commands

| Command | What it does |
|---|---|
| `up` | Applies all pending migrations, in order. This is the default, so `./bin/migrasql.sh` on its own runs `up`. |
| `status` | Shows every migration and whether it is applied, pending, or was modified after being applied. |
| `new <name>` | Creates a new timestamped migration file in `migrations/`. Does not touch the database. |
| `help` | Shows the command list. |

---

## The rules (read these, they prevent real problems)

**One migration means one logical change.** Create one table, or add one column,
per file. Small files are easy to read, easy to review, and easy to fix if
something goes wrong.

**Never edit a migration after it has been applied.** Once a migration has run,
it is part of history. If you change the file afterwards, your database and the
file no longer match, and your teammates, who already applied the old version,
will never get your edit. migrasql detects this: `status` will flag the file as
`APPLIED BUT MODIFIED AFTERWARDS!`. If you need to change something, **create a
new migration** that alters it.

**Stored routines need `DELIMITER`.** A normal SQL statement ends with `;`.
But a `PROCEDURE`, `FUNCTION`, or `TRIGGER` contains its own `;` characters
inside its body, which confuses the client into thinking the statement ended
early. To fix this, wrap those migrations with `DELIMITER`:

```sql
DELIMITER //

CREATE PROCEDURE count_clients(OUT total INT)
BEGIN
    SELECT COUNT(*) INTO total FROM clients;
END//

DELIMITER ;
```

`DELIMITER //` tells the client that statements now end with `//` instead of
`;`, so the `;` inside the body is treated as ordinary code. `DELIMITER ;` at
the end resets it. Any migration creating a routine must use this pattern.

**If a migration fails, migrasql stops.** The run halts at the failing file and
shows you the real database error. The migration is not recorded, so once you
fix the file, just run `up` again and it resumes from where it stopped.

---

## Configuration reference

Set these in `migrate.conf`, or as environment variables (environment values
let you override for a single run).

| Variable | Default | Meaning |
|---|---|---|
| `DB_NAME` | *(required)* | The database to manage. Created automatically if it does not exist. |
| `DB_USER` | `root` | Database user. |
| `DB_HOST` | *(empty)* | Leave empty for a local connection via Unix socket. Set it for a remote server. |
| `DB_PORT` | *(empty)* | Database port, if not the default. |
| `DB_CLIENT` | *(auto)* | Full path to the `mariadb`/`mysql` binary. Only needed if auto-detection fails. |
| `MIGRATIONS_DIR` | `./migrations` | Where your `.sql` files live. |

migrasql detects how to authenticate automatically: a passwordless local socket
(common on Arch), `sudo` with the unix_socket plugin (common on Ubuntu, Debian,
Fedora), or an interactive password prompt. When it asks for a password, that
password is never shown on screen or exposed to other users on the machine.

---

## How it works, briefly

- Migrations are applied in **alphabetical order**, which is why the timestamp
  prefix (`20260827143012_name.sql`) matters. It keeps them in the order you
  created them and prevents collisions when two teammates add migrations on
  different branches.
- Each applied migration is recorded in `schema_migrations` with its name and a
  SHA-256 **checksum** of the file. The checksum is how `status` knows if a file
  changed after being applied.
- The `migrations/` directory and the `schema_migrations` table are the only two
  things migrasql needs. Everything else is your SQL.

---

## License

MIT. Free to use, modify, and share.
