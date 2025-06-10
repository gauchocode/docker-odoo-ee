#!/bin/bash
set -e
source .env

# Ruta fija que debe incluirse siempre en addons_path
FIXED_BASE="/mnt/extra-addons"

# Validaciones
if [ -z "$CUSTOM_ADDONS" ] || [ -z "$FILE_PATH" ]; then
    echo "❌ Error: CUSTOM_ADDONS o FILE_PATH no están definidos en .env"
    exit 1
fi

# Asegurar que FILE_PATH sea un directorio
mkdir -p "$FILE_PATH"
ODOO_CONF="$FILE_PATH/odoo.conf"

# Crear odoo.conf si no existe
if [ ! -f "$ODOO_CONF" ]; then
    echo "� Creando nuevo archivo de configuración en $ODOO_CONF..."

    cat > "$ODOO_CONF" <<EOF
[options]
addons_path =
admin_passwd = admin
db_host = ${HOST:-localhost}
db_port = 5432
db_user = ${POSTGRES_USER:-odoo}
db_password = ${POSTGRES_PASSWORD:-odoo}
EOF

    echo "✅ Archivo generado."
else
    echo "� Usando archivo de configuración existente: $ODOO_CONF"
fi

# Construir lista de rutas para addons_path
ADDONS_PATHS=("$FIXED_BASE")  # Siempre incluir la base

for dir in "$CUSTOM_ADDONS"/*/; do
    if [ -d "$dir" ]; then
        folder=$(basename "$dir")
        ADDONS_PATHS+=("$FIXED_BASE/$folder")
    fi
done

# Convertir array a string separada por comas
ADDONS_LINE=$(IFS=, ; echo "${ADDONS_PATHS[*]}")

# Eliminar línea previa de addons_path
sed -i '/^addons_path *=.*/d' "$ODOO_CONF"

# Agregar la nueva línea al final
echo "addons_path = $ADDONS_LINE" >> "$ODOO_CONF"

echo "✅ addons_path actualizado correctamente en $ODOO_CONF:"
echo "$ADDONS_LINE"
