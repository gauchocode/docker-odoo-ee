#!/bin/bash
set -e
source .env

MODULE=${1:-all}
PG_DB="${2:-$PG_DB}"
VERBOSE=false
LOGFILE="logs/update_module.log"
HOST="postgres"

# Manejar flag --verbose como segundo argumento
if [[ "$3" == "--verbose" ]]; then
    VERBOSE=true
fi

echo "� Ejecutando actualización de módulo: $MODULE dentro del contenedor de Odoo..."

if $VERBOSE; then
    echo "� Modo verbose activado. Log: $LOGFILE"
    mkdir -p logs
    docker compose exec -T odoo \
        odoo --config=/var/lib/odoo/odoo.conf \
              -u "$MODULE" \
              -d "$PG_DB" \
              --stop-after-init \
              --db_host="$HOST" \
              --db_port=5432 \
              --db_user="$PG_USER" \
              --db_password="$PG_PASSWORD" | tee "$LOGFILE"
else
    docker compose exec -T odoo \
        odoo --config=/var/lib/odoo/odoo.conf \
              -u "$MODULE" \
            -d "$PG_DB" \
              --stop-after-init \
              --db_host="$HOST" \
              --db_port=5432 \
              --db_user="$PG_USER" \
              --db_password="$PG_PASSWORD"
fi
