import os
import sys

import pymysql

SCHEMA_PATH = os.environ.get("SCHEMA_PATH", "/app/schema.sql")


def main():
    ca = os.environ.get("DB_SSL_CA")
    conn = pymysql.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "3306")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ.get("DB_NAME", "clinicflow"),
        autocommit=True,
        connect_timeout=10,
        ssl={"ca": ca} if ca else None,
    )
    with open(SCHEMA_PATH, encoding="utf-8") as handle:
        statements = [s.strip() for s in handle.read().split(";") if s.strip()]
    with conn.cursor() as cur:
        for statement in statements:
            cur.execute(statement)
    conn.close()
    print(f"schema applied: {len(statements)} statements")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"init_db failed: {exc}", file=sys.stderr)
        sys.exit(1)
