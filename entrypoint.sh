#!/bin/bash
set -e

# Validar variables mínimas necesarias
: "${HOST:?Variable HOST no definida}"
: "${POSTGRES_DB:?Variable POSTGRES_DB no definida}"
: "${POSTGRES_USER:?Variable POSTGRES_USER no definida}"
: "${POSTGRES_PASSWORD:?Variable POSTGRES_PASSWORD no definida}"

CONFIG_PATH="/var/lib/odoo/odoo.conf"

echo "⏳ Esperando a que PostgreSQL esté disponible en $HOST..."
for i in {1..30}; do
    if pg_isready -h "$HOST" -p 5432 >/dev/null; then
        echo "✅ PostgreSQL está listo."
        break
    fi
    echo "⌛ Intento $i/30"
    sleep 1
done

if ! pg_isready -h "$HOST" -p 5432 >/dev/null; then
    echo "❌ No se pudo conectar a PostgreSQL. Abortando..."
    exit 1
fi

# Ejecutar Odoo con debugpy y la config generada previamente
echo "� Iniciando Odoo en modo depuración (debugpy)..."
exec python3 -m debugpy --listen 0.0.0.0:5678 \
    -m odoo --config="$CONFIG_PATH" \
    --db_host="$HOST" \
    --db_port=5432 \
    --db_user="$POSTGRES_USER" \
    --db_password="$POSTGRES_PASSWORD"
