#!/bin/bash
set -e

# Validar variables de entorno
: "${HOST:?Variable HOST no definida}"
: "${POSTGRES_DB:?Variable POSTGRES_DB no definida}"
: "${POSTGRES_USER:?Variable POSTGRES_USER no definida}"
: "${POSTGRES_PASSWORD:?Variable POSTGRES_PASSWORD no definida}"
: "${MAIN_MODULE:?Variable MAIN_MODULE no definida}"

# Ruta de addons personalizados
ADDONS_DIR="/mnt/extra-addons"
ODOO_CONFIG="/etc/odoo/odoo.conf"

echo "Esperando a que PostgreSQL esté disponible..."
# Limitar a 30 intentos (30 segundos de espera)
for i in {1..30}; do
    if pg_isready -h "$HOST" -p 5432; then
        echo "PostgreSQL está listo."
        break
    fi
    echo "Esperando... intento $i/30"
    sleep 1
done

# Si después de 30 intentos sigue sin estar listo, abortar
if ! pg_isready -h "$HOST" -p 5432; then
    echo "❌ No se pudo conectar a PostgreSQL. Abortando..."
    exit 1
fi

# Obtener rutas actuales de addons
CUSTOM_ADDONS_PATHS=$(odoo --config="$ODOO_CONFIG" --print-addon-paths 2>/dev/null | tr ':' '\n')

echo "📂 Rutas de módulos en Odoo actualmente:"
echo "$CUSTOM_ADDONS_PATHS"

# Leer todas las carpetas dentro de /mnt/extra-addons
EXTRA_PATHS=()
for dir in "$ADDONS_DIR"/*/; do
    if [ -d "$dir" ]; then
        echo "Encontrado módulo/carpeta: $dir"
        # Verificar si ya está en addons_path
        if ! echo "$CUSTOM_ADDONS_PATHS" | grep -q "$dir"; then
            echo "➕ Agregando $dir a addons_path."
            EXTRA_PATHS+=("$dir")
        else
            echo "✅ $dir ya está en addons_path."
        fi
    fi
done

# Si hay nuevas rutas, agregarlas al addons_path
if [ ${#EXTRA_PATHS[@]} -gt 0 ]; then
    echo "🛠️ Actualizando addons_path en $ODOO_CONFIG..."
    # Obtener línea actual
    ADDONS_PATH=$(grep -E '^addons_path\s*=' "$ODOO_CONFIG" | cut -d'=' -f2 | tr -d ' ')

    # Concatenar las nuevas rutas
    NEW_ADDONS_PATH="$ADDONS_PATH,$(IFS=,; echo "${EXTRA_PATHS[*]}")"

    # Reemplazar la línea completa
    sed -i "s|^addons_path\s*=.*|addons_path = $NEW_ADDONS_PATH|" "$ODOO_CONFIG"

    echo "✅ addons_path actualizado con éxito."
else
    echo "No se encontraron nuevas rutas para agregar al addons_path."
fi

# Verificar si el módulo ya está instalado
echo "🔍 Verificando si el módulo $MAIN_MODULE ya está instalado..."
INSTALLED_MODULES=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT name FROM ir_module_module WHERE state = 'installed';" | tr -d ' ' | tr ',' '\n')

if echo "$INSTALLED_MODULES" | grep -Fxq "$MAIN_MODULE"; then
    echo "✅ El módulo $MAIN_MODULE ya está instalado. Iniciando Odoo normalmente..."
    exec odoo -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB" --db_host="$HOST" --db_port=5432 --db_user="$POSTGRES_USER" --db_password="$POSTGRES_PASSWORD"
else
    echo "🚀 El módulo $MAIN_MODULE no está instalado. Procediendo con la instalación..."
    exec odoo -i "$MAIN_MODULE" -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB" --db_host="$HOST" --db_port=5432 --db_user="$POSTGRES_USER" --db_password="$POSTGRES_PASSWORD" --without-demo=True
fi
