#!/bin/bash

# Cargar variables desde el archivo .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Definir variables
MODULES_FILE="modulos.txt"
ADDONS_DIR=$CUSTOM_ADDONS

# Validar que ODOO_VERSION esté definida
if [ -z "$ODOO_VERSION" ]; then
    echo "❌ ERROR: La variable ODOO_VERSION no está definida en el archivo .env"
    exit 1
fi

echo "🌍 Usando la versión de Odoo: $ODOO_VERSION"

# Crear la carpeta de destino si no existe
mkdir -p "$ADDONS_DIR"

# Leer el archivo y extraer enlaces de GitHub y GitLab
grep -Eo "(https://github\.com/[^ ]+|https://gitlab\.com/[^ ]+)\.git" "$MODULES_FILE" | while read -r repo_url; do
    # Obtener el nombre del repositorio (última parte de la URL sin .git)
    repo_name=$(basename "$repo_url" .git)
    target_dir="$ADDONS_DIR/$repo_name"

    # Verificar si el repositorio ya existe
    if [ -d "$target_dir" ]; then
        echo "✅ El repositorio '$repo_name' ya existe en '$ADDONS_DIR', omitiendo clonación."
    else
        echo "🚀 Clonando '$repo_url' en '$target_dir' (intentando la branch '$ODOO_VERSION')..."
        
        # Intentar clonar la branch específica
        git clone --branch "$ODOO_VERSION" --single-branch "$repo_url" "$target_dir" 2>/dev/null

        # Verificar si la clonación fue exitosa
        if [ $? -eq 0 ]; then
            echo "✅ Repositorio '$repo_name' clonado en la branch '$ODOO_VERSION'."
        else
            echo "⚠️ No se encontró la branch '$ODOO_VERSION' en '$repo_url'. Clonando la branch por defecto..."
            git clone "$repo_url" "$target_dir"

            if [ $? -eq 0 ]; then
                echo "✅ Repositorio '$repo_name' clonado en la branch por defecto."
            else
                echo "❌ Error al clonar '$repo_url'."
            fi
        fi
    fi
done

echo "🔄 Proceso de clonación finalizado."
