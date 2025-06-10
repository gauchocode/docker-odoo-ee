#!/bin/bash
source .env

VERBOSE=false
if [[ "$1" == "--verbose" ]]; then
    VERBOSE=true
fi

if [ -z "$CUSTOM_ADDONS" ]; then
    echo "❌ Error: CUSTOM_ADDONS no está definido en .env"
    exit 1
fi

echo "� Buscando repositorios git en $CUSTOM_ADDONS..."

for dir in "$CUSTOM_ADDONS"/*/; do
    if [ -d "$dir/.git" ]; then
        echo "➡️ Actualizando $dir..."

        if $VERBOSE; then
            git -C "$dir" pull
            if [[ $? -eq 0 ]]; then
                echo "✅ Pull exitoso en $dir"
            else
                echo "❌ Error al hacer pull en $dir"
            fi
        else
            OUTPUT=$(git -C "$dir" pull 2>&1)
            if [[ $? -eq 0 ]]; then
                echo "✅ Pull exitoso en $dir"
            else
                echo "❌ Error al hacer pull en $dir"
            fi
        fi
    fi
done

echo "✅ Actualización finalizada."
