#!/bin/bash
# USS Enterprise: Engage na Mac mini.
# Založí lodní data, uloží tajemství do Klíčenky a zapne Velín jako službu launchd.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
DATA="${ENTERPRISE_DATA:-$HOME/Enterprise}"
VELIN="$DATA/.velin"
LABEL="cz.uss-enterprise.velin"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "🖖 USS Enterprise: Engage na Mac mini"
command -v python3 >/dev/null || { echo "Chybí python3 (xcode-select --install)."; exit 1; }
CLAUDE="$(command -v claude || true)"
[ -n "$CLAUDE" ] || { echo "Chybí Claude Code: npm install -g @anthropic-ai/claude-code"; exit 1; }

mkdir -p "$DATA"/{CEO,Knihovna,hlaseni,navrhy/hotovo,logs} "$VELIN" "$HOME/Library/LaunchAgents"
[ -f "$DATA/profil-firmy.md" ] || echo "⚠️  Chybí $DATA/profil-firmy.md: nejdřív udělejte onboarding (/scotty nastav lod) a profil sem uložte."

if [ ! -f "$VELIN/config.json" ]; then
  python3 - "$REPO" "$DATA" "$VELIN" <<'PY'
import json, sys
repo, data, velin = sys.argv[1:]
c = json.load(open(f"{repo}/engage/config.example.json", encoding="utf-8"))
c.update(data_dir=data, plugin_dir=f"{repo}/plugin", ritualy=f"{velin}/ritualy.json", mcp_config=f"{velin}/mcp.json")
json.dump(c, open(f"{velin}/config.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
  echo "✓ Nastavení: $VELIN/config.json"
fi
[ -f "$VELIN/ritualy.json" ] || cp "$REPO/engage/ritualy.json" "$VELIN/ritualy.json"
[ -f "$VELIN/tajemstvi.txt" ] || printf "ANTHROPIC_API_KEY\nTELEGRAM_BOT_TOKEN\nTELEGRAM_CHAT_ID\n" > "$VELIN/tajemstvi.txt"

echo "Tajemství jdou jen do Klíčenky (služba uss-enterprise). Seznam jmen: $VELIN/tajemstvi.txt"
while read -r NAZEV; do
  [ -n "$NAZEV" ] || continue
  if security find-generic-password -s uss-enterprise -a "$NAZEV" >/dev/null 2>&1; then
    echo "✓ $NAZEV už je v Klíčence"
  else
    echo "Vložte $NAZEV (text se nezobrazí):"
    security add-generic-password -s uss-enterprise -a "$NAZEV" -w
  fi
done < "$VELIN/tajemstvi.txt"

cat > "$VELIN/start.sh" <<SH
#!/bin/bash
export ENTERPRISE_CONFIG="$VELIN/config.json"
while read -r N; do
  [ -n "\$N" ] || continue
  V="\$(security find-generic-password -s uss-enterprise -a "\$N" -w 2>/dev/null)" && export "\$N=\$V"
done < "$VELIN/tajemstvi.txt"
exec /usr/bin/env python3 "$REPO/engage/velin.py" polling
SH
chmod 700 "$VELIN/start.sh"

cat > "$PLIST" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$VELIN/start.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>$(dirname "$CLAUDE"):/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string></dict>
  <key>StandardOutPath</key><string>$DATA/logs/launchd.log</string>
  <key>StandardErrorPath</key><string>$DATA/logs/launchd.log</string>
</dict>
</plist>
XML

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "✓ Velín běží jako služba $LABEL (log: $DATA/logs/launchd.log)."
echo "Zkouška: napište botovi /stav. Zastavení lodi: /stop. Vypnutí služby: launchctl bootout gui/\$(id -u)/$LABEL"
