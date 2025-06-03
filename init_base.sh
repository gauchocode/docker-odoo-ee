#!/bin/bash
set -e
source .env

echo "� Ejecutando Odoo temporal con -i base para crear estructura inicial..."

docker compose run --rm --entrypoint "" odoo \
    odoo --config=/var/lib/odoo/odoo.conf \
          -i base \
          -d "$PG_DB" \
          --stop-after-init \
          --db_host="postgres" \
          --db_port=5432 \
          --db_user="$PG_USER" \
          --db_password="$PG_PASSWORD"

