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

MODULES_LIST="/scripts/modulos.txt"

if [ ! -f "$MODULES_LIST" ]; then
  echo "No se encontró el archivo $MODULES_LIST. Iniciando Odoo normalmente..."
  exec odoo -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB"
fi

echo "Extrayendo módulos del archivo $MODULES_LIST..."

# Extrae los nombres de módulos principales (líneas que comienzan con uno o más guiones y un espacio).
declared_modules=$(grep -E "^-+\s+" "$MODULES_LIST" | sed -E 's/^-+\s+([^ ]+).*/\1/')

# Extrae las dependencias: busca la cadena "DEPEND ON:" y toma lo que sigue.
declared_dependencies=$(grep -E "DEPEND ON:" "$MODULES_LIST" \
  | sed -E 's/.*DEPEND ON:\s*(.*)/\1/' \
  | tr ',' '\n' \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
  | grep -v '^$' \
  | sort -u)

# Verificar si hay módulos válidos
if [ -z "$declared_modules" ] && [ -z "$declared_dependencies" ]; then
  echo "El archivo $MODULES_LIST no contiene módulos válidos. Iniciando Odoo normalmente..."
  exec odoo -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB"
fi

# Une ambas listas y genera una cadena separada por comas.
all_modules=$(echo -e "$declared_modules\n$declared_dependencies" | sort -u | tr '\n' ',' | sed 's/,$//')

echo "Lista completa de módulos a instalar: $all_modules"

echo "Ejecutando Odoo para instalar módulos..."
exec odoo -i "$all_modules" -d "$POSTGRES_DB" --db-filter="$POSTGRES_DB" --db_host="$HOST" --db_port=5432 --db_user="$POSTGRES_USER" --db_password="$POSTGRES_PASSWORD"

