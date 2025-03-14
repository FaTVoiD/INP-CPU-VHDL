-- cpu.vhd: Simple 8-bit CPU (BrainLove interpreter)
-- Copyright (C) 2021 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): xbelov04
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet ROM
   CODE_ADDR : out std_logic_vector(11 downto 0); -- adresa do pameti
   CODE_DATA : in std_logic_vector(7 downto 0);   -- CODE_DATA <- rom[CODE_ADDR] pokud CODE_EN='1'
   CODE_EN   : out std_logic;                     -- povoleni cinnosti
   
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- ram[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_WREN  : out std_logic;                    -- cteni z pameti (DATA_WREN='0') / zapis do pameti (DATA_WREN='1')
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA obsahuje stisknuty znak klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna pokud IN_VLD='1'
   IN_REQ    : out std_logic;                     -- pozadavek na vstup dat z klavesnice
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- pokud OUT_BUSY='1', LCD je zaneprazdnen, nelze zapisovat,  OUT_WREN musi byt '0'
   OUT_WREN : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is
	type INST is (PTRINC, PTRDEC, DATAINC, DATADEC, BEGINCYCLE, STOPCYCLE, PRINT, LOADVALUE, BREAK, SKIP, STOP_RUN);
	type STATE is (IDLE, GETC, COMMAND, STOP_RUN, PTRINC, PTRINC_1, PTRDEC, PTRDEC_1, DATAINC, DATAINC_1, DATAINC_2, DATADEC, DATADEC_1,
					DATADEC_2, BEGINCYCLE, BEGINCYCLE_1, BEGINCYCLE_2, BEGINCYCLE_3, STOPCYCLE, STOPCYCLE_1, STOPCYCLE_2, STOPCYCLE_3,
					PRINT, PRINT_1, PRINT_2, LOADVALUE, LOADVALUE_1, LOADVALUE_2, BREAK, BREAK_1, SKIP);
	signal PINST : INST;
	signal PSTATE : STATE := IDLE;
	signal NSTATE : STATE;
	signal PT_EN: std_logic;
	signal PT_IN : std_logic;
	signal PT_DC : std_logic;
	signal PC_EN : std_logic;
	signal PC_IN : std_logic;
	signal PC_DC : std_logic;

begin
	
	STATE_MACHINE: process (RESET, CLK, EN) is
	begin
		if (rising_edge(CLK) and EN = '1') then
			PSTATE <= NSTATE;
		elsif (RESET = '1') then
			PSTATE <= IDLE;
		end if;
		if (rising_edge(CLK)) then
			if (EN = '1' and RESET = '0') then
				if (PSTATE = IDLE) then
					PC_EN <= '1';
					CODE_EN <= '1';
					NSTATE <= COMMAND;
				elsif (PSTATE = COMMAND) then
					PC_EN <= '0';
					PC_IN <= '0';
					if (PINST=PTRINC) then
						NSTATE <= PTRINC;
					elsif (PINST=PTRDEC) then
						NSTATE <= PTRDEC;
					elsif (PINST=DATAINC) then
						NSTATE <= DATAINC;
					elsif (PINST=DATADEC) then
						NSTATE <= DATADEC;
					elsif (PINST=PRINT) then
						NSTATE <= PRINT;
					elsif (PINST=LOADVALUE) then
						NSTATE <= LOADVALUE;
					elsif (PINST=BEGINCYCLE) then
						NSTATE <= BEGINCYCLE;
					elsif (PINST=STOPCYCLE) then
						NSTATE <= STOPCYCLE;
					elsif (PINST=BREAK) then
						NSTATE <= BREAK;
					elsif (PINST=STOP_RUN) then
						NSTATE <= STOP_RUN;
					elsif (PINST=SKIP) then
						NSTATE <= GETC;
					end if;
					CODE_EN <= '0';
				elsif (PSTATE = GETC) then
					CODE_EN <= '1';
					PC_EN <= '1';
					PC_IN <= '1';
					NSTATE <= COMMAND;
				else
					if (PSTATE=PTRINC) then
						PT_EN <= '1';
						PT_IN <= '1';
						NSTATE <= PTRINC_1;
					elsif (PSTATE=PTRINC_1) then
						PT_EN <= '0';
						PT_IN <= '0';
						NSTATE <= GETC;
					elsif (PSTATE=PTRDEC) then
						PT_EN <= '1';
						PT_DC <= '1';
						NSTATE <= PTRDEC_1;
					elsif (PSTATE=PTRDEC_1) then
						PT_EN <= '0';
						PT_DC <= '0';
						NSTATE <= GETC;
					elsif (PSTATE=DATAINC) then
						PT_EN <= '1';
						DATA_EN <= '1';
						DATA_WREN <= '0';
						NSTATE <= DATAINC_1;
					elsif (PSTATE=DATAINC_1) then
						DATA_WREN <= '1';
						NSTATE <= DATAINC_2;
					elsif (PSTATE=DATAINC_2) then
						DATA_EN <= '0';
						NSTATE <= GETC;
					elsif (PSTATE=DATADEC) then
						PT_EN <= '1';
						DATA_EN <= '1';
						DATA_WREN <= '0';
						NSTATE <= DATADEC_1;
					elsif (PSTATE=DATADEC_1) then
						DATA_WREN <= '1';
						NSTATE <= DATADEC_2;
					elsif (PSTATE=DATADEC_2) then
						DATA_EN <= '0';
						NSTATE <= GETC;
					elsif (PSTATE=BEGINCYCLE) then
						DATA_EN <= '1';
						DATA_WREN <= '0';
						NSTATE <= BEGINCYCLE_1;
					elsif (PSTATE=BEGINCYCLE_1) then
						DATA_EN <= '0';
						if (DATA_RDATA=(DATA_RDATA'range => '0')) then
							if (PINST=STOPCYCLE) then
								PC_EN <= '0';
								PC_IN <= '0';
								CODE_EN <= '0';
								NSTATE <= GETC;
							else
								NSTATE <= BEGINCYCLE_2;
							end if;
						else
							NSTATE <= GETC;
						end if;
					elsif (PSTATE=BEGINCYCLE_2) then
						PC_EN <= '1';
						PC_IN <= '1';
						CODE_EN <= '1';
						NSTATE <= BEGINCYCLE_3;
					elsif (PSTATE=BEGINCYCLE_3) then
						PC_EN <= '0';
						CODE_EN <= '0';
						NSTATE <= BEGINCYCLE_1;
					elsif (PSTATE=STOPCYCLE) then
						DATA_EN <= '1';
						DATA_WREN <= '0';
						NSTATE <= STOPCYCLE_1;
					elsif (PSTATE=STOPCYCLE_1) then
						DATA_EN <= '0';
						if (DATA_RDATA=(DATA_RDATA'range => '0')) then
							NSTATE <= GETC;
						else
							if (PINST=BEGINCYCLE) then
								PC_EN <= '0';
								PC_DC <= '0';
								CODE_EN <= '0';
								NSTATE <= GETC;
							else
								NSTATE <= STOPCYCLE_3;
							end if;
						end if;
					elsif (PSTATE=STOPCYCLE_2) then
						PC_EN <= '0';
						PC_DC <= '0';
						NSTATE <= STOPCYCLE_1;
					elsif (PSTATE=STOPCYCLE_3) then
						PC_EN <= '1';
						CODE_EN <= '1';
						CODE_EN <= '1';
						NSTATE <= STOPCYCLE_2;
					elsif (PSTATE=BREAK) then
						PC_EN <= '1';
						PC_IN <= '1';
						CODE_EN <= '1';
						if (PINST=STOPCYCLE) then
							PC_EN<= '0';
							PC_IN <= '0';
							CODE_EN <= '0';
							NSTATE <= GETC;
						else
							NSTATE <= BREAK_1;
						end if;
					elsif (PSTATE=BREAK_1) then
						PC_EN <= '0';
						PC_IN <= '0';
						CODE_EN <= '0';
						NSTATE <= BREAK;
					elsif (PSTATE=PRINT) then
						DATA_EN <= '1';
						DATA_WREN <= '0';
						NSTATE <= PRINT_1;
					elsif (PSTATE=PRINT_1) then
						DATA_EN <= '0';
						OUT_DATA <= DATA_RDATA;
						if (OUT_BUSY='0') then
							OUT_WREN <= '1';
							NSTATE <= PRINT_2;
						end if;
					elsif (PSTATE=PRINT_2) then
						OUT_WREN <= '0';
						NSTATE <= GETC;
					elsif (PSTATE=LOADVALUE) then
						IN_REQ <= '1';
						DATA_EN <= '1';
						PT_EN <= '1';
						NSTATE <= LOADVALUE_1;
					elsif (PSTATE=LOADVALUE_1) then
						if (IN_VLD='1') then
							IN_REQ <= '0';
							DATA_WREN <= '1';
							NSTATE <= LOADVALUE_2;
						end if;
					elsif (PSTATE=LOADVALUE_2) then
						DATA_EN <= '0';
						PT_EN <= '0';
						NSTATE <= GETC;
					elsif (PSTATE=SKIP) then
						NSTATE <= GETC;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	DC: process (CODE_DATA) is
	begin
		if (CODE_DATA(7 downto 4)=X"0") then
			if (CODE_DATA(3 downto 0)=X"0") then
				PINST <= STOP_RUN;
			else
				PINST <= SKIP;
			end if;
		elsif (CODE_DATA(7 downto 4)=X"2") then 
			if (CODE_DATA(3 downto 0)=X"B") then
				PINST <= DATAINC;
			elsif (CODE_DATA(3 downto 0)=X"C") then
				PINST <= LOADVALUE;
			elsif (CODE_DATA(3 downto 0)=X"D") then
				PINST <= DATADEC;
			elsif (CODE_DATA(3 downto 0)=X"E") then
				PINST <= PRINT;
			else
				PINST <= SKIP;
			end if;
		elsif (CODE_DATA(7 downto 4)=X"3") then 
			if (CODE_DATA(3 downto 0)=X"C") then
				PINST <= PTRDEC;
			elsif (CODE_DATA(3 downto 0)=X"E") then
				PINST <= PTRINC;
			else
				PINST <= SKIP;
			end if;
		elsif (CODE_DATA(7 downto 4)=X"5") then 
			if (CODE_DATA(3 downto 0)=X"B") then 
				PINST <= BEGINCYCLE;
			elsif (CODE_DATA(3 downto 0)=X"D") then 
				PINST <= STOPCYCLE;
			else
				PINST <= SKIP;
			end if;
		elsif (CODE_DATA(7 downto 4)=X"7") then 
			if (CODE_DATA(3 downto 0)=X"E") then
				PINST <= BREAK;
			else
				PINST <= SKIP;
			end if;
		else
			PINST <= SKIP;
		end if;
	end process;
	
	Write_data: process (PSTATE, DATA_RDATA, IN_DATA) is
	begin
		case PSTATE is
			when DATAINC_1 => DATA_WDATA <= DATA_RDATA+1;
			when DATADEC_1 => DATA_WDATA <= DATA_RDATA-1;
			when LOADVALUE_1 => DATA_WDATA <= IN_DATA;
			when others => NULL;
		end case;
	end process;
	
	PT_PROCESS: process (RESET, PT_EN, PT_IN, PT_DC) is
	variable PT_CNT : std_logic_vector(9 downto 0) := "0000000000";
	begin
		if (PT_EN='1') then
			if (PT_IN = '1') then
				PT_CNT := PT_CNT+1;
				DATA_ADDR <= PT_CNT;
			elsif (PT_DC = '1') then
				PT_CNT := PT_CNT-1;
				DATA_ADDR <= PT_CNT;
			end if;
		elsif (RESET = '1') then
			PT_CNT := "0000000000";
			DATA_ADDR <= PT_CNT;
		end if;
	end process;
	
	PC: process (RESET, PC_EN, PC_IN, PC_DC) is
	variable PC_CNT : std_logic_vector(11 downto 0) := "000000000000";
	begin
		if (PC_EN = '1') then
			if (PC_IN = '1') then
				PC_CNT := PC_CNT+1;
				CODE_ADDR <= PC_CNT;
			end if;
			if (PC_DC = '1') then
				PC_CNT := PC_CNT-1;
				CODE_ADDR <= PC_CNT;
			end if;
		elsif (RESET = '1') then
			PC_CNT := "000000000000";
			CODE_ADDR <= PC_CNT;
		end if;
	end process;
end behavioral;
 
 
 
