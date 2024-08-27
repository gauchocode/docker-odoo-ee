#!/usr/bin/env bash
sd build --rm=true -t gauchocode/odoo-gc:16.0 ./
result=$?
if [ "$result" -eq 0 ]; then
    sd push gauchocode/odoo-gc:16.0
else
    echo "Falló la creación de la imagen"
fi
exit $return_code
