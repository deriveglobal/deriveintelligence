#!/bin/sh
docker exec -i krb-assessment node --input-type=module < /opt/krb-assessment/rep_gelisim_uret.mjs >> /var/log/rep_gelisim.log 2>&1
