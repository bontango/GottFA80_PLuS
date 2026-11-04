@{
    Name        = 'plus_hw21x_cyclone_iv'
    Title       = 'GottFA80 PLuS HW 2.1x mit Cyclone IV Board (EP4CE6E22C8)'
    BoardId     = '51'           # zweistellig, steht auch in variant_pkg.vhd
    RtlFamily   = 'cyclone_iv'      # welche files_<familie>.tcl (lib_cyclone_IV / lib_cyclone_10)
    Options     = @()
    BinFolder   = 'PLuS/HW2.1x/Cyclone_IV'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @('Debug[1]', 'Debug[2]', 'FA_RXD', 'FA_TXD', 'FA_CTRL_REQ')
    Notes       = 'Ausgeliefert als GottFA80_PLuS_v511.jic. Nur Debug[0] (PIN_11) ist herausgefuehrt; PIN_7/PIN_2 sind hier Sound/Audio_RX (Korrektur v511).'
}
