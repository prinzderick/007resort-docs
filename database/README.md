# Database design notes

`schema-draft-v0.sql` is a **design-review draft**, not a migration. It exists to validate the shape of the highest-risk tables described in [`architecture/04-database-schema.md`](../architecture/04-database-schema.md) before the first real migration is written in `otueke-api/db/migrations/`.

Once that first migration lands, `otueke-api` becomes the single authoritative owner of the schema (per the client specification and [ADR-0003](../adr/0003-identifier-and-money-conventions.md) / [ADR-0004](../adr/0004-schema-migrations-and-data-access.md)), and this draft is kept only as historical design context — it is not applied to any real environment and must not drift into being treated as a second schema owner.

To try it locally against the dev MySQL 8.4 container in `otueke-infrastructure`:

```bash
mysql -h 127.0.0.1 -P 3306 -u root -p otueke_dev < schema-draft-v0.sql
```
