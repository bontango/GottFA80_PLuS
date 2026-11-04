-- VHDL implementation of a System80/80A/80B Gottlieb MPU
-- (c)2020 bontango
--
-- This is free software: you can redistribute
-- it and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This is distributed in the hope that it will
-- be useful, but WITHOUT ANY WARRANTY; without even the
-- implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE. See the GNU General Public License
-- for more details.
--
-- Changelog:
-- initial release for GottFA80_PLuS v2.0 based on GottFA80S V501
--
-- for FPGA v3 changes: shared SPI; no Serial
-- v510 inital version for HW 2.1x EP4CE6F17C8
-- v511 output ports corrected for sound/audio_rx
--
-- 04.11.2026 gemeinsamer Sourcebaum: dieses EINE Top-Level gilt fuer alle
-- PLuS-Varianten (variants\plus_*). Board-Unterschiede stehen in
-- variants\<n>\variant_pkg.vhd (BOARD_ID) und pins.tcl, die SW-Ziffer in
-- lib_common\version_pkg.vhd. Anzeige = BOARD_ID & SW_SUB (z.B. "51" & '1').
-- Debug ist jetzt 3 Bit breit (wie HW2.01); HW2.1x fuehrt nur Debug[0] heraus,
-- Debug[1..2] sind dort VIRTUAL_PIN.
--
-- 04.11.2026 Variante plus_hw21x_cyclone_iv_v7 (Cyclone-IV-Board v7 mit ESP32-C3):
-- FA-Control (lib_fa_control, aus SternFA) ueber HAS_ESP32, dafuer ohne integriertes
-- Soundboard (HAS_SOUNDBOARD = false) - beides passt nicht zusammen in den EP4CE6.
-- Ohne ESP ist fa_active konstant '0'; alle Muxe unten fallen dann weg.

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.version_pkg.all;
use work.variant_pkg.all;
use work.fa_control_pkg.all;	-- fa_nibble_array_t, lib_fa_control/

entity SYS80 is
	port(
	   -- the FPGA board
		clk_50	: in std_logic;
		reset_sw	: in std_logic;
		LED_Int 	: out STD_LOGIC;
		LED_SDcard 	: out STD_LOGIC;
		LED_ON 	: out STD_LOGIC;

		-- U4 switchmatrix 8strobe; 8 returns
		U4_PB	:	buffer 	std_logic_vector(7 downto 0);
		U4_PA	:	in 	std_logic_vector(7 downto 0);
		
		-- U5 displays  		
		-- 24 Segments ( seperate because of 80B ) J2 1..24
		-- U5_PB 0..6 & U5_PA 4..6
		disp_segments 	: out 	std_logic_vector(1 to 24);				
		U5_PA				: out std_logic_vector(3 downto 0); -- 16 strobes via decoder
		U5_PA_7			: in std_logic; -- Slam
		U5_PB_7			: out std_logic; -- Switch Enable
		
		-- Solenoids, Lamps & Sound
		U6_PA		: out std_logic_vector(7 downto 0); -- Sols & Sound 8 signals combined			
		U6_PB		: out std_logic_vector(7 downto 0);-- Lamps ( 4 control, 4 latch strobes)		
		
		-- SPI SD card & EEprom
		CS_SDcard	: 	buffer 	std_logic;
		CS_EEprom	: 	buffer 	std_logic;
		MOSI			: 	out 	std_logic;
		MISO			: 	in 	std_logic;
		CLK			: 	out 	std_logic;
		
		-- DIp Switch Game selectOptions
		DIP_Strobe	:	out 	std_logic_vector(3 downto 0);
		DIP_Return	:	in 	std_logic_vector(3 downto 0);
		myTest		: 	in 	std_logic;
		
		-- Sound
		Audio_RX			: 	buffer 	std_logic;
		Sound 			: 	buffer 	std_logic;

		-- debug
		Debug			:	out 	std_logic_vector(2 downto 0);

		-- FA-Control: ESP32-C3 auf X7 des Cyclone-IV-Boards v7 (HAS_ESP32).
		-- Auf allen anderen Boards VIRTUAL_PIN (variant.psd1).
		FA_RXD			:	in		std_logic;	-- R3, vom TX des ESP
		FA_TXD			:	out	std_logic;	-- T2, zum RX des ESP
		FA_CTRL_REQ		:	in		std_logic	-- N3, active low, Weak-Pull-up

		);
end SYS80;


architecture rtl of SYS80 is

signal cpu_clk		: std_logic; -- 895 kHz CPU clock
signal reset_l	 	: std_logic := '0';
signal reset_sw_stable	:	std_logic; 
signal Counter : integer range 0 to 15 := 0;

-- CPU 6502
signal cpu_addr		: std_logic_vector(15 downto 0);
signal cpu_din			: std_logic_vector(7 downto 0);
signal cpu_dout		: std_logic_vector(7 downto 0);
signal cpu_wr_n		: std_logic := '1';
signal phi2				: std_logic;
signal cpu_irq_n		: std_logic;

--  5101 RAM
signal r5101_dout_4bit 	: std_logic_vector(3 downto 0);	  
signal r5101_dout_8bit 	: std_logic_vector(7 downto 0);	  
signal r5101_cs		: std_logic;

-- ROM
signal game_rom_dout  : std_logic_vector(7 downto 0);
signal game_rom2_dout  : std_logic_vector(7 downto 0);
signal system_rom_dout  : std_logic_vector(7 downto 0);

-- RIOT U4 Switch Matrix
signal U4_RAM_cs  		: std_logic;
signal U4_IO_cs  			: std_logic;
signal U4_RAM_dout		: std_logic_vector(7 downto 0);
signal U4_IO_dout			: std_logic_vector(7 downto 0);
signal U4_pa_in			: std_logic_vector(7 downto 0);
signal SW_Freeplay		: std_logic_vector(7 downto 0):="00000000";
--signal U4_pa_out		: std_logic_vector(7 downto 0);
--signal U4_pb_in			: std_logic_vector(7 downto 0);
--signal U4_pb_out			: std_logic_vector(7 downto 0);
signal U4_irq_n			: std_logic;

-- trigger
signal game_over_relay			: std_logic;
signal clk_Z1			: std_logic;
signal clk_Z3			: std_logic;
signal test_sw			: std_logic;
signal credit_sw			: std_logic;


-- RIOT U5 Display Control
signal U5_RAM_cs  		: std_logic;
signal U5_IO_cs  			: std_logic;
signal U5_RAM_dout		: std_logic_vector(7 downto 0);
signal U5_IO_dout			: std_logic_vector(7 downto 0);
--signal U5_pa_in			: std_logic_vector(7 downto 0):="11111111";
signal U5_pa_out		: std_logic_vector(7 downto 0);
--signal U5_pb_in			: std_logic_vector(7 downto 0);
signal U5_pb_out			: std_logic_vector(7 downto 0);
signal U5_irq_n			: std_logic;
signal not80B				: std_logic:='0'; --default we have 80B system
signal segments_80B 		: std_logic_vector(1 to 24);				
signal segments_80 		: std_logic_vector(1 to 24);			
signal bm_segments 		: std_logic_vector(1 to 24);			
signal Din_Seg_A			: std_logic_vector(3 downto 0);	
signal Din_Seg_B			: std_logic_vector(3 downto 0);	
signal Din_Seg_C			: std_logic_vector(3 downto 0);	
signal bm_digit_strobe	: std_logic_vector(3 downto 0);	
			
-- RIOT U& Solenoid & Lamp Control
signal U6_RAM_cs  		: std_logic;
signal U6_IO_cs  			: std_logic;
signal U6_RAM_dout		: std_logic_vector(7 downto 0);
signal U6_IO_dout			: std_logic_vector(7 downto 0);
--signal U6_pa_in			: std_logic_vector(7 downto 0);
signal U6_pa_out		: std_logic_vector(7 downto 0);
--signal U6_pb_in			: std_logic_vector(7 downto 0);
signal U6_pb_out			: std_logic_vector(7 downto 0);
signal U6_irq_n			: std_logic;

-- address decoding helper
signal game_rom_cs		: std_logic;
signal game_rom2_cs		: std_logic;
signal game_rom_addr	:  std_logic_vector(10 downto 0);
signal game_rom2_addr	:  std_logic_vector(10 downto 0);
signal system_rom_cs		: std_logic;
signal system_rom_addr	:  std_logic_vector(12 downto 0);

-- SD card
signal address_sd_card	:  std_logic_vector(13 downto 0);
signal data_sd_card	:  std_logic_vector(7 downto 0);
signal wr_rom			:  std_logic;
signal wr_game_rom			:  std_logic;
signal wr_game_rom2			:  std_logic;
signal wr_system_rom			:  std_logic;
signal SDcard_MOSI	:	std_logic; 
signal SDcard_CLK		:	std_logic; 
signal SDcard_error	:	std_logic; 

-- EEprom we use 128Bytes
signal address_eeprom	:  std_logic_vector(6 downto 0);
signal data_eeprom	:  std_logic_vector(7 downto 0);
signal wr_ram			:  std_logic;
signal EEprom_MOSI	:	std_logic; 
signal EEprom_CLK		:	std_logic; 
signal EEprom_active	:	std_logic; 

-- init & boot message helper
signal game_running		: 	std_logic:= '0';
signal game_dig0			:  character;
signal game_dig1			:  character;
signal game_dig2			:  character;
signal g_opt_dig0			:  character;
signal g_opt_dig1			:  character;
signal sb_opt_dig0			:  character;
signal sb_opt_dig1			:  character;

-- dip games select and options
signal readingdips	: 	std_logic:= '1';
signal game_select 		:  std_logic_vector(5 downto 0);				
signal game_option		: 	std_logic_vector(1 to 6);
signal sb_option		: 	std_logic_vector(1 to 4);
		
-- diff
signal sim_coin		: 	std_logic:= '0';
signal slam				: 	std_logic;
signal lamp_ds 		:  std_logic_vector(3 downto 0);		
signal late80B			: std_logic:='0'; --default we have not a late 80B system with bigger rom

-- game options
signal opt_freeplay				: 	std_logic;
signal opt_init_nvram				: 	std_logic;
signal opt_slam_fix_open			: 	std_logic;
signal opt_slam_fix_close		: 	std_logic;

-- soundboard
-- ROM
signal soundrom1_dout	:	std_logic_vector(7 downto 0);
signal soundrom2_dout	: 	std_logic_vector(7 downto 0);	
	
signal 	Sound_S1			: std_logic;
signal 	Sound_S2			: std_logic;
signal 	Sound_S4			: std_logic;
signal 	Sound_S8			: std_logic;
signal 	Sound_S16		: std_logic;
	
-- address decoding helper
signal soundrom1_cs		: std_logic;
signal soundrom2_cs		: std_logic;
signal sb_rom1_addr	:  std_logic_vector(10 downto 0);
signal sb_rom2_addr	:  std_logic_vector(10 downto 0);
signal soundrom1_addr	:  std_logic_vector(10 downto 0);
signal soundrom2_addr	:  std_logic_vector(10 downto 0);
signal wr_soundrom1		: std_logic;
signal wr_soundrom2		: std_logic;

------------------------------------------------------------------------------
-- FA-Control (lib_fa_control). Nummerierung wie LISY80 (lisy80.c):
--   Lampen 0..47  = Transistor Q1..Q48: Q = 4*(FEED-1) + LD-Bit, FEED 1..12 auf
--                   U6 PB7..4, LD1..4 auf U6 PB3..0 (Q1 Game-Over-Relais, Q2 Tilt,
--                   Q3 Muenzsperre, Sound16 = Q10 bei 80/80A, Q5 bei 80B).
--   Spulen 1..9   = SOL1..9: zwei 74LS139 an U6 PA (AB1 = PA1..0, AB2 = PA3..2,
--                   I1G = PA5, I2G = PA6, low aktiv; AB 3/2/1/0 = SOL1/2/3/4 bzw.
--                   5/6/7/8) und SOL9 = PA7 (Spule an bei PA7 = '0').
--                   Je Decoder kann nur EINE Spule gleichzeitig an sein.
--   Schalter      = 10 * (U4 PB-Bit) + (U4 PA-Bit), 0..77, N_SW = 78 mit Luecken.
--                   Test = 07, Replay/Credit = 47 wie in LISY80.
--   Sound 0..15   = U6 PA3..0 negiert bei PA4 = '0' (Z31). Waehrend ein Sound
--                   ansteht, sind die Spulendecoder abgeschaltet (gemeinsame Leitungen).
--   Displays 1..4 = Spieler, 7 Stellen, ueber boot_message (nur 80/80A, BCD).
--                   Display 0 (Status) wird angenommen, aber nicht angezeigt.
-- fa_u6a/fa_u6b haben die Bedeutung der RIOT-Ports (vor den Invertern unten),
-- damit die Ausgangspfade dieselben bleiben wie im Spiel.
------------------------------------------------------------------------------
constant FA_N_LAMPS	: integer := 48;
constant FA_N_SOL		: integer := 9;
constant FA_N_SW		: integer := 78;
constant FA_N_DISP	: integer := 5;
constant FA_DIGITS	: integer := 7;
signal fa_active		: std_logic;
signal fa_sw_state	: std_logic_vector(FA_N_SW - 1 downto 0) := (others => '0');
signal fa_lamp_ovr	: std_logic_vector(FA_N_LAMPS - 1 downto 0);
signal fa_sol_ovr		: std_logic_vector(FA_N_SOL - 1 downto 0);
signal fa_disp_ovr	: fa_nibble_array_t(0 to FA_N_DISP * FA_DIGITS - 1);
signal fa_snd_ovr		: std_logic_vector(3 downto 0);
signal fa_snd_en		: std_logic;
signal fa_u6a			: std_logic_vector(7 downto 0);
signal fa_u6b			: std_logic_vector(7 downto 0);
signal fa_sw_strobe	: std_logic_vector(7 downto 0);
signal fa_disp1		: string(1 to 7);
signal fa_disp2		: string(1 to 7);
signal fa_disp3		: string(1 to 7);
signal fa_disp4		: string(1 to 7);
signal u4_pb_out		: std_logic_vector(7 downto 0);
signal fa_sim_ret		: std_logic_vector(7 downto 0);	-- simulierte Schalter der gestrobten Spalte
signal bm_display1	: string(1 to 7);
signal bm_display2	: string(1 to 7);
signal bm_display3	: string(1 to 7);
signal bm_display4	: string(1 to 7);
signal bm_error4		: string(1 to 7);


begin

-- LEDs GottFA80
LED_Int <= not game_running;
LED_SDcard <= SDcard_error;
LED_ON <= '0'; --RTH

-- Debug war bisher nie zugewiesen (Warning 10541, implizit '0'); jetzt explizit.
Debug <= (others => '0');


----------------------
-- assign options
----------------------
opt_freeplay				<= not game_option(1);
opt_init_nvram				<= not game_option(2);
opt_slam_fix_open			<= not game_option(3);
opt_slam_fix_close		<= not game_option(4);


----------------------
-- boot message
----------------------
BM: entity work.boot_message
port map(
	clk_in		=> cpu_clk, 	
	-- Control/Data Signals,
   show  => (not game_running) or fa_active,
	SD_error => not SDcard_error,
	-- output
	bm_digit_strobe	=> bm_digit_strobe,
	bm_segments => bm_segments,
	-- input (display data); unter FA-Control die Ziffern des Hosts
	display1	=> bm_display1,
	display2	=> bm_display2,
	display3	=> bm_display3,
	display4	=> bm_display4,
	error_disp4 => bm_error4,
	status_d	=> "       "
	);

bm_display1 <= fa_disp1 when fa_active = '1' else "    " & BOARD_ID & SW_SUB;  -- SW VERSION: variant_pkg + version_pkg
bm_display2 <= fa_disp2 when fa_active = '1' else "    " & game_dig2 & game_dig1 & game_dig0;
bm_display3 <= fa_disp3 when fa_active = '1' else " 050963";
bm_display4 <= fa_disp4 when fa_active = '1' else " " & g_opt_dig1 & g_opt_dig0 & "  " & sb_opt_dig1 & sb_opt_dig0;
bm_error4   <= fa_disp4 when fa_active = '1' else "0000000";
	
----------------------
-- try anti thunk at boot
----------------------
AT: entity work.anti_thunk
port map(
	clk_in		=> cpu_clk, 	
	-- Control/Data Signals,
   is_active  => not game_running,
	-- output
	lamp_ds => lamp_ds
	);
	
----------------------
-- read the dips
----------------------
RDIPS: entity work.read_the_dips
port map(
	clk_in		=> cpu_clk, 	
	i_Rst_L  => reset_sw_stable,     -- FPGA Reset   
   readingdips	=> readingdips,
	--output 
	game_select	=> game_select,
	game_option	=> game_option,
	sb_option => sb_option,
	-- strobes
	strobes => DIP_Strobe,
	-- returns
	returns => DIP_Return
	);
	

CONVG: entity work.byte_to_ascii
port map(
	clk_in	=> clk_50, 		
	mybyte	=> "1" & not opt_freeplay & game_select,
	dig0_ascii => game_dig0,
	dig1_ascii => game_dig1,
	dig2_ascii => game_dig2
	);
	
CONVO: entity work.byte_to_ascii
port map(
	clk_in	=> clk_50, 		
	mybyte	=> "11" & game_option(6) & game_option(5) & game_option(4) & game_option(3) & game_option(2) & game_option(1),
	dig0_ascii => g_opt_dig0,
	dig1_ascii => g_opt_dig1,
	dig2_ascii => open
	);
	
CONVS: entity work.byte_to_ascii
port map(
	clk_in	=> clk_50, 		
	mybyte	=> "1111" & sb_option(4) & sb_option(3) & sb_option(2) & sb_option(1),
	dig0_ascii => sb_opt_dig0,
	dig1_ascii => sb_opt_dig1,
	dig2_ascii => open
	);
		
-- RIOT IRQ outputs all assert CPU IRQ input
cpu_irq_n <= U4_irq_n and U5_irq_n and U6_irq_n;		
--cpu_irq_n <= '1';

-- general assigments
phi2 <= not cpu_clk;

-- slam
slam <= '0' when opt_slam_fix_open = '1' else --slam open for late 80B games
		  '1' when opt_slam_fix_close = '1' else -- slam fix closed
		  U5_PA_7; --real slam

---------------------
-- shared SPI bus
----------------------
--SD card only at start of game
MOSI <= SDcard_MOSI when reset_l = '0' else EEprom_MOSI;
CLK <= SDcard_CLK when reset_l = '0' else EEprom_CLK;

---------------------
-- count ints
-- indicate game running or not
---------------------
COUNT_INTS: entity work.count_to_zero
port map(   
   Clock => clk_50,
	count =>"11111111",
	d_in => cpu_irq_n,
	d_out => game_running,
	clear => reset_l
	);
 
---------------------
-- detection game over relay (Q1)
----------------------
clk_Z1 <= '1' when U6_pb_out(7 downto 4) = "0001" else '0'; --DS1

sn74175_Game_O: entity work.sn74175 
port map(   
   Clock => clk_50,
	clk => clk_Z1,
	clear	=> '1',
	D => U6_pb_out(3 downto 0),
	Q => open,
	Qn(0) => game_over_relay
);

 
---------------------
-- SD card stuff
----------------------
SD_CARD: entity work.SD_Card
port map(
	--no_of_sectors => x"20", -- 32 sectors per rom
	--
	i_clk		=> clk_50,	
	-- Control/Data Signals,
   i_Rst_L  => not readingdips,     -- FPGA Reset & dip read finished
	-- PMOD SPI Interface
   o_SPI_Clk  => SDcard_CLK,
   i_SPI_MISO => MISO,
   o_SPI_MOSI => SDcard_MOSI,
   o_SPI_CS_n => CS_SDcard,	
	-- selection
	selection => "0" & opt_freeplay & not game_select,
	-- data
	address_sd_card => address_sd_card,
	data_sd_card => data_sd_card,
	wr_rom => wr_rom,
	-- control CPU
	cpu_reset_l => reset_l,
	-- feedback
	SDcard_error => SDcard_error
	);	
	
------------------
-- ROMs ----------
-- moved to RAM, initial 16KByte read from SD
-- one file of 16Kbyte for all Gottlieb Variants
-- one file of 16Kbyte for all Gottlieb Variants
-- lower half is game rom and need to be copied to 8KByte blocks
-- upper half is system rom
-- need to be mapped to MPU memory  address range
------------------
					
-- address selection	
-- read from SD when wr_rom == 1
-- else map to address room

-- content of game rom is read from first 2K of SD
wr_game_rom <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="000" )) else '0';
game_rom_addr <=  --2K
	address_sd_card(10 downto 0) when wr_game_rom = '1' else
	cpu_addr(10 downto 0);

-- content of extended game rom (late 80B games) is read from second 2K of SD
wr_game_rom2 <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="001" )) else '0';
game_rom2_addr <=  --2K
	address_sd_card(10 downto 0) when wr_game_rom2 = '1' else
	cpu_addr(10 downto 0);
		
-- content of sound rom 1 is read from third 2K of SD
wr_soundrom1 <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="010" )) else '0';
sb_rom1_addr <=  --2K
	address_sd_card(10 downto 0) when wr_soundrom1 = '1' else soundrom1_addr;

-- content of sound rom 2 is read from fourth 2K of SD
wr_soundrom2 <= '1' when ((wr_rom='1') and (address_sd_card(13 downto 11) ="011" )) else '0';
sb_rom2_addr <=  --2K
	address_sd_card(10 downto 0) when wr_soundrom2 = '1' else soundrom2_addr;
	
-- content of system rom is read from second 8K of SD	
wr_system_rom <= '1' when ((wr_rom='1') and (address_sd_card(13) = '1' )) else '0';
system_rom_addr <= --8K
	address_sd_card(12 downto 0) when wr_system_rom = '1' else
	cpu_addr(12 downto 0);

	
-- Address decoding here, 
-- 0x0000-0x07FF	RIOTS RAM and I/O
-- used: A13 | A12 | A11 | A10 | A9 | A8 | A7
--         0x800 blocks  | n.u.|rs_n|  RIOT sel
--
-- U4 Memory (RIOT) - 0x0000 - 0x007F
U4_RAM_cs 	<= '1' when cpu_addr(13 downto 7) ="0000000" else '0';
-- U5 Memory (RIOT) - 0x0080 - 0x00FF
U5_RAM_cs 	<= '1' when cpu_addr(13 downto 7) ="0000001" else '0';
-- U6 Memory (RIOT) - 0x0100 - 0x017F
U6_RAM_cs 	<= '1' when cpu_addr(13 downto 7) ="0000010" else '0';
-- Not Used - 0x0180 - 0x01FF (Test Fixture)
--
-- U4 Registers - 0x0200 - 0x027F
U4_IO_cs 	<= '1' when cpu_addr(13 downto 7) ="0000100" else '0';
-- U5 Registers - 0x0280 - 0x02FF
U5_IO_cs 	<= '1' when cpu_addr(13 downto 7) ="0000101" else '0';
-- U6 Registers - 0x0300 - 0x037F
U6_IO_cs 	<= '1' when cpu_addr(13 downto 7) ="0000110" else '0';
-- 0x0800-0x0FFF	"001" not used
--
-- 0x1000-0x17FF	"010" Game Rom
game_rom_cs	<= '1' when cpu_addr(13 downto 11) ="010" else '0';
-- 0x1800-0x1FFF	"011" Z5 (5101)
r5101_cs <= '1' when cpu_addr(13 downto 11) ="011" else '0';	
-- 0x2000-0x27FF	"100" SYSTEM ROM
-- 0x2800-0x2FFF	"101" SYSTEM ROM
-- 0x3000-0x37FF	"110" SYSTEM ROM
-- 0x3800-0x3FFF	"111" SYSTEM ROM
system_rom_cs <= cpu_addr(13);
-- late 80B games only when selected
late80B <= '1' when game_select(5 downto 3) = "000" else '0'; --all games after Robo War (GAME SELECT IS NEGATED)
game_rom2_cs	<= '1' when cpu_addr(13 downto 11) ="010" and cpu_addr(15) = '1' and late80B='1' else '0';


-- Bus control
cpu_din <= 
	game_rom2_dout when game_rom2_cs='1' else -- late 80B overwrites selection 
	U4_RAM_dout when U4_RAM_cs='1' else
	U5_RAM_dout when U5_RAM_cs='1' else
	U6_RAM_dout when U6_RAM_cs='1' else
	U4_IO_dout when U4_IO_cs='1'  else
	U5_IO_dout when U5_IO_cs='1'  else
	U6_IO_dout when U6_IO_cs='1'  else		
	game_rom_dout when game_rom_cs='1' else
	--"1111" & r5101_dout_4bit when r5101_cs='1' else	
	cpu_dout(7 downto 4) & r5101_dout_4bit when r5101_cs='1' else	
	system_rom_dout when system_rom_cs='1' else
	x"FF";

---------------------
-- U4
-- Switches
----------------------
META2: entity work.Cross_Slow_To_Fast_Clock_Bus
port map(
   i_D => U4_PA,
	o_Q => U4_pa_in,
   i_Fast_Clk => cpu_clk
	);

-- simulate left coin ( strobe 1 / return 7 )
Freeplay: process(sim_coin, U4_PB, opt_freeplay)
 begin 
    if (( sim_coin = '1') and (U4_PB(1) = '1') and (opt_freeplay = '1')) then
		SW_Freeplay(7) <= '1';
	 else	
		SW_Freeplay(7) <= '0';
	end if;	
 end process;  
	
-- detect credit and test_switch for trigger
-- due to iverters on the borad switch is active when both strobe and return are HIGH
-- switch enable for dips need to be low, Gottlieb does check dips when not in game!?
--credit_sw <=   U4_pa_in(7) and U4_PB(4) and not U5_pb_out(7);  -- credit switch is strobe 4 and return 7 and not dip switch active
detect_credit_sw_trigger: entity work.detect_sw_trigger
port map(
	clk    => cpu_clk,
	sw_strobe => U4_PB(4),
	sw_return => U4_pa_in(7),
	sw_enable => U5_pb_out(7),
	trigger => credit_sw,	
	rst 	=> game_running
);

detect_credit_sw: entity work.detect_sw
port map(
	clk    => cpu_clk,
	sw_strobe => U4_PB(4),
	sw_return => U4_pa_in(7),
	sw_enable => U5_pb_out(7),
	short_push => open,
	long_push => sim_coin,
	rst 	=> game_running
);

--test_sw   <= 	U4_pa_in(7) and U4_PB(0) and not U5_pb_out(7); -- test switch is strobe 0 and return 7 and not dip switch active
detect_test_sw: entity work.detect_sw
port map(
	clk    => cpu_clk,
	sw_strobe => U4_PB(0),
	sw_return => U4_pa_in(7),
	sw_enable => U5_pb_out(7),
	short_push => test_sw,
	long_push => open,
	rst 	=> game_running
);

--------------------------------------------------
-- U5
-- display 
--------------------------------------------------
U5_PB_7 <= '1' when fa_active = '1' else not U5_pb_out(7); --switch enable (FA: Matrix, keine DIPs)

-- determine if we have a 80B system -> no strobes on U5 PA0 .. PA3
COUNT_STROBES: entity work.count_to_zero
port map(   
   Clock => clk_50,
	count =>"00001111",
	d_in => U5_pa_out(1), --count only one of  signals				   
	d_out => not80B,
	clear => reset_l
	);

--------------------------------------------------
-- 80B display routines	
--------------------------------------------------
segments_80B(8) <= not U5_pb_out(4); --LD1
segments_80B(16) <= not U5_pb_out(5); --LD2
segments_80B(24) <= not U5_pb_out(6); --Reset
-- D0 ... D4
sn74175_80B_1: entity work.sn74175 
port map(   
   Clock => clk_50,
	clk => U5_pa_out(4),
	clear	=> reset_l,
	D => not U5_pb_out(3 downto 0),
	Q => open,
	Qn(0) => segments_80B(2),
	Qn(1) => segments_80B(6),
	Qn(2) => segments_80B(7),
	Qn(3) => segments_80B(1)
);
sn74175_80B_2: entity work.sn74175 
port map(   
   Clock => clk_50,
	clk => U5_pa_out(5),
	clear	=> reset_l,
	D => not U5_pb_out(3 downto 0),
	Q => open,
	Qn(0) => segments_80B(10),
	Qn(1) => segments_80B(14),
	Qn(2) => segments_80B(15),
	Qn(3) => segments_80B(9)
);

--------------------------------------------------
-- 80/80A display routines	
--------------------------------------------------
--digit strobes
U5_PA(3 downto 0) <= U5_pa_out(3 downto 0) when game_running='1' and fa_active='0' else bm_digit_strobe;

-- assign display segments dependent on display type		
disp_segments <= 
--	segments_80B when not80B = '0' else	
--	bm_segments when game_running = '0' else --and U5_pb_out(6) = '1' else  --RTH
--	segments_80;
	bm_segments when ( game_running = '0' and U5_pb_out(6) = '1') or SDcard_error = '0' or fa_active = '1' else  --RTH
	segments_80 when not80B = '1' else
   segments_80B;	

	
--segments
sn74175_80_1: entity work.sn74175 
port map(   
	Clock => clk_50,
	clk => U5_pa_out(4),
	clear	=> '1',
	D => not U5_pb_out(3 downto 0),
	Q => open,
	Qn => Din_Seg_A
);
sn74175_80_2: entity work.sn74175 
port map(   
	Clock => clk_50,
	clk => U5_pa_out(5),
	clear	=> '1',
	D => not U5_pb_out(3 downto 0),
	Q => open,
	Qn => Din_Seg_B
);
sn74175_80_3: entity work.sn74175 
port map(   
	Clock => clk_50,
	clk => U5_pa_out(6),
	clear	=> '1',
	D => not U5_pb_out(3 downto 0),
	Q => open,
	Qn => Din_Seg_C
);


sn7448_1: entity work.sn7448
port map(   
	Din 	=> Din_Seg_A,
	Dout  => segments_80(1 to 7)
);
segments_80(8) <= not U5_pb_out(4);

sn7448_2: entity work.sn7448
port map(   
	Din 	=> Din_Seg_B,
	Dout  => segments_80(9 to 15)
);
segments_80(16) <= not U5_pb_out(5);

sn7448_3: entity work.sn7448
port map(   
	Din 	=> Din_Seg_C,
	Dout  => segments_80(17 to 23)
);
segments_80(24) <= not U5_pb_out(6);


--------------------------------------------------
-- solenoids & lamps
--------------------------------------------------
-- unter FA-Control dieselben Pfade, gespeist aus fa_u6a/fa_u6b (RIOT-Bedeutung)
U6_PA(4 downto 0) <= not fa_u6a(4 downto 0) when fa_active='1' else
                     not U6_pa_out(4 downto 0) when game_running='1' else "00000"; --sound AND Z31
U6_PA(7 downto 5) <= fa_u6a(7 downto 5) when fa_active='1' else
                     U6_pa_out(7 downto 5) when game_running='1' else "111"; -- decoder enable and Sol9
U6_PB(3 downto 0) <= not fa_u6b(3 downto 0) when fa_active='1' else
                     not U6_pb_out(3 downto 0) when game_running='1' else "1111"; -- thunk prevention (inverter)
U6_PB(7 downto 4) <= fa_u6b(7 downto 4) when fa_active='1' else
                     U6_pb_out(7 downto 4)when reset_l='1' else lamp_ds; -- thunk prevention
	
-- cpu clock 892Khz
clock_gen: entity work.cpu_clk_gen 
port map(   
	clk_in => clk_50,
	cpu_clk_out	=> cpu_clk
);


U1: entity work.T65 -- 6502 
port map(
	Mode    			=> "00",
	Res_n   			=> reset_l and not fa_active,	-- FA-Control haelt die CPU an
	Enable  			=> '1',
	Clk     			=> cpu_clk,
	Rdy     			=> '1',
	Abort_n 			=> '1',
	IRQ_n   			=> cpu_irq_n,
	NMI_n   			=> '1',
	SO_n    			=> '1',
	R_W_n 			=> cpu_wr_n,
	A(15 downto 0)	=> cpu_addr,       
	DI     			=> cpu_din,
	DO    			=> cpu_dout
	);
		

	----------------------
-- read eeprom, read/write to ram
----------------------
EEprom: entity work.EEprom
port map(
	i_clk => clk_50,
	address_eeprom	=> address_eeprom,
	data_eeprom	=> data_eeprom,
	wr_ram => wr_ram,
	q_ram => r5101_dout_8bit,
	-- Control/Data Signals,
   --i_Rst_L  => reset_sw_stable,     -- FPGA Reset   
	i_Rst_L  => reset_l,
	-- PMOD SPI Interface
   o_SPI_Clk  => EEprom_CLK,
   i_SPI_MISO => MISO,
   o_SPI_MOSI => EEprom_MOSI,
   o_SPI_CS_n => CS_EEprom,
	-- selection
	selection => not game_select,
	-- write trigger
	w_trigger(3) => game_over_relay,
	w_trigger(2) => test_sw,
	w_trigger(1) => credit_sw,
	w_trigger(0) => not game_option(1), -- as trigger for testing	
	-- init trigger (no read, RAM will be zero)
	i_init_Flag => not opt_init_nvram, -- 0 if Dip is set 
	-- signal to outside
	is_active => EEprom_active
	);	
	
----------------------
-- 5101 ram (dual port)
----------------------
Z5: entity work.R5101 -- 5101 RAM 128Byte (256 * 4bit) 
	port map(
		address_a	=> cpu_addr(7 downto 0),
		address_b   => address_eeprom,
		clock			=> clk_50,
		data_a		=> cpu_dout (3 DOWNTO 0), -- Gottlieb use the lower 4 bits
		data_b		=> data_eeprom, --8bit
		wren_a 		=> r5101_cs and not cpu_wr_n,
		wren_b 		=> wr_ram,
		q_a			=> r5101_dout_4bit,
		q_b			=> r5101_dout_8bit
);
	
	
U4_RAM: entity work.RIOT_RAM
port map(
	address	=> cpu_addr(7 DOWNTO 0),
	clock		=> clk_50, 
	data		=>  cpu_dout (7 DOWNTO 0),
	wren 		=> U4_RAM_cs and not cpu_wr_n,
	q			=> U4_RAM_dout
);	
U4_IO: entity work.R6532  -- Switchmatrx
port map(
	phi2   => phi2,
   rst_n  => reset_l,
   cs     => U4_IO_cs,
   rw_n   => cpu_wr_n,
	irq_n  => U4_irq_n,
	
   add    => cpu_addr(4 downto 0),
   din	 => cpu_dout,
	dout	 => U4_IO_dout,
		
	pa_in	 => U4_pa_in or SW_Freeplay or fa_sim_ret,
   pa_out => open,
   pb_in  => "00000000",
	pb_out => u4_pb_out
 );
-- Schalter-Strobes: unter FA-Control aus FA_STROBES
U4_PB <= fa_sw_strobe when fa_active = '1' else u4_pb_out;

U5_RAM: entity work.RIOT_RAM
port map(
	address	=> cpu_addr(7 DOWNTO 0),
	clock		=> clk_50, 
	data		=>  cpu_dout (7 DOWNTO 0),
	wren 		=> U5_RAM_cs and not cpu_wr_n,
	q			=> U5_RAM_dout
);  
U5_IO: entity work.R6532  -- Display Control
port map(
	phi2   => phi2,
   rst_n  => reset_l,
   cs     => U5_IO_cs,
   rw_n   => cpu_wr_n,
	irq_n  => U5_irq_n,
	
   add    => cpu_addr(4 downto 0),
   din	 => cpu_dout,
	dout	 => U5_IO_dout,
			
	pa_in	 => slam & "0000000",
   pa_out => U5_pa_out,
   pb_in  => "00000000",
	pb_out => U5_pb_out
 );
  
U6_RAM: entity work.RIOT_RAM
port map(
	address	=> cpu_addr(7 DOWNTO 0),
	clock		=> clk_50, 
	data		=>  cpu_dout (7 DOWNTO 0),
	wren 		=> U6_ram_cs and not cpu_wr_n,
	q			=> U6_RAM_dout
);
U6_IO: entity work.R6532  -- Solenoid & Lamp Control
port map(
	phi2   => phi2,
   rst_n  => reset_l,
   cs     => U6_IO_cs,
   rw_n   => cpu_wr_n,
	irq_n  => U6_irq_n,
	
   add    => cpu_addr(4 downto 0),
   din	 => cpu_dout,
	dout	 => U6_IO_dout,
		
	pa_in	 => "00000000",
   pa_out => U6_pa_out,
   pb_in  => "00000000",
	pb_out => U6_pb_out
 );  

GAME: entity work.GAME_ROM -- Game ROM 2KByte
port map(
	address	=> game_rom_addr,  -- 10 downto 0
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_game_rom,	
	q			=> game_rom_dout
	);

GAME2: entity work.GAME_ROM -- extended Game ROM 2KByte or late 80B games
port map(
	address	=> game_rom2_addr,  -- 10 downto 0
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_game_rom2,	
	q			=> game_rom2_dout
	);
	
SYSTEM: entity work.SYSTEM_ROM -- System ROM 8KByte
port map(
	address	=> system_rom_addr, -- 12 downto 0
	clock		=> clk_50, 
	data => data_sd_card,
	wren => wr_system_rom,	
	q	=> system_rom_dout
	);
	
-- soundrom1 for MA219/MA309
-- soundrom for MA55 and others	
SOUNDROM1: entity work.GAME_ROM -- ROM 2KByte
port map(
	address	=> sb_rom1_addr,  -- 10 downto 0
	clock		=> clk_50, 
	data 		=> data_sd_card,
	wren 		=> wr_soundrom1,
	q			=> soundrom1_dout
	);

-- soundrom2 for MA219/MA309
-- maskrom (R6530 internal) for MA55 and others	
SOUNDROM2: entity work.GAME_ROM -- ROM 2KByte
port map(
	address	=> sb_rom2_addr,  -- 10 downto 0
	clock		=> clk_50, 
	data 		=> data_sd_card,
	wren 		=> wr_soundrom2,
	q			=> soundrom2_dout
	);
	
	
META1: entity work.Cross_Slow_To_Fast_Clock
port map(
   i_D => reset_sw,
	o_Q => reset_sw_stable,
   i_Fast_Clk => cpu_clk
	); 

	
--integrated soundboard											Sound#3 by pushing test button
Sound_S1 <= ((not u6_pa_out(0) and not u6_pa_out(4))) when mytest='1' else '1';
Sound_S2 <= ((not u6_pa_out(1) and not u6_pa_out(4))) when mytest='1' else '1';
Sound_S4 <= ((not u6_pa_out(2) and not u6_pa_out(4))) when mytest='1' else '0';
Sound_S8 <= ((not u6_pa_out(3) and not u6_pa_out(4))) when mytest='1' else '0';


---------------------
-- detection Sound16 (Q10)
----------------------
clk_Z3 <= '1' when U6_pb_out(7 downto 4) = "0011" else '0'; --DS3

sn74175_Sound16: entity work.sn74175 
port map(   
   Clock => clk_50,
	clk => clk_Z3,
	clear	=> '1',
	D => U6_pb_out(3 downto 0),
	--Q => open,
	Q(1) => Sound_S16
);


------------------------------------------------------------------------------
-- Integriertes Soundboard (GOSOF80). Auf dem v7-Board (FA-Control) abgeschaltet:
-- beides zusammen passt nicht in den EP4CE6. Die Sound-Leitungen U6 PA0..4 gehen
-- trotzdem an den Stecker - ein vorhandenes Original-Soundboard bekommt sie.
------------------------------------------------------------------------------
gen_no_soundboard: if not HAS_SOUNDBOARD generate
	Sound          <= '0';
	Audio_RX       <= '1';				-- UART-Ruhepegel zum DFPlayer
	soundrom1_addr <= (others => '0');
	soundrom2_addr <= (others => '0');
end generate;

gen_soundboard: if HAS_SOUNDBOARD generate
SOUNDBOARD: entity work.gosof80
port map(
		clk_50	=> clk_50,
		cpu_clk  => cpu_clk,
		reset_l	=> reset_l,
		game_running => game_running,
		test	=> '1', --myTest,
		Audio_O	=> sound,
		
		-- Sound input S1,S2,S4,S8,S16
		-- initial low due to 2803A on input of Gosof80
		Sound_Meta(0) => Sound_S1,
		Sound_Meta(1) => Sound_S2,
		Sound_Meta(2) => Sound_S4,
		Sound_Meta(3) => Sound_S8,
		Sound_Meta(4) => Sound_S16,
		
		--Soundboard Options S1 DIPs 1..6
		SB_Opt => sb_option(1) & sb_option(2) & sb_option,
		
		--switches	:	
		game_sel	=> not game_select,
		--option   => sb_option,
		
		-- DFPlayer
		DFP_tx	=> Audio_RX,
		
		--module
		soundrom1_addr => soundrom1_addr,
		soundrom2_addr => soundrom2_addr,
		soundrom1_dout => soundrom1_dout,
		soundrom2_dout => soundrom2_dout

	);
end generate;

------------------------------------------------------------------------------
-- FA-Control. Die Muxe oben sind bewusst unbedingt: ohne ESP ist fa_active die
-- Konstante '0', und die Synthese entfernt sie wieder.
------------------------------------------------------------------------------
gen_fa_control: if HAS_ESP32 generate

	signal lamp_cnt   : integer range 0 to 4999 := 0;	-- 100 us je Phase
	signal lamp_phase : integer range 0 to 2 := 0;
	signal lamp_latch : integer range 1 to 12 := 1;
	signal sw_cnt     : integer range 0 to 49999 := 0;	-- 1 ms je Strobe
	signal sw_slot    : integer range 0 to 7 := 0;
	signal game_bcd   : std_logic_vector(11 downto 0);

	-- Monitor (Opcode 0x6E, FA-Control ab 1.25), Byte k der Antwort =
	-- mon_data(8k+7 downto 8k). Laenge folgt aus der Bestueckung
	-- (fa_connect_monitor_len): 1 + 6 + 2*2 + 1 + 10 + (2 + 4*4) = 40.
	--   1      Flags: bit0 Spiel laeuft, bit1 FA-Control aktiv (Attract/Sim: 0)
	--   2..7   Lampen 0..47 (Q1..Q48), LSB von Byte 2 = Lampe 0
	--   8..9   Spulen 1..9 jetzt (bit0 = Spule 1)
	--   10..11 Spulen gesehen seit dem letzten Abholen
	--   12     Sound gesehen seit dem letzten Abholen: bit0..3 = S1/S2/S4/S8, bit4 = S16
	--   13..22 Schalter wie Opcode 0x28 (10 * PB + PA)
	--   23..40 Displays 0..4 (Status 4, Spieler je 7 Stellen + 1 dunkles Fuellnibble),
	--          zwei Ziffern je Byte, linke Ziffer im High-Nibble, >= 0xA = dunkel
	constant FA_MON_BYTES : integer := 40;
	type mon_seq_t is array (0 to 35) of integer range -1 to 31;
	-- Ziffer n der Displayfolge -> Index in mon_dig (-1 = Fuellnibble)
	constant MON_SEQ : mon_seq_t := (
		0, 1, 2, 3,                          -- Status
		4, 5, 6, 7, 8, 9, 10, -1,            -- Spieler 1
		11, 12, 13, 14, 15, 16, 17, -1,      -- Spieler 2
		18, 19, 20, 21, 22, 23, 24, -1,      -- Spieler 3
		25, 26, 27, 28, 29, 30, 31, -1);     -- Spieler 4
	signal mon_data   : std_logic_vector(8 * FA_MON_BYTES + 7 downto 0);
	signal mon_rd     : std_logic;
	signal mon_idx    : integer range 0 to 255;
	signal mon_dig    : fa_nibble_array_t(0 to 31) := (others => "1111");
	signal mon_lamps  : std_logic_vector(47 downto 0) := (others => '0');
	signal mon_b_q    : std_logic_vector(7 downto 0) := (others => '0');
	signal mon_b_qq   : std_logic_vector(7 downto 0) := (others => '0');
	signal mon_s_q    : std_logic_vector(3 downto 0) := (others => '0');
	signal mon_s_qq   : std_logic_vector(3 downto 0) := (others => '0');
	signal mon_eff_a  : std_logic_vector(7 downto 0);
	signal mon_sol    : std_logic_vector(8 downto 0);
	signal mon_sol_x  : std_logic_vector(8 downto 0) := (others => '0');
	signal mon_snd    : std_logic_vector(4 downto 0);
	signal mon_snd_x  : std_logic_vector(4 downto 0) := (others => '0');
	signal fa_sim_sw  : std_logic_vector(FA_N_SW - 1 downto 0);

	function dig2bcd(c : character) return std_logic_vector is
	begin
		if c >= '0' and c <= '9' then
			return std_logic_vector(to_unsigned(character'pos(c) - 48, 4));
		end if;
		return "0000";
	end function;

	function nib2char(n : std_logic_vector(3 downto 0)) return character is
	begin
		if unsigned(n) < 10 then
			return character'val(48 + to_integer(unsigned(n)));
		end if;
		return ' ';		-- >= 0xA = dunkel
	end function;

begin

FAC: entity work.fa_control
generic map(
	CLKS_PER_BIT => 434,		-- 50 MHz / 115200 Baud
	HW_NAME      => "GottFA80",
	API_VER      => "0.12",
	N_LAMPS      => FA_N_LAMPS,
	N_SOL        => FA_N_SOL,
	N_SOUNDS     => 16,
	N_SW         => FA_N_SW,
	N_DISP       => FA_N_DISP,
	DISP_TYPE    => 1,		-- BCD7
	DISP_DIGITS  => (4, 7, 7, 7, 7, 0, 0),
	MAX_LAMPS    => FA_N_LAMPS,
	MAX_SOL      => FA_N_SOL,
	MAX_SW       => FA_N_SW,
	MAX_DIGITS   => FA_DIGITS,
	GAME_DIGITS  => 3,		-- FA-Control legt Namen/ROMs unter GottFA80/<nnn> ab
	MON_BYTES    => FA_MON_BYTES,
	HAS_SIM_SW   => true		-- Opcode 0x6F, Schalter simulieren im Monitor-Modus
	)
port map(
	clk         => clk_50,
	reset       => not reset_sw_stable,
	rxd         => FA_RXD,
	txd         => FA_TXD,
	ctrl_req    => FA_CTRL_REQ,
	ctrl_allow  => '1',		-- wie GottFA1 v7: Freigabe allein ueber ctrl_req
	ctrl_active => fa_active,
	ver_main    => dig2bcd(BOARD_ID(1)),
	ver_sub1    => dig2bcd(BOARD_ID(2)),
	ver_sub2    => dig2bcd(SW_SUB),
	game_info   => game_bcd,
	sw_state    => fa_sw_state,
	lamp_ovr    => fa_lamp_ovr,
	sol_ovr     => fa_sol_ovr,
	disp_ovr    => fa_disp_ovr,
	snd_ovr     => fa_snd_ovr,
	snd_en      => fa_snd_en,
	mon_data    => mon_data,
	mon_rd      => mon_rd,
	mon_idx     => mon_idx,
	sim_sw      => fa_sim_sw
	);

-- Simulierte Schalter (Opcode 0x6F, nur im Monitor-Modus, fa_control loescht sie
-- unter Kontrolle und nach 2 s ohne Byte): Schalter 10*s + r liegt auf Return r,
-- solange das Spiel Strobe s (U4 PB) treibt. Vor dem RIOT geodert - kann also nur
-- schliessen, nie einen echten Schalter verdecken. Nicht waehrend das Spiel ueber
-- Switch-Enable die DIPs liest (U5 PB7 = '1').
SIM_RET_MUX: process(fa_sim_sw, U4_PB, U5_pb_out)
	variable v : std_logic_vector(7 downto 0);
begin
	v := (others => '0');
	if U5_pb_out(7) = '0' then
		for s in 0 to 7 loop
			if U4_PB(s) = '1' then
				for r in 0 to 7 loop
					v(r) := v(r) or fa_sim_sw(10 * s + r);
				end loop;
			end if;
		end loop;
	end if;
	fa_sim_ret <= v;
end process;

-- Spielnummer wie auf der Bootanzeige (Spieler 2)
game_bcd <= dig2bcd(game_dig2) & dig2bcd(game_dig1) & dig2bcd(game_dig0);

-- Displays: LISY-Ziffer 0 ist die LINKE, boot_message zeigt display(1) links.
fa_disp1 <= nib2char(fa_disp_ovr(1*FA_DIGITS+0)) & nib2char(fa_disp_ovr(1*FA_DIGITS+1)) & nib2char(fa_disp_ovr(1*FA_DIGITS+2)) &
            nib2char(fa_disp_ovr(1*FA_DIGITS+3)) & nib2char(fa_disp_ovr(1*FA_DIGITS+4)) & nib2char(fa_disp_ovr(1*FA_DIGITS+5)) &
            nib2char(fa_disp_ovr(1*FA_DIGITS+6));
fa_disp2 <= nib2char(fa_disp_ovr(2*FA_DIGITS+0)) & nib2char(fa_disp_ovr(2*FA_DIGITS+1)) & nib2char(fa_disp_ovr(2*FA_DIGITS+2)) &
            nib2char(fa_disp_ovr(2*FA_DIGITS+3)) & nib2char(fa_disp_ovr(2*FA_DIGITS+4)) & nib2char(fa_disp_ovr(2*FA_DIGITS+5)) &
            nib2char(fa_disp_ovr(2*FA_DIGITS+6));
fa_disp3 <= nib2char(fa_disp_ovr(3*FA_DIGITS+0)) & nib2char(fa_disp_ovr(3*FA_DIGITS+1)) & nib2char(fa_disp_ovr(3*FA_DIGITS+2)) &
            nib2char(fa_disp_ovr(3*FA_DIGITS+3)) & nib2char(fa_disp_ovr(3*FA_DIGITS+4)) & nib2char(fa_disp_ovr(3*FA_DIGITS+5)) &
            nib2char(fa_disp_ovr(3*FA_DIGITS+6));
fa_disp4 <= nib2char(fa_disp_ovr(4*FA_DIGITS+0)) & nib2char(fa_disp_ovr(4*FA_DIGITS+1)) & nib2char(fa_disp_ovr(4*FA_DIGITS+2)) &
            nib2char(fa_disp_ovr(4*FA_DIGITS+3)) & nib2char(fa_disp_ovr(4*FA_DIGITS+4)) & nib2char(fa_disp_ovr(4*FA_DIGITS+5)) &
            nib2char(fa_disp_ovr(4*FA_DIGITS+6));

-- Lampen: je 74175 (FEED 1..12) erst LD mit FEED 0, dann FEED = n, dann wieder
-- FEED 0, LD bleibt stehen - so passt es zu jeder Taktflanke. RIOT-Bedeutung:
-- LD = '1' ist "an" (lisy80_coil_handler_b), invertiert wird beim Ausgang oben.
FA_LAMPS: process(clk_50)
	variable nib : std_logic_vector(3 downto 0);
begin
	if rising_edge(clk_50) then
		nib := (others => '0');
		for i in 0 to 11 loop
			if lamp_latch = i + 1 then
				nib := fa_lamp_ovr(4 * i + 3 downto 4 * i);
			end if;
		end loop;
		if lamp_cnt = 4999 then
			lamp_cnt <= 0;
			if lamp_phase = 2 then
				lamp_phase <= 0;
				if lamp_latch = 12 then
					lamp_latch <= 1;
				else
					lamp_latch <= lamp_latch + 1;
				end if;
			else
				lamp_phase <= lamp_phase + 1;
			end if;
		else
			lamp_cnt <= lamp_cnt + 1;
		end if;
		case lamp_phase is
			when 0 =>      fa_u6b <= "0000" & nib;
			when 1 =>      fa_u6b(7 downto 4) <= std_logic_vector(to_unsigned(lamp_latch, 4));
			when others => fa_u6b(7 downto 4) <= "0000";
		end case;
	end if;
end process;

-- Spulen und Sound auf U6 PA (RIOT-Bedeutung, s. Konstantenblock).
FA_SOL: process(fa_sol_ovr, fa_snd_ovr, fa_snd_en)
	variable a : std_logic_vector(7 downto 0);
begin
	a := "01111111";			-- Decoder aus, Sound aus, AB = 11
	a(7) := not fa_sol_ovr(8);		-- SOL9: an bei PA7 = '0'
	if fa_snd_en = '1' then
		a(3 downto 0) := not fa_snd_ovr;	-- Z31 freigegeben, Sound negiert
		a(4) := '0';
	else
		-- Decoder 1: SOL1..4 (AB1 = 3..0), kleinste Nummer gewinnt
		if    fa_sol_ovr(0) = '1' then a(1 downto 0) := "11"; a(5) := '0';
		elsif fa_sol_ovr(1) = '1' then a(1 downto 0) := "10"; a(5) := '0';
		elsif fa_sol_ovr(2) = '1' then a(1 downto 0) := "01"; a(5) := '0';
		elsif fa_sol_ovr(3) = '1' then a(1 downto 0) := "00"; a(5) := '0';
		end if;
		-- Decoder 2: SOL5..8 (AB2 = 3..0)
		if    fa_sol_ovr(4) = '1' then a(3 downto 2) := "11"; a(6) := '0';
		elsif fa_sol_ovr(5) = '1' then a(3 downto 2) := "10"; a(6) := '0';
		elsif fa_sol_ovr(6) = '1' then a(3 downto 2) := "01"; a(6) := '0';
		elsif fa_sol_ovr(7) = '1' then a(3 downto 2) := "00"; a(6) := '0';
		end if;
	end if;
	fa_u6a <= a;
end process;

-- Schalter-Strobes bei angehaltener CPU: ein Strobe je Millisekunde.
FA_STROBES: process(clk_50)
begin
	if rising_edge(clk_50) then
		if sw_cnt = 49999 then
			sw_cnt <= 0;
			if sw_slot = 7 then
				sw_slot <= 0;
			else
				sw_slot <= sw_slot + 1;
			end if;
		else
			sw_cnt <= sw_cnt + 1;
		end if;
		for s in 0 to 7 loop
			if sw_slot = s then
				fa_sw_strobe(s) <= '1';
			else
				fa_sw_strobe(s) <= '0';
			end if;
		end loop;
	end if;
end process;

-- Schalterzustand, immer gelesen (FA-Control zeigt ihn auch ohne Uebernahme):
-- wer auch strobt, die Returns eines aktiven Strobes werden uebernommen. Nicht,
-- solange das Spiel ueber Switch-Enable die DIPs liest (U5 PB7 = '1').
FA_SWITCHES: process(clk_50)
begin
	if rising_edge(clk_50) then
		if U5_pb_out(7) = '0' or fa_active = '1' then
			for s in 0 to 7 loop
				if U4_PB(s) = '1' then
					for r in 0 to 7 loop
						fa_sw_state(10 * s + r) <= U4_pa_in(r) or fa_sim_ret(r);	-- Monitor zeigt simulierte mit
					end loop;
				end if;
			end loop;
		end if;
	end if;
end process;

------------------------------------------------------------------------------
-- Monitor: der Istzustand, gelesen ohne Uebernahme und ohne etwas anzufassen.
-- Quelle sind die RIOT-Werte (bzw. unter FA-Control fa_u6a/fa_u6b), also dieselben
-- Werte, die LISY80 auswertet. RIOT-Ausgaenge wechseln mit cpu_clk; sie werden
-- zweimal abgetastet und muessen uebereinstimmen.
------------------------------------------------------------------------------
-- Lampen: Schatten der 74175. Solange FEED = n (1..12) steht, wird LD uebernommen.
MON_LAMP_SHADOW: process(clk_50)
	variable feed : integer range 0 to 15;
begin
	if rising_edge(clk_50) then
		if fa_active = '1' then
			mon_b_q <= fa_u6b;
		else
			mon_b_q <= U6_pb_out;
		end if;
		mon_b_qq <= mon_b_q;
		if mon_b_q = mon_b_qq and (game_running = '1' or fa_active = '1') then
			feed := to_integer(unsigned(mon_b_q(7 downto 4)));
			for i in 0 to 11 loop
				if feed = i + 1 then
					mon_lamps(4 * i + 3 downto 4 * i) <= mon_b_q(3 downto 0);
				end if;
			end loop;
		end if;
	end if;
end process;

-- Spulen und Sound aus U6 PA wie lisy80_coil_handler_a.
mon_eff_a <= fa_u6a when fa_active = '1' else U6_pa_out;

MON_COILS: process(mon_eff_a, game_running, fa_active)
	variable s : std_logic_vector(8 downto 0);
begin
	s := (others => '0');
	if game_running = '1' or fa_active = '1' then
		if mon_eff_a(5) = '0' then		-- I1G: Decoder 1 (SOL1..4)
			case mon_eff_a(1 downto 0) is
				when "11"   => s(0) := '1';
				when "10"   => s(1) := '1';
				when "01"   => s(2) := '1';
				when others => s(3) := '1';
			end case;
		end if;
		if mon_eff_a(6) = '0' then		-- I2G: Decoder 2 (SOL5..8)
			case mon_eff_a(3 downto 2) is
				when "11"   => s(4) := '1';
				when "10"   => s(5) := '1';
				when "01"   => s(6) := '1';
				when others => s(7) := '1';
			end case;
		end if;
		s(8) := not mon_eff_a(7);		-- SOL9 hat einen Inverter dahinter
	end if;
	mon_sol <= s;
end process;

-- Sound S1..S8 = PA3..0 negiert bei PA4 = '0'; S16 = Lampe Q10 (80/80A) bzw. Q5 (80B).
mon_snd(3 downto 0) <= not mon_eff_a(3 downto 0)
                       when mon_eff_a(4) = '0' and (game_running = '1' or fa_active = '1')
                       else "0000";
mon_snd(4) <= mon_lamps(9) when not80B = '1' else mon_lamps(4);

-- Spulen und Sound dauern Millisekunden, der Host fragt alle 500 ms: jeden Puls
-- halten, bis sein Byte gesendet ist. Setzen gewinnt gegen Loeschen.
MON_PULSES: process(clk_50)
begin
	if rising_edge(clk_50) then
		if mon_rd = '1' and mon_idx = 10 then
			mon_sol_x(7 downto 0) <= mon_sol(7 downto 0);
		else
			mon_sol_x(7 downto 0) <= mon_sol_x(7 downto 0) or mon_sol(7 downto 0);
		end if;
		if mon_rd = '1' and mon_idx = 11 then
			mon_sol_x(8) <= mon_sol(8);
		else
			mon_sol_x(8) <= mon_sol_x(8) or mon_sol(8);
		end if;
		if mon_rd = '1' and mon_idx = 12 then
			mon_snd_x <= mon_snd;
		else
			mon_snd_x <= mon_snd_x or mon_snd;
		end if;
	end if;
end process;

-- Displays (nur 80/80A, BCD): Ziffer aus den 74175-Latches Din_Seg_A/B/C bei
-- Digit-Strobe s = U5 PA3..0. Zuordnung wie boot_message.vhd:
--   A: s 15, 5..0 = Spieler 1 links..rechts,  s 12..6 = Spieler 2 links..rechts
--   B: dieselben Strobes fuer Spieler 3 bzw. 4
--   C: s 15..12 = Status links..rechts (Reihenfolge an der Anlage ungeprueft)
-- Unter FA-Control bleiben die zuletzt gelesenen Ziffern stehen.
MON_DISP: process(clk_50)
	variable s : integer range 0 to 15;
begin
	if rising_edge(clk_50) then
		mon_s_q  <= U5_pa_out(3 downto 0);
		mon_s_qq <= mon_s_q;
		if mon_s_q = mon_s_qq and game_running = '1' and fa_active = '0' and not80B = '1' then
			s := to_integer(unsigned(mon_s_q));
			case s is
				when 0 to 5 =>
					mon_dig(4 + 6 - s)  <= Din_Seg_A;		-- Spieler 1, Stelle 1..6
					mon_dig(18 + 6 - s) <= Din_Seg_B;		-- Spieler 3
				when 15 =>
					mon_dig(4)  <= Din_Seg_A;				-- Spieler 1, Stelle 0
					mon_dig(18) <= Din_Seg_B;				-- Spieler 3
				when others => null;
			end case;
			case s is
				when 6 to 12 =>
					mon_dig(11 + 12 - s) <= Din_Seg_A;	-- Spieler 2
					mon_dig(25 + 12 - s) <= Din_Seg_B;	-- Spieler 4
				when others => null;
			end case;
			case s is
				when 12 to 15 =>
					mon_dig(15 - s) <= Din_Seg_C;			-- Status
				when others => null;
			end case;
		end if;
	end if;
end process;

mon_data(7 downto 0)     <= x"00";		-- Byte 0 ist die Laenge, sendet fa_control
-- bit3: Schalter simulierbar (HAS_SIM_SW, Freigabe = ctrl_allow, hier immer '1')
mon_data(15 downto 8)    <= "0000" & '1' & '0' & fa_active & game_running;
mon_data(63 downto 16)   <= mon_lamps;
mon_data(79 downto 64)   <= "0000000" & mon_sol;
mon_data(95 downto 80)   <= "0000000" & mon_sol_x;
mon_data(103 downto 96)  <= "000" & mon_snd_x;
mon_data(183 downto 104) <= "00" & fa_sw_state;

mon_disp_pack: for n in 0 to 35 generate
	pad: if MON_SEQ(n) < 0 generate
		mon_data(8 * (23 + n / 2) + 7 - 4 * (n mod 2) downto 8 * (23 + n / 2) + 4 - 4 * (n mod 2)) <= "1111";
	end generate;
	dig: if MON_SEQ(n) >= 0 generate
		mon_data(8 * (23 + n / 2) + 7 - 4 * (n mod 2) downto 8 * (23 + n / 2) + 4 - 4 * (n mod 2)) <= mon_dig(MON_SEQ(n));
	end generate;
end generate;

end generate;

------------------------------------------------------------------------------
-- Boards ohne ESP32. FA_TXD hat hier keinen Pin (VIRTUAL_PIN), muss aber
-- getrieben sein; '1' ist der Ruhepegel einer UART-Leitung.
------------------------------------------------------------------------------
gen_no_fa_control: if not HAS_ESP32 generate
	fa_active    <= '0';
	FA_TXD       <= '1';
	fa_u6a       <= (others => '1');
	fa_u6b       <= (others => '0');
	fa_sw_strobe <= (others => '0');
	fa_sim_ret   <= (others => '0');
	fa_disp1     <= "       ";
	fa_disp2     <= "       ";
	fa_disp3     <= "       ";
	fa_disp4     <= "       ";
end generate;

end rtl;
		