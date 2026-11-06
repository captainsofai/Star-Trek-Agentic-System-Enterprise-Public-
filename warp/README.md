# Warp: USS Enterprise jako autonomní agentní systém

> **Axiom:** „Warp 1." Loď už nečeká, až kapitán otevře chat. Běží sama podle plánu, hlásí se kapitánovi a ven jedná jen na jeho „Proveďte".

Warp spustí stanice lodi jako agenty Claude (Claude Code v režimu bez obsluhy) na **Mac mini** nebo na **Google Cloudu**. Celé to vede Scotty: v Claude napište `/scotty warp` a on vás provede krok za krokem. Tahle složka je kód, který přitom použije.

## Jak loď v režimu Warp běží

1. **Rituály podle plánu:** `ritualy.json` (cron, místní čas). Na Mac mini je spouští plánovač ve Velínu, na Google Cloudu Cloud Scheduler.
2. **Velín v telefonu:** soukromý chat s Telegram botem. Chodí do něj hlášení a z něj kapitán dává rozkazy:

   | Zpráva | Co se stane |
   |---|---|
   | libovolný text | rozkaz Picardovi, ten ho rozdělí stanicím |
   | `/sulu kurz`, `/picard projekty`, `/number-one rano`, … | rozkaz konkrétní stanici |
   | `Go [ID]` | start mise, kterou Picard naplánoval (`mise/<ID>.md`) |
   | `Proveďte <ID>` | jeden schválený běh s nástroji ven, jen na návrh `<ID>` |
   | `/stav` | poslední hlášení a čekající návrhy |
   | `/stop` (červený poplach) a `/start` | zastavení a obnovení lodi |

3. **Agenti se skilly a nástroji:**
   - každý běh načte plugin lodi (`../plugin`), lodní data (profil firmy, agenda, Knihovna) a MCP konektory z `mcp.json`;
   - v běžném běhu má agent jen `nastroje_bezne`, nástroje ven (`nastroje_ven`) jsou zakázané;
   - akci ven stanice zapíše jako návrh `navrhy/<ID>.md`.

Každý běh uloží hlášení do `hlaseni/`, Velín zapisuje do `logs/`. Na každý běh je strop ceny (`max_budget_usd`) a času (`timeout_s`).

## Soubory

| Soubor | K čemu |
|---|---|
| `velin.py` | Velín: běh stanic, rituály, Telegram, „Proveďte", červený poplach (jen standardní knihovna Pythonu) |
| `ritualy.json` | rituály: id, kdy (cron), stanice, příkaz, zapnuto |
| `config.example.json` | nastavení: lodní data, nástroje běžné a ven, proměnné pro agenta, strop ceny |
| `mcp.example.json` | šablona konektorů (MCP serverů) pro autonomní běh |
| `mac/install.sh` | Mac mini: lodní data v `~/Enterprise`, tajemství do Klíčenky, služba launchd |
| `gcp/setup.sh`, `gcp/Dockerfile` | Google Cloud: Cloud Run, Cloud Storage, Secret Manager, Cloud Scheduler, webhook |

## Mac mini

1. Nainstalujte Claude Code (`npm install -g @anthropic-ai/claude-code`).
2. Stáhněte toto repo, třeba `git clone` do domovské složky.
3. Po onboardingu uložte `profil-firmy.md` do `~/Enterprise/`.
4. Spusťte `warp/mac/install.sh`. Vloží tajemství do Klíčenky (klíč Claude API, token bota, vaše chat ID) a zapne službu.
5. Konektory: `~/Enterprise/.velin/mcp.json` podle šablony. Jména tokenů přidejte do `tajemstvi.txt` a `env_pro_agenta` a znovu spusťte instalaci.

Doporučení: samostatný uživatel macOS jen pro loď s automatickým přihlášením, FileVault, automatické aktualizace a režim bez uspání.

## Google Cloud

```bash
PROJECT=<id-projektu> REGION=europe-west1 ./warp/gcp/setup.sh
# Claude přes Vertex AI místo klíče Claude API:
PROJECT=<id-projektu> USE_VERTEX=1 VERTEX_REGION=<region> ./warp/gcp/setup.sh
```

Skript se před každým krokem zeptá:
1. zapne služby;
2. založí servisní účet a soukromý bucket (disk lodi `/data`);
3. uloží tajemství do Secret Manageru;
4. sestaví obraz a nasadí Velín na Cloud Run s jednou stálou instancí (dva dotazy);
5. založí rituály v Cloud Scheduleru a webhook Telegramu.

Profil firmy, `mcp.json` a úpravy rituálů nahrajete do bucketu (`gs://<bucket>/.velin/`).

## Bezpečnost

1. **Bez „Proveďte" nic ven:** nástroje ven jsou v běžném běhu zakázané přímo v Claude Code (`--disallowedTools`), nejen v pokynech; povolí se jen v běhu po „Proveďte &lt;ID&gt;" a jen na ten návrh.
2. **Tajemství jen v trezoru:** Klíčenka nebo Secret Manager. Agent dostane jen proměnné z `env_pro_agenta`, nikdy token bota ani tokeny Velínu. Bash a WebFetch agent nemá.
3. **Jen kapitán:** Velín přijímá zprávy jen z `TELEGRAM_CHAT_ID`. Na Google Cloudu je webhook chráněný tajným tokenem Telegramu a rituály tokenem `RITUAL_TOKEN`; bucket je soukromý.
4. **Brzda a strop:** `/stop` zastaví všechny běhy i rituály. Na každý běh je strop ceny a času, záznam každého běhu je v `logs/`.
5. **Známá rizika:** injekce přes obsah zvenčí (e-mail, web), proti které stojí pravidla, návrhy místo akcí a schválení kapitánem; token webhooku a rituálů vidí správci projektu, rotujte je po 90 dnech.

Star Trek je ochranná známka CBS Studios Inc.; tento projekt s ní není spojen ani jí podporován a jména používá jen jako metaforu velení lodi.
