# Arbeitsweise im gemeinsamen Sourcebaum (GottFA80 PLuS)

## Was ändern → wo

| Ich will … | Datei |
|---|---|
| Logik ändern (für alle Boards) | `top/SYS80.vhd`, `lib_common/*.vhd` |
| eine neue `.vhd` hinzufügen | Datei nach `lib_common/` **und** Eintrag in `scripts/files_common.tcl` |
| einen Pin eines Boards verlegen | `variants/<n>/pins.tcl` |
| einen Port nur auf einem Board haben | Port ins Top-Level, auf den anderen Boards in `variant.psd1` → `VirtualPins` |
| eine globale Quartus-Einstellung | `scripts/common_header.tcl` |
| Gerät/Familie | `variants/<n>/device.tcl` |
| Timing-Constraints | `lib_common/SYS80.sdc` (gilt für alle) |
| Megafunction (ROM/RAM) neu erzeugen | in **beiden** `lib_cyclone_IV/` und `lib_cyclone_10/`, Entity-Namen gleich lassen |
| Release | `SW_SUB` in `lib_common/version_pkg.vhd` +1, dann `scripts/release.ps1 -Note "…"` |

**`variants/<n>/SYS80.qsf` nie von Hand ändern.** Schreibt Quartus aus der IDE etwas
hinein (Pin Planner, Settings-Dialog), meldet `gen_qsf.ps1 -Quiet` das beim nächsten
`check.ps1`/`build.ps1` und überschreibt es. Die Änderung dann ins passende Fragment
übertragen.

## Ablauf einer Änderung

```powershell
cd N:\Projekte\FPGA System80\FPGA_source
powershell -File scripts\check.ps1            # schnell: nur Synthese aller Boards
powershell -File scripts\check.ps1 -Full      # voll, mit Slack und .sof
powershell -File scripts\build.ps1 plus_hw21x_cyclone_iv   # .sof + .jic eines Boards
```

`check.ps1` vergleicht mit `scripts/baseline.csv` (Synthese-Zahlen Comb/Reg/Mem exakt,
Slack mit Toleranz 1,5 ns und Boden 0,05 ns). Eine **gewollte** Änderung: Zahlen in
`baseline.csv` nachziehen und in der Note-Spalte begründen.

Exit-Codes: 0 sauber · 1 Buildfehler · 2 Abweichung von der Baseline.

## Release

1. `lib_common/version_pkg.vhd`: `SW_SUB` hochzählen (z. B. `'1'` → `'2'`).
2. `powershell -File scripts\release.ps1 -Note "was sich ändert"`
   → baut alle aktiven Boards und legt `bin/<BinFolder>/GottFA80_PLuS_v<BoardId><SW_SUB>.jic` ab,
   schreibt `bin/PLuS/changelog.txt` mit SHA-256 fort.
3. In `VARIANTEN.md` eintragen, welches Board **auf Hardware** getestet wurde.

## Die alten Projektordner

`GottFA80_PLuS_HW201_Cyclone_IV_v4`, `GottFA80_PLuS_HW21x_Cyclone_IV_v4`,
`GottFA80_PLuS_HW21x_Cyclone_10` liegen nur noch als Backup auf dem Netzlaufwerk und
sind seit 04.11.2026 nicht mehr im Repo. **Dort nicht mehr bauen oder ändern.**
HW201 baut dort ohnehin nicht mehr (siehe `VARIANTEN.md`).

Die GottFA80- und GottFA80S-Ordner nebenan sind (noch) eigenständige Projekte und
benutzen `lib_common/` direkt per `../lib_common`. **Eine Änderung in `lib_common/`
wirkt also auch dort.** Bestandsaufnahme: `docs/BESTANDSAUFNAHME_80_80S.md`.

## Fallstricke

- In Windows PowerShell 5.1 kein `2>&1` (und kein `*>`) auf `quartus_*.exe` bzw. auf
  Skripte, die es aufrufen – die TBBmalloc-Notiz auf stderr wird sonst zum Fehler.
- Textersetzungen nicht mit `sed -i` aus der Git-Bash (zerstört CRLF), sondern
  PowerShell `[System.IO.File]::WriteAllText` mit `UTF8Encoding($false)`.
- `else generate` gibt es in VHDL-93 nicht; Generate-Labels ändern Hierarchienamen,
  auf die die `.sdc` zeigt (`cpu_clk_gen:clock_gen|cpu_clk_out`).
