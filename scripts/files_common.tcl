# files_common.tcl - Quellen, die JEDE Variante braucht.
# Pfade sind relativ zum Projektverzeichnis variants\<n>\.
# Kein SEARCH_PATH: jede Datei steht explizit hier - eine neue .vhd kann so nicht
# in einer Variante fehlen. Packages zuerst.
#
# lib_common\ wird (Stand 11/2026) auch von den noch nicht umgebauten
# GottFA80-/GottFA80S-Ordnern direkt per ../lib_common benutzt.
set_global_assignment -name VHDL_FILE ../../lib_common/T65/T65_Pack.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/version_pkg.vhd
set_global_assignment -name VHDL_FILE variant_pkg.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/uart_clk_gen.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/attract.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/dac.vhd
set_global_assignment -name VHDL_FILE "../../lib_common/Votrax-SC01.vhd"
set_global_assignment -name VHDL_FILE ../../lib_common/DFPlayer_Mini_CMD.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/GOSOF80.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/anti_thunk.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/EEprom.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/T65/T65_MCode.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/T65/T65_ALU.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/T65/T65.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/SPI_Master.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/SN74175.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/SN7448_GTB.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/SN7448.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/slow_to_fast_clock_bus.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/slow_to_fast_clock.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/SD_Card.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/read_the_dips.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/R6532.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/detect_sw_trigger.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/detect_sw.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/cpu_clk_gen.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/count_to_zero.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/byte_to_ascii.vhd
set_global_assignment -name VHDL_FILE ../../lib_common/boot_message.vhd
set_global_assignment -name VHDL_FILE ../../top/SYS80.vhd
set_global_assignment -name SDC_FILE ../../lib_common/SYS80.sdc
