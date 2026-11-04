-- variant_pkg.vhd - Konstanten der Variante plus_hw21x_cyclone_iv
-- GottFA80 PLuS HW 2.1x mit Cyclone IV Board (EP4CE6E22C8)
--
-- Anzeige der SW-Version beim Booten = BOARD_ID & SW_SUB (lib_common\version_pkg.vhd).
-- BOARD_ID ist zweistellig: 1. Ziffer FPGA-Familie (5 = Cyclone IV, 6 = Cyclone 10),
-- 2. Ziffer Platinenstand (0 = HW 2.0x, 1 = HW 2.1x).
package variant_pkg is
	constant BOARD_ID : string(1 to 2) := "51";
end package variant_pkg;
