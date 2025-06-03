#!/bin/bash

# Cargar variables desde el archivo .env
if [ -f .env ]; then
    set -o allexport
    source .env
    set +o allexport
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

# Verificar que el archivo de módulos existe y no está vacío
if [ ! -f "$MODULES_FILE" ] || [ ! -s "$MODULES_FILE" ]; then
    echo "❌ ERROR: El archivo '$MODULES_FILE' no existe o está vacío."
    exit 1
fi

echo "📂 Leyendo '$MODULES_FILE'..."

# Leer el archivo y extraer enlaces de GitHub y GitLab con sus posibles branches
while IFS= read -r line; do
    echo "🔍 Procesando línea: $line"
    repo_url=$(echo "$line" | grep -Eo "(https://github\.com/[^ ]+|https://gitlab\.com/[^ ]+)(\.git)?")
    branch=$(echo "$line" | sed -n 's/.*--branch[ ]*\"\?\([^\"]*\)\"\?.*/\1/p')
    
    # Si no se encuentra una branch en la línea, usar ODOO_VERSION
    branch=${branch:-$ODOO_VERSION}
    
    if [ -n "$repo_url" ]; then
        echo "🔗 URL detectada: $repo_url"
        echo "🌿 Branch seleccionada: $branch"

        repo_name=$(basename "$repo_url" .git)
        target_dir="$ADDONS_DIR/$repo_name"
        
        # Verificar si el repositorio ya existe
        if [ -d "$target_dir" ]; then
            echo "✅ El repositorio '$repo_name' ya existe en '$ADDONS_DIR', omitiendo clonación."
        else
            echo "🚀 Clonando '$repo_url' en '$target_dir' (branch '$branch')..."
            
            # Autenticación para GitLab
            if [[ "$repo_url" == *"gitlab.com"* ]] && [ -n "$GITLAB_USER" ] && [ -n "$GITLAB_PASSWORD" ]; then
                repo_url_with_auth=$(echo "$repo_url" | sed "s#https://#https://$GITLAB_USER:$GITLAB_PASSWORD@#")
            else
                repo_url_with_auth="$repo_url"
            fi
            
            # Intentar clonar con la branch especificada
            if git clone --branch "$branch" --single-branch "$repo_url_with_auth" "$target_dir" 2>/dev/null; then
                echo "✅ Repositorio '$repo_name' clonado en la branch '$branch'."
            else
                echo "⚠️ No se encontró la branch '$branch' en '$repo_url'. Clonando la branch por defecto..."
                if git clone "$repo_url_with_auth" "$target_dir"; then
                    echo "✅ Repositorio '$repo_name' clonado en la branch por defecto."
                else
                    echo "❌ Error al clonar '$repo_url'."
                fi
            fi
        fi
    else
        echo "⚠️ No se encontró una URL válida en la línea: $line"
    fi

done < "$MODULES_FILE"

echo "🔄 Proceso de clonación finalizado."
