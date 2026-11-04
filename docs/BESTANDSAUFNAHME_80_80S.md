# Bestandsaufnahme GottFA80 / GottFA80S (Stand 04.11.2026)

Die PLuS-Varianten sind seit 04.11.2026 im gemeinsamen Sourcebaum (`top/`, `variants/plus_*`).
Die acht Projektordner der GottFA80 (SMD) und GottFA80S liegen noch flach daneben, sind
**nicht** im Git-Repo (Whitelist in `.gitignore`) und werden später umgebaut. Dieses
Dokument hält nur fest, was dort vorliegt – es wurde nichts geändert.

## Übersicht

| Ordner | Familie / Device | Anzeige | Top-Zeilen | Pins | `.sdc` | Release in `bin/` = `output_files`? | `.sof` vom |
|---|---|---|---|---|---|---|---|
| `GottFA80S_HW1.1_Cyclone_IV_v4` | Cyclone IV E `EP4CE6E22C8` | 501 | 939 | 88 | gemeinsam¹ | ja – `80S/HW_1.1/Cyclone_IV/GottFA80S_v501.jic` | 28.06.2025 |
| `GottFA80S_HW1.2_Cyclone_IV_v4` | Cyclone IV E `EP4CE6E22C8` | 512 | 946 | 85 | gemeinsam¹ | ja – `80S/HW_1.2/Cyclone_IV/GottFA80S_v512.jic` | 30.10.2026 |
| `GottFA80S_HW1.2_Cyclone_10` | Cyclone 10 LP `10CL006YE144C8G` | 612 | 946 | 85 | gemeinsam¹ | ja – `80S/HW_1.2/Cyclone_10/GottFA80S_v612.jic` | 06.12.2025 |
| `GottFA80_HW1.1SMD_Cyclone_IV_v4` | Cyclone IV E `EP4CE6E22C8` | 303 | 900 | 82 | **eigene**² | ja – `v110/GottFA80_v110_v303.jic` | 11.01.2026 |
| `GottFA80_HW1.1SMD_Cyclone_IV_v3` | Cyclone IV E `EP4CE6F17C8` | 203 | 859 | 82 | gemeinsam¹ | ja – `v110/GottFA80_v110_v203.jic` | 05.12.2025 |
| `GottFA80_HW1.1SMD_Cyclone_IV_v3_MPF` | Cyclone IV E `EP4CE6F17C8` | 203 | 859 | 82 | gemeinsam¹ | – (identisch zu v3) | 05.12.2025 |
| `GottFA80_HW1.1SMD_Cyclone_10` | Cyclone 10 LP `10CL006YE144C8G` | 403 | 862 | 82 | gemeinsam¹ | ja – `v110/GottFA80_v110_v403a.jic` | 02.08.2025 |
| `GottFA80_HW1.1SMD_Cyclone_II` | Cyclone II `EP2C5T144C8` | 103 | 833 | 82 | eigene | ja – `v110/GottFA80_v110_v103.pof` | 28.03.2026 |

¹ byte-gleich mit `lib_common/SYS80.sdc` (der PLuS-`.sdc`).
² wie ¹, nur ist `create_generated_clock … cpu_clk_out` auskommentiert – v4 erzeugt den
CPU-Takt über die PLL `lib_cyclone_IV/cpu_clock_gen` statt über `cpu_clk_gen`.

Alle `.jic`/`.pof` in `bin/` sind md5-gleich mit dem jeweiligen `output_files/` – die
ausgelieferten Stände sind also in den Ordnern reproduzierbar vorhanden (Baustand der
Quellen dabei aber nicht gesichert, siehe nächster Abschnitt).

Alle bis auf Cyclone II bauen mit Quartus 22.1std; Cyclone II braucht 13.0sp1 Web Edition
(dort wirkt `VIRTUAL_PIN` nicht – Warning 292013).

## Gefundene Probleme

1. **`GottFA80S_HW1.1_Cyclone_IV_v4` baut nicht mehr** – dieselbe Lücke wie beim
   PLuS-HW201: die `.qsf` listet `lib_common/GOSOF80.vhd`, aber nicht `attract.vhd` und
   `uart_clk_gen.vhd`, die GOSOF 3.97 (seit 28.06.2025) braucht. Belegt am 04.11.2026 per
   `quartus_map` auf einer Kopie: `Error (10481) … does not contain primary unit "attract"`.
   Gegenprobe `GottFA80S_HW1.2_Cyclone_IV_v4`: baut. Folge: das ausgelieferte 80S-`v501`
   enthält GOSOF 3.96, die 80S-HW1.2-Releases enthalten 3.97 mit Attract.
2. **`lib_common` ist schon geteilt, aber ohne Netz.** Jede Änderung dort wirkt sofort auf
   alle 7 Ordner, die es benutzen; geprüft wird das von niemandem. Genau so ist Punkt 1
   entstanden.
3. **Die 80S-`.qsf` listen `SYS80.vhd` nicht** (`VHDL_FILE`-Liste ohne Top-Level). Quartus
   findet die Datei, weil sie im Projektordner liegt und wie die Top-Entity heißt – das
   bricht beim Umzug in `variants/<n>/`.
4. Die Cyclone-II-Variante benutzt **lokale Kopien** der Module (`anti_thunk`, `T65`, `R6532`,
   …) statt `lib_common` (nur 3 von 22 Dateien aus `lib_common`) – ein eigener Altstand.
5. Absolute Pfade in `GottFA80S_HW1.2_Cyclone_IV_v4/sys80.cof`
   (`N:/Projekte/FPGA System80/FPGA_source/…/SYS80.sof`).

## Abstand zum PLuS-Top-Level (`top/SYS80.vhd`, Basis HW21x Cyclone IV)

Gezählte Diff-Zeilen gegen `GottFA80_PLuS_HW21x_Cyclone_IV_v4/SYS80.vhd`:

| Ordner | Zeilen | Was |
|---|---|---|
| 80S HW1.2 CIV / C10 | 32 | Port `Serial_RX/TX` statt `Debug`; PLuS hat 3-stellige Spielnummer (`game_dig2`) und Freeplay-Bit in `mybyte`, 80S zweistellig. CIV vs C10 untereinander: nur Version (512/612). |
| 80S HW1.1 CIV | 53 | dazu getrennte SPI-Ports für SD-Karte und EEPROM (`SDcard_MOSI/MISO/CLK`, `EEprom_MOSI/MISO/CLK`), Serial-Richtung vertauscht |
| 80 SMD CIV v3 / C10 | ~315 | kein Soundboard (kein GOSOF80/DFPlayer/Votrax/dac), `read_the_dips_80`, `LED_0..2` statt `LED_ON`, `DIP_Strobe(1..0)`/`DIP_Return(4..0)`; v3 vs C10 nur 7 Zeilen |
| 80 SMD CIV v4 | ~374 | wie v3, zusätzlich `boot_message_80B` und PLL `cpu_clock_gen`; v4 vs v3: 63 Zeilen |
| 80 SMD v3_MPF | – | `.vhd` und `.qsf` identisch zu v3; zusätzlich unbenutzte `lisy_api.vhd`, `lisy_test_api.vhd` im Ordner |

## Empfehlung für den späteren Umbau

- **80S HW1.2 (CIV + C10)**: kann direkt in den bestehenden Baum. Mit Platzhalter-Ports
  (`Serial_RX/TX` neben `Debug`, VIRTUAL_PIN) und einer Konstante für die 2-/3-stellige
  Spielnummer passt es sehr wahrscheinlich ins **selbe** `top/SYS80.vhd` – vorher klären,
  ob die 3-stellige Spielauswahl/Freeplay aus PLuS auch für 80S gewollt ist (dann ist es
  Angleichen, kein Generate).
- **80S HW1.1**: erst klären, ob noch gepflegt (`Dormant`?). Getrennte SPI-Busse sind ein
  echter Hardwareunterschied → Konstante `HAS_SHARED_SPI` + paarweises `generate`.
- **80 SMD**: zu weit weg für dasselbe Top-Level. Erst die vier 22.1-Ordner untereinander
  angleichen (Skill `fpga-varianten-angleichen`; v4 ist die Leitvariante?), dann eigenes
  `top/SYS80_80.vhd` oder `TopEntity` im selben Baum. Cyclone II bleibt mit lokalen Kopien
  und 13.0sp1 ein Sonderfall – ggf. `Generated = $false` oder `Dormant`.
- `version_pkg.vhd` ist heute PLuS-spezifisch (eine Ziffer). Für 80/80S entweder eigenes
  Package oder dieselbe Ziffer – Entscheidung beim Umbau.
- Vor jedem Umbau: Baseline wie bei PLuS, insbesondere prüfen, welcher Ordner heute
  überhaupt noch baut (Punkt 1).

## Aufräumkandidaten (nichts davon gelöscht)

- `lib_common/GOSOF80_096.vhd` (= `GOSOF80.vhd.bak`, GOSOF 3.96) – nur noch Referenz für
  die Reproduktion von PLuS v501 / 80S v501. Wird von keiner `.qsf` benutzt.
- `.bak`-Dateien in `lib_common/` (`EEprom`, `SD_Card`, `GOSOF80`, `DFPlayer_Mini_CMD`,
  `boot_message_80B`) – teils noch im Git-Index.
- In den Projektordnern je `SYS80.vhd.bak`, `*_old.vhd`, `SYS80_beta.vhd`, `SYS80_v202.vhd`,
  `SYS80_511.vhd`, `archive/` u. ä.
- `GottFA80_HW1.1SMD_Cyclone_IV_v3_MPF` – Duplikat von v3 plus zwei unbenutzte Dateien.
- `archive/` im Wurzelordner (alte Modulstände, `- Kopie`-Dateien).
