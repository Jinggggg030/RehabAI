# Database migrations

These scripts are retained for upgrading older RehabAI databases. Run them
from the repository root with Python module syntax, for example:

```powershell
python -m backend.migrations.migrate_profile_picture
```

The current backend also performs its required additive schema checks during
startup. Do not run `legacy_destructive_migration.py` or
`recreate_chat_tables.py` against a database containing important data; those
utilities intentionally drop tables.
