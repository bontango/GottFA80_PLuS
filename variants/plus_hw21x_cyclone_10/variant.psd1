@{
    Name        = 'plus_hw21x_cyclone_10'
    Title       = 'GottFA80 PLuS HW 2.1x mit Cyclone 10 Board (10CL006YE144C8G)'
    BoardId     = '61'           # zweistellig, steht auch in variant_pkg.vhd
    RtlFamily   = 'cyclone_10'      # welche files_<familie>.tcl (lib_cyclone_IV / lib_cyclone_10)
    Options     = @()
    BinFolder   = 'PLuS/HW2.1x/Cyclone_10'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @('Debug[1]', 'Debug[2]', 'FA_RXD', 'FA_TXD', 'FA_CTRL_REQ')
    Notes       = 'Ausgeliefert als GottFA80_PLuS_v611.jic. Pinout wie plus_hw21x_cyclone_iv bis auf 6 Lagen (U6_PA[0]/[3], DIP_Strobe[1]/[3], DIP_Return[2], disp_segments[14]).'
}
