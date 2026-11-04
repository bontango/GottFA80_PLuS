# device.tcl - was fuer DIESES Board gilt, ausser den Pinlagen.
# Wird von scripts\gen_qsf.ps1 in SYS80.qsf eingesetzt. Handgepflegt.
#
# Board v7 hat keinen JTAG-Stecker: programmiert wird ueber den ESP32 auf X7
# (FA-Control, Kachel 09 FPGA, oder POST /api/fpgaup). Release ist deshalb die .rbf.
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE6F17C8
set_global_assignment -name LAST_QUARTUS_VERSION "22.1std.2 Lite Edition"
set_global_assignment -name GENERATE_RBF_FILE ON
