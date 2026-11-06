# Star Trek Agentic System Enterprise

**USS Enterprise: agentní enterprise systém pro řízení firmy.**

> Firma je loď USS Enterprise a vy jste její kapitán. Určíte cíl a řeknete „Go", posádka pracuje, Q kontroluje a loď se z každé chyby učí. Ven nejde nic, dokud neřeknete „Proveďte".

Sedm stanic a Q v Claude pokrývají všech 28 rolí firmy. Po instalaci se loď sama naladí na vaši firmu, s **Warpem** běží i sama, na Mac mini nebo na Google Cloudu.

| Stanice | Skill | Drží |
|---|---|---|
| **Picard**, CEO a orchestrátor | `/picard` | mise, strategie, KPI, finance, rozhodnutí, projekty a provoz |
| **Number One**, asistent | `/number-one` | ranní brief, kalendář, akce, agenda, pošta, pokladna |
| **Kirk**, HR | `/kirk` | nábor, zapracování, kapacita, rozvoj, kultura |
| **Spock**, vědecká stanice | `/spock` | wiki, podklady, data, feedback, právo a compliance |
| **Uhura**, komunikace | `/uhura` | brand, sociální sítě, kampaně, PR, eventy |
| **Sulu**, kormidelník | `/sulu` | obchod, CRM, nabídky, partneři, zákaznická podpora |
| **Scotty**, strojovna | `/scotty` | onboarding, Warp, stavba webů a aplikací, IT, updaty |
| **Q**, mimo posádku | `/q` | kontrola, audit, lekce a update verzí |

Celý systém v jednom dokumentu: [STAR-TREK-AGENTIC-SYSTEM-ENTERPRISE.md](STAR-TREK-AGENTIC-SYSTEM-ENTERPRISE.md).

## Jak začít

1. **Instalace:** v Claude Code `/plugin marketplace add captainsofai/Star-Trek-Agentic-System-Enterprise-Public-` a `/plugin install star-trek-agentic-system-enterprise`; v aplikaci Claude zabalte složku `plugin/` do zipu s příponou `.plugin` a nahrajte ho.
2. **Konektory:** e-mail, kalendář a soubory; Notion nebo CRM a fakturaci podle potřeby.
3. **Onboarding:** napište třeba „Ahoj, Enterprise". Loď se za 10 minut zeptá na vás, firmu, tým, nástroje a co vás pálí, a naladí stanice a rituály.
4. **První mise:** řekněte cíl, Picard ukáže plán, vy řeknete „Go". Co má jít ven, schválíte „Proveďte".
5. **Warp:** `/scotty warp` a loď poběží sama, hlášení a rozkazy budou v telefonu. Viz [warp/](warp/README.md).

## Struktura repa

```
.claude-plugin/marketplace.json   katalog pro Claude Code
plugin/skills/lodni-rad/          Lodní řád, mapa rolí, profil firmy, rituály
plugin/skills/onboarding/         naladění lodi na vaši firmu
plugin/skills/<stanice>/          picard, number-one, kirk, spock, uhura, sulu, scotty, q
warp/                             autonomní běh: Velín, rituály, Mac mini, Google Cloud
CHANGELOG.md                      historie verzí
```

---

Star Trek je ochranná známka CBS Studios Inc.; tento projekt s ní není spojen ani jí podporován a jména používá jen jako metaforu velení lodi.
