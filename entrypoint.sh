#!/bin/bash
set -e

# Validar variables de entorno
: "${HOST:?Variable HOST no definida}"
: "${POSTGRES_DB:?Variable POSTGRES_DB no definida}"
: "${POSTGRES_USER:?Variable POSTGRES_USER no definida}"
: "${POSTGRES_PASSWORD:?Variable POSTGRES_PASSWORD no definida}"
: "${CUSTOM_ADDONS:?Variable CUSTOM_ADDONS no definida}"

# Ruta donde están los módulos personalizados (en Docker: /mnt/extra-addons)
ADDONS_DIR="/mnt/extra-addons"

echo "Esperando a que PostgreSQL esté disponible..."
until pg_isready -h "$HOST" -p 5432; do
    sleep 1
done
echo "PostgreSQL está listo."

MODULES_FILE="/scripts/modulos.txt"
ODOO_CONFIG="/etc/odoo/odoo.conf"

if [ ! -f "$MODULES_FILE" ]; then
  echo "No se encontró el archivo $MODULES_FILE. Iniciando Odoo normalmente..."
  exec odoo -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB"
fi

echo "Extrayendo módulos del archivo $MODULES_FILE..."

# Obtener rutas actuales donde Odoo busca módulos
CUSTOM_ADDONS_PATHS=$(odoo --config="$ODOO_CONFIG" --print-addon-paths 2>/dev/null | tr ':' '\n')

echo "📂 Rutas de módulos en Odoo:"
echo "$CUSTOM_ADDONS_PATHS"

# Extraer nombres de repositorios desde enlaces de GitHub y GitLab en el archivo de módulos
REPOS=$(grep -Eo 'https://(github|gitlab).com/[^ ]+' "$MODULES_FILE" | awk -F'/' '{print $NF}')

echo "🔗 Repositorios encontrados en el archivo de módulos: $REPOS"

# Verificar si las carpetas de los repositorios existen en /mnt/extra-addons y agregar su path si falta en Odoo
MISSING_PATHS=()
for repo in $REPOS; do
    if [ -d "$ADDONS_DIR/$repo" ]; then
        echo "✅ La carpeta $repo existe en $ADDONS_DIR"
        if ! echo "$CUSTOM_ADDONS_PATHS" | grep -q "$ADDONS_DIR/$repo"; then
            echo "➕ La carpeta $repo no está en addons_path de Odoo, se agregará."
            MISSING_PATHS+=("$ADDONS_DIR/$repo")
        fi
    else
        echo "⚠️ Advertencia: La carpeta $repo no existe en $ADDONS_DIR. No se agregará."
    fi
done

# Si hay rutas faltantes, agregarlas a addons_path en odoo.conf
if [ ${#MISSING_PATHS[@]} -gt 0 ]; then
    echo "➕ Agregando rutas de módulos faltantes en el archivo de configuración de Odoo..."

    # Obtener la línea actual de addons_path
    ADDONS_PATH=$(grep -E '^addons_path\s*=' "$ODOO_CONFIG" | cut -d'=' -f2 | tr -d ' ')

    # Agregar las nuevas rutas de repositorios
    NEW_ADDONS_PATH="$ADDONS_PATH,$(IFS=,; echo "${MISSING_PATHS[*]}")"

    # Reemplazar en el archivo de configuración
    sed -i "s|^addons_path\s*=.*|addons_path = $NEW_ADDONS_PATH|" "$ODOO_CONFIG"

    echo "✅ Se actualizaron las rutas de módulos en Odoo."
fi

# Extraer módulos locales del archivo (excluyendo URLs y comentarios)
ALL_MODULES=$(grep -vE '^(#|http)' "$MODULES_FILE" | awk '{$1=$1};1' | tr '\n' ',' | sed 's/,$//')

if [ -z "$ALL_MODULES" ]; then
    echo "No se encontraron módulos locales en $MODULES_FILE. Iniciando Odoo normalmente..."
    exec odoo -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB"
fi

echo "Lista completa de módulos a instalar: $ALL_MODULES"

# Obtener lista de módulos instalados en la base de datos
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
