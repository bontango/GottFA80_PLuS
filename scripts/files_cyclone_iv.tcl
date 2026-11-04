# files_cyclone_iv.tcl - Megafunctions der Familie (lib_cyclone_IV\).
# Die Wrapper unterscheiden sich zwischen den Familien nur im intended_device_family;
# die Entity-Namen sind identisch. Die .qip loesen ihre Pfade selbst auf (qip_path).
set_global_assignment -name QIP_FILE ../../lib_cyclone_IV/SYSTEM_ROM.qip
set_global_assignment -name QIP_FILE ../../lib_cyclone_IV/SB_RAM.qip
set_global_assignment -name QIP_FILE ../../lib_cyclone_IV/RIOT_RAM.qip
set_global_assignment -name QIP_FILE ../../lib_cyclone_IV/R5101.qip
set_global_assignment -name QIP_FILE ../../lib_cyclone_IV/GAME_ROM.qip
