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

PROD_URL="$PROD_URL"
PROD_MASTER_KEY="$PROD_MASTER_KEY"
PG_DB="$PG_DB"
ODOO_PORT="${ODOO_PORT:-8069}"  # Por defecto 8069 si no está definido

BACKUP_FILE="odoo_backup.zip"
LOCAL_URL="http://localhost:$ODOO_PORT"

# ========================
# FUNCIÓN PARA VERIFICAR CONEXIÓN A ODOO
# ========================
function verificar_conexion() {
    URL=$1
    echo "🔍 Verificando conexión a $URL ..."
    if curl -k -L -s --head --request GET "$URL/web/database/manager" | grep "200 OK" > /dev/null; then
        echo "✅ Conexión exitosa a $URL"
    else
        echo "❌ No se pudo conectar a $URL"
        exit 1
    fi
}

# ========================
# FUNCIÓN DE BACKUP
# ========================
function backup_odoo() {
    echo "🔵 Iniciando backup desde $PROD_URL de la base '$PG_DB'..."
    verificar_conexion "$PROD_URL"
    curl -k -L -X POST "https://$PROD_URL/web/database/backup" \
        -d "master_pwd=$PROD_MASTER_KEY" \
        -d "name=$PG_DB" \
        -d "backup_format=zip" \
        --output "$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        echo "✅ Backup completado: $BACKUP_FILE"
    else
        echo "❌ Error durante el backup."
        exit 1
    fi
}

# ========================
# FUNCIÓN PARA ELIMINAR BASE DE DATOS LOCAL
# ========================
function drop_local_db() {
    echo "🗑️ Eliminando base '$PG_DB' en entorno local ($LOCAL_URL)..."
    verificar_conexion "$LOCAL_URL"
    curl -k -L -X POST "$LOCAL_URL/web/database/drop" \
        -d "master_pwd=$PROD_MASTER_KEY" \
        -d "name=$PG_DB" \
        -d "drop=true"
}

# ========================
# FUNCIÓN DE RESTORE EN LOCAL
# ========================
function restore_local() {
    echo "🟡 Restaurando backup en entorno local ($LOCAL_URL) con nombre '$PG_DB'..."
    verificar_conexion "$LOCAL_URL"
    curl -k -L -X POST "$LOCAL_URL/web/database/restore" \
        -F "master_pwd=$PROD_MASTER_KEY" \
        -F "name=$PG_DB" \
        -F "backup_file=@$BACKUP_FILE" \
        -F "copy=true"

    if [ $? -eq 0 ]; then
        echo "✅ Restauración completada como '$PG_DB' en local"
    else
        echo "❌ Error durante la restauración."
        exit 1
    fi
}

# ========================
# FUNCIÓN PARA LIMPIAR ARCHIVOS TEMPORALES
# ========================
function limpiar_backup() {
    echo "🧹 Eliminando archivo temporal $BACKUP_FILE..."
    rm -f "$BACKUP_FILE"
    echo "✅ Limpieza completada."
}

# ========================
# EJECUCIÓN COMPLETA
# ========================
limpiar_backup
backup_odoo
drop_local_db
restore_local