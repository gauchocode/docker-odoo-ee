#!/bin/bash
set -e

# Validar variables de entorno
: "${HOST:?Variable HOST no definida}"
: "${POSTGRES_DB:?Variable POSTGRES_DB no definida}"
: "${POSTGRES_USER:?Variable POSTGRES_USER no definida}"
: "${POSTGRES_PASSWORD:?Variable POSTGRES_PASSWORD no definida}"

echo "Esperando a que PostgreSQL esté disponible..."
until pg_isready -h "$HOST" -p 5432; do
    sleep 1
done
echo "PostgreSQL está listo."

MODULES_FILE="/scripts/modulos.txt"

if [ ! -f "$MODULES_FILE" ]; then
  echo "No se encontró el archivo $MODULES_FILE. Iniciando Odoo normalmente..."
  exec odoo -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB"
fi

echo "Extrayendo módulos del archivo $MODULES_FILE..."

# Extraer módulos locales del archivo (excluyendo URLs y comentarios)
ALL_MODULES=$(grep -vE '^(#|http)' "$MODULES_FILE" | awk '{$1=$1};1' | tr '\n' ',' | sed 's/,$//')

if [ -z "$ALL_MODULES" ]; then
    echo "No se encontraron módulos locales en $MODULES_FILE. Iniciando Odoo normalmente..."
    exec odoo -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB"
fi

echo "Lista completa de módulos a instalar: $ALL_MODULES"

# 🔎 Obtener lista de módulos instalados en la base de datos
# Normalizar módulos instalados (eliminar espacios y convertir a lista con líneas)
INSTALLED_MODULES=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT name FROM ir_module_module WHERE state = 'installed';" | tr -d ' ' | tr ',' '\n')

# Normalizar la lista de módulos a instalar
MODULES_TO_INSTALL=$(echo "$ALL_MODULES" | tr ',' '\n' | tr -d ' ' | grep -Fxv -f <(echo "$INSTALLED_MODULES") | tr '\n' ',' | sed 's/,$//')

# Verificación de depuración
echo "📌 Lista completa de módulos: $ALL_MODULES"
echo "✅ Módulos instalados: $INSTALLED_MODULES"
echo "🚀 Módulos realmente no instalados y que se instalarán: $MODULES_TO_INSTALL"

if [ -z "$MODULES_TO_INSTALL" ]; then
    echo "Todos los módulos ya están instalados. No se realizará ninguna acción."
    exec odoo -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB" --db_host="$HOST" --db_port=5432 --db_user="$POSTGRES_USER" --db_password="$POSTGRES_PASSWORD" 
else
    echo "Módulos a instalar: $MODULES_TO_INSTALL"
    exec odoo -i "$MODULES_TO_INSTALL" -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB" --db_host="$HOST" --db_port=5432 --db_user="$POSTGRES_USER" --db_password="$POSTGRES_PASSWORD" --without-demo=True
fi
