# files_cyclone_10.tcl - Megafunctions der Familie (lib_cyclone_10\).
# Die Wrapper unterscheiden sich zwischen den Familien nur im intended_device_family;
# die Entity-Namen sind identisch. Die .qip loesen ihre Pfade selbst auf (qip_path).
set_global_assignment -name QIP_FILE ../../lib_cyclone_10/SYSTEM_ROM.qip
set_global_assignment -name QIP_FILE ../../lib_cyclone_10/SB_RAM.qip
set_global_assignment -name QIP_FILE ../../lib_cyclone_10/RIOT_RAM.qip
set_global_assignment -name QIP_FILE ../../lib_cyclone_10/R5101.qip
set_global_assignment -name QIP_FILE ../../lib_cyclone_10/GAME_ROM.qip
