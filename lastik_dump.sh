#!/usr/bin/env bash
# Salt okuma. Yamalayacagim 25 satirin TAM metnini dok.
# Hafizadan anchor uydurmak yasak -- her yama taze grep'ten.
S=/opt/krb-assessment/server_container.mjs
for L in 21060 21096 21165 21536 22143 22148 22154 22912 22992 23042 \
         23191 23219 23250 23353 23511 24607 24618 24624 24645 24654 \
         24668 26430 26542 29031; do
  echo "══════════ satir $L ══════════"
  sed -n "$((L-2)),$((L+3))p" $S
done
echo
echo "══════════ AI prompt bloku (24600-24675) — ornek SQL'ler ══════════"
sed -n '24600,24675p' $S
