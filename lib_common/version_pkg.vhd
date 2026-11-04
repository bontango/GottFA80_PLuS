-- version_pkg.vhd - Software-Ziffer, gemeinsam fuer alle PLuS-Varianten.
--
-- Angezeigte Version = BOARD_ID (variants\<n>\variant_pkg.vhd, zweistellig) & SW_SUB.
-- Ein Release aendert NUR diese Ziffer, alle Boards folgen:
--   HW2.01 Cyclone IV -> 50x, HW2.1x Cyclone IV -> 51x, HW2.1x Cyclone 10 -> 61x
--
-- Stand 04.11.2026: 1 (= ausgelieferte v501 / v511 / v611).
package version_pkg is
	constant SW_SUB : character := '1';
end package version_pkg;
