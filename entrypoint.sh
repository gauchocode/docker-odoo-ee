#!/bin/bash
set -e

# Validar variables de entorno
: "${HOST:?Variable HOST no definida}"
: "${POSTGRES_DB:?Variable POSTGRES_DB no definida}"

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

# -----------------------------------------------------------------------------
# 1. Actualizar addons_path en odoo.conf a partir de las rutas de clonación
#    Se consideran sólo las líneas que comienzan con "http" (repositorios)
#    Cada línea de repositorio tiene el formato:
#       <URL> [<carpeta>]
#    Si <carpeta> es "none" o no se especifica, se usará el nombre del repo.
# -----------------------------------------------------------------------------
if [ -f "$MODULES_FILE" ]; then
    echo "🔧 Configurando addons_path a partir de repositorios en modulos.txt..."
    # Extraer solo las líneas que empiezan con "http" y procesarlas:
    ADDONS_PATHS=$(grep '^https' "$MODULES_FILE" | while read -r line; do
        # Separa la URL y, si existe, la carpeta (por espacio)
        repo_url=$(echo "$line" | awk '{print $1}')
        repo_dir=$(echo "$line" | awk '{print $2}')
        # Si no se especificó o se indica "none", se toma el nombre del repo:
        if [[ -z "$repo_dir" || "$repo_dir" == "none" ]]; then
            repo_dir=$(basename "$repo_url" .git)
        fi
        # Se asume que los repos se clonaron en la carpeta indicada en o algún directorio (por ejemplo, /opt/odoo/custom-addons)
        # Ajusta la ruta destino según tu entorno; en este ejemplo se asume que se clonaron en /opt/odoo/custom-addons
        echo "/mnt/extra-addons/$repo_dir"
    done | paste -sd "," -)

    # Obtener el addons_path actual de odoo.conf
    CURRENT_ADDONS_PATH=$(grep '^addons_path' /etc/odoo/odoo.conf | cut -d'=' -f2- | tr -d ' ')
    if [[ -n "$CURRENT_ADDONS_PATH" ]]; then
        UPDATED_ADDONS_PATH="$CURRENT_ADDONS_PATH,$ADDONS_PATHS"
    else
        UPDATED_ADDONS_PATH="$ADDONS_PATHS"
    fi

    # Reemplazar addons_path en odoo.conf
    sed -i "/^addons_path/c\addons_path = $UPDATED_ADDONS_PATH" /etc/odoo/odoo.conf
    echo "✅ 'addons_path' actualizado en /etc/odoo/odoo.conf: $UPDATED_ADDONS_PATH"
else
    echo "⚠️ No se encontró $MODULES_FILE, no se modificó addons_path."
fi

# -----------------------------------------------------------------------------
# 2. Extraer módulos locales (para instalación vía Odoo)
#    Se ignoran las líneas que comienzan con "http" (ya procesadas) y las que son comentarios.
# -----------------------------------------------------------------------------
LOCAL_MODULES=$(grep -vE '^(#|http)' "$MODULES_FILE" | awk '{$1=$1};1')

# Verificar si hay módulos locales o dependencias
if [ -z "$LOCAL_MODULES" ] && [ -z "$declared_dependencies" ]; then
  echo "El archivo $MODULES_FILE no contiene módulos locales válidos. Iniciando Odoo normalmente..."
  exec odoo -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB"
fi

# Combinar módulos locales y dependencias
ALL_MODULES=$(echo -e "$LOCAL_MODULES\n$declared_dependencies" | sort -u | tr '\n' ',' | sed 's/,$//')

echo "Lista completa de módulos a instalar: $ALL_MODULES"

echo "Ejecutando Odoo para instalar módulos..."
exec odoo -i "$ALL_MODULES" -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB" --db_host="$HOST" --db_port=5432 --db_user="$POSTGRES_USER" --db_password="$POSTGRES_PASSWORD" --without-demo=True
