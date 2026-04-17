# ── Load Test — Trigger Container Apps HTTP Scaling ──
[ -z "$1" ] && echo "Usage: ./load-test.sh <fqdn>" && exit 1

URL="https://$1/api/info"
END=$(( $(date +%s) + 180 ))

echo "Load testing $URL for 3 minutes..."

for i in $(seq 1 20); do
  while [ "$(date +%s)" -lt "$END" ]; do
    if [ "$i" -eq 1 ]; then
      curl -s --max-time 5 "$URL" 2>/dev/null; sleep 5
    else
      curl -s -o /dev/null --max-time 5 "$URL"; sleep 0.2
    fi
  done &
done

wait
echo "Done."
