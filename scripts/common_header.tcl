# common_header.tcl - globale Assignments, die fuer JEDE Variante gelten.
# Wird von scripts\gen_qsf.ps1 in variants\<n>\SYS80.qsf eingesetzt.
# Uebernommen am 04.11.2026 aus GottFA80_PLuS_HW21x_Cyclone_IV_v4\SYS80.qsf
# (in allen drei PLuS-Varianten identisch).
#
# NICHT hierher gehoeren:
#   FAMILY / DEVICE / LAST_QUARTUS_VERSION -> variants\<n>\device.tcl
#   TOP_LEVEL_ENTITY                       -> schreibt gen_qsf.ps1 selbst
#   Pinlagen                               -> variants\<n>\pins.tcl
#   Quelldateien                           -> scripts\files_*.tcl
set_global_assignment -name ORIGINAL_QUARTUS_VERSION "13.0 SP1"
set_global_assignment -name PROJECT_CREATION_TIME_DATE "17:45:57  APRIL 01, 2020"
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 1
set_global_assignment -name USE_CONFIGURATION_DEVICE ON
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top
set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top
set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_ASDO_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name POWER_PRESET_COOLING_SOLUTION "23 MM HEAT SINK WITH 200 LFPM AIRFLOW"
set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to reset_sw
set_global_assignment -name RESERVE_ALL_UNUSED_PINS_NO_OUTPUT_GND "AS INPUT TRI-STATED"
set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top
