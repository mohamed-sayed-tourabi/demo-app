# ── Load Test — Exceed HTTP Scaling Threshold ──
if [ -z "$1" ]; then
  echo "Usage: ./load-test.sh <fqdn>"
  echo "Example: ./load-test.sh from-code-to-cloud.gentletree-6e99dd4c.westeurope.azurecontainerapps.io"
  exit 1
fi

APP_URL="https://$1"
CONCURRENT=20   # above the threshold of 10
DURATION=60    # seconds

echo "🔥 Hammering $APP_URL with $CONCURRENT concurrent requests..."
echo "   Watch scaling at: https://portal.azure.com"

for i in $(seq 1 $CONCURRENT); do
  while true; do
    curl -s -o /dev/null "$APP_URL"
  done &
done

sleep $DURATION
echo "🛑 Stopping..."
kill $(jobs -p)