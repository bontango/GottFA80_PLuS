-- variant_pkg.vhd - Konstanten der Variante plus_hw21x_cyclone_iv
-- GottFA80 PLuS HW 2.1x mit Cyclone IV Board (EP4CE6E22C8)
--
-- Anzeige der SW-Version beim Booten = BOARD_ID & SW_SUB (lib_common\version_pkg.vhd).
-- BOARD_ID ist zweistellig: 1. Ziffer FPGA-Board (5 = Cyclone IV v4, 6 = Cyclone 10,
-- 7 = Cyclone IV v7 mit ESP32), 2. Ziffer Platinenstand (0 = HW 2.0x, 1 = HW 2.1x).
package variant_pkg is
	constant BOARD_ID : string(1 to 2) := "51";
	-- ESP32-C3 mit FA-Control (lib_fa_control). Nur das Cyclone-IV-Board v7 traegt ihn.
	constant HAS_ESP32 : boolean := false;
	-- Integriertes Soundboard GOSOF80 (lib_common\GOSOF80.vhd).
	constant HAS_SOUNDBOARD : boolean := true;
end package variant_pkg;
