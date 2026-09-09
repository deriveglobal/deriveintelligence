echo "############ SUPHELI YAZMA UCLARI — auth var mi, gercekten oku ############"
for L in 20875 21008 20720 20981 14720 16488 17737; do
  echo "───────── satir $L ─────────"
  sed -n "${L},$((L+12))p" server_container.mjs
  echo
done
