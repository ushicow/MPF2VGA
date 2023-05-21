library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
 
entity top is
    port (
        pRh		: out std_logic;
        pRl		: out std_logic;
        pGh		: out std_logic;
        pGl		: out std_logic;
        pBh		: out std_logic;
        pBl		: out std_logic;
        pHSYNC 	: out std_logic;
        pVSYNC	: out std_logic;
        
        pVaddr	: out std_logic_vector(14 downto 0);
        pVdata	: inout std_logic_vector(7 downto 0);
        pVwrite	: out std_logic;
        
        pAaddr	: in std_logic_vector(15 downto 0);
        pAdata	: in std_logic_vector(7 downto 0);
        pArw	: in std_logic;
        pAq3	: in std_logic;
        pAphi0	: in std_logic;

		pAdev   : out std_logic;
		pAiosel : out std_logic;
		pExtm	: inout std_logic;
        
        reset 	: in std_logic;
        clk		: in std_logic
    );
end top;
 
architecture RTL of top is
 
    signal hcount : std_logic_vector(9 downto 0);
    signal vcount : std_logic_vector(9 downto 0);
    signal pcount : std_logic_vector(2 downto 0);
 
    signal vga_out : std_logic_vector(5 downto 0);
 
    signal vram_col : std_logic_vector(6 downto 0);
    signal vram_row : std_logic_vector(9 downto 0);
    signal vreg : std_logic_vector(6 downto 0);
    signal vram_write : std_logic_vector(2 downto 0);
    signal color : std_logic_vector(3 downto 0);
    signal page : std_logic;
	signal gr : std_logic;
	signal double : std_logic;
	signal aux : std_logic;
	signal interlace : std_logic;
    signal code : std_logic_vector(3 downto 0);
 
    signal apple_addr : std_logic_vector(15 downto 0);
    signal apple_data : std_logic_vector(7 downto 0);
    signal apple_write : std_logic;
    
    constant ACTIVE_PIXEL : integer := 640;
    constant ACTIVE_LINE  : integer := 480;
 
    constant SCREEN_PIXEL : integer := 560;
    constant SCREEN_LINE : integer := 192 * 2;
    constant BORDER_PIXEL : integer := (ACTIVE_PIXEL - SCREEN_PIXEL) / 2;
    constant BORDER_LINE : integer := (ACTIVE_LINE - SCREEN_LINE) / 2;
	constant SCREEN_LEFT : integer := BORDER_PIXEL;
	constant SCREEN_RIGHT : integer := BORDER_PIXEL + SCREEN_PIXEL;
	constant SCREEN_TOP : integer := 0;
	constant SCREEN_BOTTOM : integer := SCREEN_LINE;

    constant FPORCH_PIXEL : integer := ACTIVE_PIXEL + 16;
    constant SYNC_PIXEL   : integer := FPORCH_PIXEL + 96;
    constant BPORCH_PIXEL : integer := SYNC_PIXEL + 48;
    constant FPORCH_LINE  : integer := SCREEN_TOP + ACTIVE_LINE + 10;
    constant SYNC_LINE    : integer := FPORCH_LINE + 2;
    constant BPORCH_LINE  : integer := SYNC_LINE + 33;

	begin
    pRh <= vga_out(5);
	pRl <= vga_out(4);
    pGh <= vga_out(3);
	pGl <= vga_out(2);
    pBh <= vga_out(1);
	pBl <= vga_out(0);
    vram_row <= vcount(3 downto 1) & vcount(6 downto 4) & 
        vcount(8 downto 7) & vcount(8 downto 7);
	pAiosel <= '0' when pAaddr(15 downto 8) = X"C1" and pAphi0 = '1' else '1';
	pExtm <= '0' when pAaddr(15 downto 8) = X"C1" and pAphi0 = '1' else 'Z';
	pAdev <= '0' when pAaddr(15 downto 4) = X"C09" and pAphi0 = '1' else '1';
	
process(pAq3, reset, pAphi0)
begin
    if (reset = '0') then
		gr <= '0';
        page <= '0';
		double <= '0';
		aux <= '0';
		interlace <= '0';
    elsif (pAq3'event and pAq3 = '0' and pAphi0 = '1') then
        case pAaddr is
			when X"C004" => aux <= '0'; -- Aux off
			when X"C005" => aux <= '1'; -- Aux on
			when X"C050" => gr <= '1'; -- Graphics mode
			when X"C051" => gr <= '0'; -- Text mode
			when X"C054" => page <= '0'; -- Page2 off
			when X"C055" => page <= '1'; -- Page2 on
			when X"C05E" => double <= '1'; -- Double on
			when X"C05F" => double <= '0'; -- Double off
			when others => null;
        end case;
		apple_addr <= pAaddr;
        apple_data <= pAdata;
		apple_write <= not pArw;
    end if;
end process;

process(code)
begin
    case code is
        when "0000" => vga_out <= "000000"; -- Black
        when "0001" => vga_out <= "110000"; -- Magenta
        when "0010" => vga_out <= "100100"; -- Brown
        when "0011" => vga_out <= "110100"; -- Oragne
        when "0100" => vga_out <= "000100"; -- Dark Green
        when "0101" => vga_out <= "010101"; -- Gray 1
        when "0110" => vga_out <= "001100"; -- Green
        when "0111" => vga_out <= "111100"; -- Yellow
        when "1000" => vga_out <= "000010"; -- Dark Blue
        when "1001" => vga_out <= "110011"; -- Violet
        when "1010" => vga_out <= "101010"; -- Gray 2
        when "1011" => vga_out <= "111010"; -- Pink / Purple
        when "1100" => vga_out <= "000011"; -- Medium Blue
        when "1101" => vga_out <= "011011"; -- Light Blue
        when "1110" => vga_out <= "011110"; -- Aqua / Blue
        when "1111" => vga_out <= "111111"; -- White
        when others => null;
    end case;
end process;
 
process(clk, reset)
begin
    if (reset = '0') then
        vram_write <= "000";
        pcount <= "000";
        pVwrite <= '1';
        pVdata <= (others => 'Z');
    elsif (clk'event and clk = '0') then
        if (pcount = "000") then
            pVaddr(14) <= double;
            pVaddr(13) <= page;
            pVaddr(12 downto 0)	<= (vram_row & "000") + 
                vram_col(6 downto 1);
        end if;
        if (pcount = "001" and vram_col < 80) then
            if (hcount(0) = '1') then
                color <= color(2 downto 0) & pVdata(0);
                vreg <= pVdata(7 downto 1);
            end if;
        elsif (hcount(0) = '1') then
            color <= color(2 downto 0) & vreg(0);
            vreg <= vreg(6) & '0' & vreg(5 downto 1);
        end if;
        if (pAphi0 = '1' and vram_write = "100") then
            vram_write <= "000";
        end if;
        if (pcount = "011") then
            if (pAphi0 = '0' and apple_write = '1' and
					apple_addr(14 downto 13) = "01" and
                     vram_write = "000") then
                vram_write <= "001";
            end if;
			pVaddr <= aux & apple_addr(15) & apple_addr(12 downto 0);
        end if;
        if (vram_write = "001") then -- pcount = "100"
            pVwrite <= '0';
            vram_write <= "010";
        end if;
        if (vram_write = "010") then -- pcount = "101"
            pVdata <= apple_data;
            vram_write <= "011";
        end if;
        if (vram_write = "011") then -- pcount = "110"
            pVwrite <= '1';
            pVdata <= (others => 'Z');
            vram_write <= "100";
        end if;
		if (pcount = "110") then
            pcount <= "000";
            vram_col <= vram_col + 1;
        else
            pcount <= pcount + 1;
        end if;
    end if;
end process;
 
process(clk, reset)
begin
    if (reset = '0') then
        hcount <= (others => '0');
        vcount <= (others => '0');
        pHSYNC <= '1';
        pVSYNC <= '1';
    elsif clk'event and clk = '1' then
        if (hcount = FPORCH_PIXEL) then
			pHSYNC <= '0';
            if (vcount = FPORCH_LINE) then
                pVSYNC <= '0';
            elsif (vcount = SYNC_LINE) then
                pVSYNC <= '1';
            end if;
            if (vcount = (BPORCH_LINE - 1)) then
                vcount <= (others => '0');
            else
                vcount <= vcount + 1;
			end if;
		elsif (hcount = SYNC_PIXEL) then
			pHSYNC <= '1';
        end if;
        
        if (hcount = (BPORCH_PIXEL - 1)) then
            hcount <= (others => '0');
        else 
            hcount <= hcount + 1;
        end if;
        
        if (vcount > (SCREEN_TOP - 1) and vcount < SCREEN_LINE and
            hcount > (SCREEN_LEFT - 1) and hcount < SCREEN_RIGHT) then
			if (hcount(0) = '0') then
				if (gr = '0') then
					code <= color(1) & color(1) & color(1) & color(1);
				elsif (color(2 downto 0) = "010") then
					if (hcount(1) = '0') then
						if (vreg(6) = '0') then
							code <= "1011"; -- Purple
						else
							code <= "1110"; -- Blue
						end if;
					else
						if (vreg(6) = '0') then
							code <= "0110"; -- Green
						else
							code <= "0011"; -- Oragne
						end if;
					end if;
				elsif (color(2 downto 0) = "101") then
					if (hcount(1) = '1') then
						if (vreg(6) = '0') then
							code <= "1011"; -- Purple
						else
							code <= "1110"; -- Blue
						end if;
					else
						if (vreg(6) = '0') then
							code <= "0110"; -- Green
						else
							code <= "0011"; -- Oragne
						end if;
					end if;
				else
					code(3) <= color(1);
					code(2) <= color(1);
					code(1) <= color(1);
					code(0) <= color(1);
				end if;
			end if;
        else
            code <= (others => '0');
        end if;
    end if;
end process;
    
end RTL;