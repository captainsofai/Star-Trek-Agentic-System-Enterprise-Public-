#!/bin/bash
# USS Enterprise: Warp na Google Cloud.
# Cloud Run služba (Velín), Cloud Storage jako disk lodi, Secret Manager, Cloud Scheduler pro rituály a webhook Telegramu.
# Každý krok, který zakládá prostředky nebo stojí peníze, se nejdřív zeptá.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="${PROJECT:?Nastavte PROJECT=<id projektu v Google Cloud>}"
REGION="${REGION:-europe-west1}"
BUCKET="${BUCKET:-$PROJECT-uss-enterprise}"
SLUZBA="uss-enterprise-velin"
SA="$SLUZBA@$PROJECT.iam.gserviceaccount.com"
IMAGE="$REGION-docker.pkg.dev/$PROJECT/uss-enterprise/velin:latest"
USE_VERTEX="${USE_VERTEX:-0}"            # 1 = Claude přes Vertex AI místo klíče Claude API
VERTEX_REGION="${VERTEX_REGION:-global}" # ověřte region dostupnosti Claude ve Vertex AI
TZ_RITUALY="${TZ_RITUALY:-Europe/Prague}"

ano() { read -r -p "$1 [ano/ne] " o; [ "$o" = "ano" ]; }

echo "🖖 USS Enterprise: Warp na Google Cloud (projekt $PROJECT, region $REGION)"
gcloud config set project "$PROJECT" >/dev/null

if ano "1/6 Zapnout služby (Run, Scheduler, Secret Manager, Artifact Registry, Cloud Build, Storage)?"; then
  gcloud services enable run.googleapis.com cloudscheduler.googleapis.com secretmanager.googleapis.com \
    artifactregistry.googleapis.com cloudbuild.googleapis.com storage.googleapis.com
  [ "$USE_VERTEX" = "1" ] && gcloud services enable aiplatform.googleapis.com
fi

if ano "2/6 Založit servisní účet $SLUZBA a soukromý bucket gs://$BUCKET?"; then
  gcloud iam service-accounts describe "$SA" >/dev/null 2>&1 || gcloud iam service-accounts create "$SLUZBA" --display-name "USS Enterprise Velín"
  gcloud storage buckets describe "gs://$BUCKET" >/dev/null 2>&1 || \
    gcloud storage buckets create "gs://$BUCKET" --location "$REGION" --uniform-bucket-level-access --public-access-prevention
  gcloud storage buckets add-iam-policy-binding "gs://$BUCKET" --member "serviceAccount:$SA" --role roles/storage.objectAdmin >/dev/null
  [ "$USE_VERTEX" = "1" ] && gcloud projects add-iam-policy-binding "$PROJECT" --member "serviceAccount:$SA" --role roles/aiplatform.user >/dev/null
  python3 - "$REPO" <<'PY' > /tmp/uss-config.json
import json, sys
c = json.load(open(f"{sys.argv[1]}/warp/config.example.json", encoding="utf-8"))
c.update(data_dir="/data", plugin_dir="/app/plugin", ritualy="/data/.velin/ritualy.json", mcp_config="/data/.velin/mcp.json")
print(json.dumps(c, ensure_ascii=False, indent=2))
PY
  gcloud storage cp -n /tmp/uss-config.json "gs://$BUCKET/.velin/config.json"
  gcloud storage cp -n "$REPO/warp/ritualy.json" "gs://$BUCKET/.velin/ritualy.json"
  echo "Profil firmy nahrajte do gs://$BUCKET/profil-firmy.md (po onboardingu)."
fi

TAJEMSTVI="TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID TELEGRAM_WEBHOOK_SECRET RITUAL_TOKEN"
[ "$USE_VERTEX" = "1" ] || TAJEMSTVI="ANTHROPIC_API_KEY $TAJEMSTVI"
if ano "3/6 Uložit tajemství do Secret Manageru ($TAJEMSTVI)?"; then
  for N in $TAJEMSTVI; do
    if gcloud secrets describe "$N" >/dev/null 2>&1; then echo "✓ $N existuje"; continue; fi
    case "$N" in
      TELEGRAM_WEBHOOK_SECRET|RITUAL_TOKEN) V="$(openssl rand -hex 24)";;
      *) read -r -s -p "Vložte $N (text se nezobrazí): " V; echo;;
    esac
    printf %s "$V" | gcloud secrets create "$N" --data-file=- --replication-policy=automatic >/dev/null
    gcloud secrets add-iam-policy-binding "$N" --member "serviceAccount:$SA" --role roles/secretmanager.secretAccessor >/dev/null
    echo "✓ $N uloženo"
  done
fi

if ano "4/6 Sestavit obraz Velínu (Cloud Build)?"; then
  gcloud artifacts repositories describe uss-enterprise --location "$REGION" >/dev/null 2>&1 || \
    gcloud artifacts repositories create uss-enterprise --repository-format docker --location "$REGION"
  cat > /tmp/uss-build.yaml <<YAML
steps:
- name: gcr.io/cloud-builders/docker
  args: ["build", "-t", "$IMAGE", "-f", "warp/gcp/Dockerfile", "."]
images: ["$IMAGE"]
YAML
  gcloud builds submit "$REPO" --config /tmp/uss-build.yaml
fi

if ano "5/6 Nasadit Velín na Cloud Run (1 stálá instance, bez veřejných dat; účtuje se stále)?"; then
  SECRETS=""; for N in $TAJEMSTVI; do SECRETS="$SECRETS,$N=$N:latest"; done
  ENVS="ENTERPRISE_CONFIG=/data/.velin/config.json"
  [ "$USE_VERTEX" = "1" ] && ENVS="$ENVS,CLAUDE_CODE_USE_VERTEX=1,ANTHROPIC_VERTEX_PROJECT_ID=$PROJECT,CLOUD_ML_REGION=$VERTEX_REGION"
  gcloud run deploy "$SLUZBA" --image "$IMAGE" --region "$REGION" --service-account "$SA" \
    --allow-unauthenticated --min-instances 1 --max-instances 1 --no-cpu-throttling \
    --cpu 1 --memory 2Gi --timeout 3600 --concurrency 10 \
    --add-volume name=lod,type=cloud-storage,bucket="$BUCKET" --add-volume-mount volume=lod,mount-path=/data \
    --set-env-vars "$ENVS" --set-secrets "${SECRETS#,}"
fi

URL="$(gcloud run services describe "$SLUZBA" --region "$REGION" --format 'value(status.url)')"
if ano "6/6 Založit rituály v Cloud Scheduleru a webhook Telegramu ($URL)?"; then
  RT="$(gcloud secrets versions access latest --secret RITUAL_TOKEN)"
  python3 - "$REPO/warp/ritualy.json" <<'PY' | while IFS=$'\t' read -r ID KDY; do
import json, sys
for r in json.load(open(sys.argv[1], encoding="utf-8")):
    if r.get("zapnuto", True):
        print(f"{r['id']}\t{r['kdy']}")
PY
    gcloud scheduler jobs describe "uss-enterprise-$ID" --location "$REGION" >/dev/null 2>&1 && \
      gcloud scheduler jobs delete "uss-enterprise-$ID" --location "$REGION" --quiet
    gcloud scheduler jobs create http "uss-enterprise-$ID" --location "$REGION" --schedule "$KDY" \
      --time-zone "$TZ_RITUALY" --uri "$URL/ritual/$ID" --http-method POST \
      --headers "Authorization=Bearer $RT" >/dev/null
    echo "✓ rituál $ID ($KDY)"
  done
  TG="$(gcloud secrets versions access latest --secret TELEGRAM_BOT_TOKEN)"
  WS="$(gcloud secrets versions access latest --secret TELEGRAM_WEBHOOK_SECRET)"
  curl -fsS "https://api.telegram.org/bot$TG/setWebhook" --data-urlencode "url=$URL/telegram" --data-urlencode "secret_token=$WS" >/dev/null
  echo "✓ webhook Telegramu nastaven"
fi
echo "🖖 Warp 1. Zkouška: napište botovi /stav. Zastavení lodi: /stop."
