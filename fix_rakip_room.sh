#!/bin/bash
set -e
docker cp krb-assessment:/app/shells/bi.js /opt/krb-assessment/shells/bi.js

perl -i -0777 -pe '
s/const room = cont\.querySelector\('"'"'#vmo-room-rakip'"'"'\);\n    if \(!room\) return;/const room = cont.querySelector('"'"'#vmo-room-rakip .vmo-data-wall'"'"') || cont.querySelector('"'"'#vmo-room-rakip'"'"');\n    if (!room) return;/
' /opt/krb-assessment/shells/bi.js

echo "Verify:"
grep -n 'vmo-data-wall\|vmo-room-rakip' /opt/krb-assessment/shells/bi.js | grep -A1 'rakip'

docker cp /opt/krb-assessment/shells/bi.js krb-assessment:/app/shells/bi.js
docker restart krb-assessment
echo "TAMAM"
