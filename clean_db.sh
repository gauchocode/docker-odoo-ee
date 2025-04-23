#!/bin/bash

# ========================
# CARGAR VARIABLES DESDE .env
# ========================
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ Archivo .env no encontrado."
    exit 1
fi

PG_DB="$PG_DB"
PG_USER="$PG_USER"
PG_CONTAINER_NAME="$PG_CONTAINER_NAME"
ODOO_CONTAINER_NAME="$ODOO_CONTAINER_NAME"
PG_PASSWORD="$PG_PASSWORD"


# ========================
# COMANDOS SQL QUE VAMOS A EJECUTAR
# ========================
SQL=$(cat <<EOF
-- 1. Cambiar la contraseña del admin a 'admin'
UPDATE res_users
SET password = 'admin'
WHERE login = 'admin';

-- 2. Eliminar servidores de correo
DELETE FROM ir_mail_server;
DELETE FROM fetchmail_server;

-- 3. Desactivar todos los cron jobs
UPDATE ir_cron SET active = FALSE;
EOF
)

# ========================
# EJECUCIÓN DENTRO DEL CONTENEDOR DE POSTGRES
# ========================
echo "🔧 Ejecutando limpieza en base '$PG_DB' dentro del contenedor '$PG_CONTAINER_NAME'..."
docker exec -i "$PG_CONTAINER_NAME" psql -U "$PG_USER" -d "$PG_DB" -c "$SQL" 

if [ $? -eq 0 ]; then
    echo "✅ Cambios aplicados exitosamente en '$PG_DB'"
else
    echo "❌ Error al aplicar los cambios en la base de datos."
    exit 1
fi
