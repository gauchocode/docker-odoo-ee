FROM odoo:15.0 AS odoo

LABEL maintainer="Pedro Jabie <pjabie@broobe.com>"

USER root

ENV ETC_DIR=/etc/odoo
ENV DATA_DIR=/opt/odoo/data
ENV LOG_DIR=/var/log/odoo
ENV BKP_DIR=/var/odoo/backups
ENV ADDONS_DIR=/opt/odoo/custom-addons
ENV ODOO_RC=${ETC_DIR}/odoo.conf
RUN \
       mkdir -p ${ETC_DIR} \
    && mkdir -p ${DATA_DIR} \
    && mkdir -p ${LOG_DIR} \
    && mkdir -p ${BKP_DIR} \
    && mkdir -p ${ADDONS_DIR} \
    && chown -R odoo.odoo /opt/odoo \
    && chown -R odoo.odoo /var/odoo

# Copiar los addons Enterprise
COPY ./enterprise /mnt/enterprise-addons

# Ajustar permisos si es necesario
RUN chown -R odoo:odoo /mnt/enterprise-addons


# instalar el ultimo pip
RUN curl -fsSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
    && python3 get-pip.py \
    && rm get-pip.py

RUN apt-get -qq update && apt-get install -yqq --no-install-recommends \
    git python3-dev build-essential

COPY ./requirements /req
RUN pip3 install -r /req/requirements.txt
RUN pip3 install -r /req/odoo-argentina.txt
RUN pip3 install -r /req/adhoc-aeroo_reports.txt
RUN rm -r /req

# crear cache para pyafipws lo necesita para actualizar desde padron y darle
# permisos para que pueda escribir desde pyafipws porque ahi hay una base
# sqlite que se usa cuando se refrescan actividades, impuestos y conceptos.
RUN mkdir /usr/local/lib/python3.9/dist-packages/pyafipws/cache
RUN chmod -R 777 /usr/local/lib/python3.9/dist-packages/pyafipws

# bajar el cifrado del cliente para evitar el error DH_KEY_TOO_SMALL
# parece que la afip tiene un cifrado debil.
RUN sed -i  "s/CipherString = DEFAULT@SECLEVEL=2/CipherString = DEFAULT@SECLEVEL=1/" /etc/ssl/openssl.cnf