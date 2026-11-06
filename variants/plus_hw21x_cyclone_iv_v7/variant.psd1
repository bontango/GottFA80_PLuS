@{
    Name        = 'plus_hw21x_cyclone_iv_v7'
    Title       = 'GottFA80 PLuS HW 2.1x mit Cyclone IV Board v7 (EP4CE6F17C8, ESP32-C3 auf X7)'
    BoardId     = '71'           # zweistellig, steht auch in variant_pkg.vhd
    RtlFamily   = 'cyclone_iv'
    Options     = @()
    BinFolder   = 'PLuS/HW2.1x/Cyclone_IV_v7'
    # Board v7 hat keinen JTAG-Stecker; die .rbf (GENERATE_RBF_FILE in device.tcl)
    # wird ueber den ESP32 geschrieben. build.ps1 prueft, dass sie frisch ist.
    ReleaseArtifact = 'rbf'
    Dormant     = $false
    # Debug[1..2] wie auf HW2.1x nicht herausgefuehrt; FA_* liegen auf echten Pins.
    VirtualPins = @('Debug[1]', 'Debug[2]')
    Notes       = 'Neu 04.11.2026: FA-Control (HAS_ESP32) statt integriertem Soundboard (HAS_SOUNDBOARD = false). Pinout aus plus_hw21x_cyclone_iv ueber pins_Cyclone_II_IV_10.xlsx umgesetzt. Hardwaregetestet 06.11.2026 (Ralf): Connect/Release, Monitor-Displays, Namensdateien GottFA80. Erstes Release v711 (.rbf).'
}
