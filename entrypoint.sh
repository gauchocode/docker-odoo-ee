#!/bin/bash
set -e

# Validar variables de entorno
: "${HOST:?Variable HOST no definida}"
: "${POSTGRES_DB:?Variable POSTGRES_DB no definida}"
: "${POSTGRES_USER:?Variable POSTGRES_USER no definida}"
: "${POSTGRES_PASSWORD:?Variable POSTGRES_PASSWORD no definida}"
: "${MAIN_MODULE:?Variable MAIN_MODULE no definida}"

# Rutas
ADDONS_DIR="/mnt/extra-addons"
ORIGINAL_CONFIG="/etc/odoo/odoo.conf"
MODIFIED_CONFIG="/var/lib/odoo/odoo.conf"

echo "Esperando a que PostgreSQL esté disponible..."
for i in {1..30}; do
    if pg_isready -h "$HOST" -p 5432; then
        echo "PostgreSQL está listo."
        break
    fi
    echo "Esperando... intento $i/30"
    sleep 1
done

if ! pg_isready -h "$HOST" -p 5432; then
    echo "❌ No se pudo conectar a PostgreSQL. Abortando..."
    exit 1
fi

# Obtener rutas actuales de addons
CUSTOM_ADDONS_PATHS=$(odoo --config="$ORIGINAL_CONFIG" --print-addon-paths 2>/dev/null | tr ':' '\n')

echo "📂 Rutas de módulos en Odoo actualmente:"
echo "$CUSTOM_ADDONS_PATHS"

# Leer todas las carpetas dentro de /mnt/extra-addons
EXTRA_PATHS=()
for dir in "$ADDONS_DIR"/*/; do
    if [ -d "$dir" ]; then
        echo "Encontrado módulo/carpeta: $dir"
        if ! echo "$CUSTOM_ADDONS_PATHS" | grep -q "$dir"; then
            echo "➕ Agregando $dir a addons_path."
            EXTRA_PATHS+=("$dir")
        else
            echo "✅ $dir ya está en addons_path."
        fi
    fi
done

# Generar nuevo archivo de configuración si hay nuevas rutas
if [ ${#EXTRA_PATHS[@]} -gt 0 ]; then
    echo "🛠️ Generando archivo de configuración modificado en $MODIFIED_CONFIG..."

    # Si el archivo de destino no existe, copiar el original
    if [ ! -f "$MODIFIED_CONFIG" ]; then
        cp "$ORIGINAL_CONFIG" "$MODIFIED_CONFIG"
        echo "📄 Copia base creada desde el archivo original."
    else
        echo "📄 Usando archivo de configuración existente en el destino."
    fi

    # Leer línea actual de addons_path
    ADDONS_PATH=$(grep -E '^addons_path\s*=' "$MODIFIED_CONFIG" | cut -d'=' -f2 | tr -d ' ')

    # Concatenar las nuevas rutas
    NEW_ADDONS_PATH="$ADDONS_PATH,$(IFS=,; echo "${EXTRA_PATHS[*]}")"

    # Reemplazar en el archivo copiado o existente
    sed -i "s|^addons_path\s*=.*|addons_path = $NEW_ADDONS_PATH|" "$MODIFIED_CONFIG"

    echo "✅ addons_path actualizado con éxito."
else
    echo "No se encontraron nuevas rutas para agregar al addons_path."

    # Si no hay cambios, usar el config original solo si no existe el modificado
    if [ ! -f "$MODIFIED_CONFIG" ]; then
        cp "$ORIGINAL_CONFIG" "$MODIFIED_CONFIG"
        echo "📄 Copia base creada desde el archivo original (sin cambios en addons_path)."
    else
        echo "📄 Archivo de configuración ya existe. No se realizaron cambios."
    fi
fi


# Verificar si el módulo principal está instalado
echo "🔍 Verificando si el módulo $MAIN_MODULE ya está instalado..."
INSTALLED_MODULES=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT name FROM ir_module_module WHERE state = 'installed';" | tr -d ' ' | tr ',' '\n')

if echo "$INSTALLED_MODULES" | grep -Fxq "$MAIN_MODULE"; then
    echo "✅ El módulo $MAIN_MODULE ya está instalado. Iniciando Odoo normalmente..."
    exec odoo --config="$MODIFIED_CONFIG" -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB" --db_host="$HOST" --db_port=5432 --db_user="$POSTGRES_USER" --db_password="$POSTGRES_PASSWORD"
else
    echo "🚀 El módulo $MAIN_MODULE no está instalado. Procediendo con la instalación..."
    exec odoo --config="$MODIFIED_CONFIG" -i "$MAIN_MODULE" -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB" --db_host="$HOST" --db_port=5432 --db_user="$POSTGRES_USER" --db_password="$POSTGRES_PASSWORD" --without-demo=True
fi
