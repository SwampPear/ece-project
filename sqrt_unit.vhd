library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sqrt_unit is
    port (
        clk       : in  std_logic;
        resetn    : in  std_logic;

        start     : in  std_logic;
        root_in   : in  unsigned(15 downto 0);

        busy      : out std_logic;
        done      : out std_logic;

        output    : out unsigned(15 downto 0)
    );
end sqrt_unit;

architecture rtl of sqrt_unit is

    type state_t is (IDLE, RUN, FINISH);
    signal st : state_t := IDLE;

    signal busy_s : std_logic := '0';
    signal done_s : std_logic := '0';

    signal remainder : unsigned(17 downto 0) := (others => '0');
    signal root      : unsigned(9 downto 0)  := (others => '0');

    signal count : integer range 0 to 7 := 0;

    signal x_reg : unsigned(15 downto 0) := (others => '0');

begin

    busy   <= busy_s;
    done   <= done_s;
    output <= ("00000000" & root(7 downto 0));   -- result in low 8 bits

    process(clk, resetn)
        variable next_pair : unsigned(1 downto 0);
    begin
        if resetn = '0' then
            st        <= IDLE;
            busy_s    <= '0';
            done_s    <= '0';
            remainder <= (others => '0');
            root      <= (others => '0');
            count     <= 0;
            x_reg     <= (others => '0');

        elsif rising_edge(clk) then

            case st is
            ---------------------------------------------------------------------
            when IDLE =>
                busy_s <= '0';

                if start = '1' then
                    st        <= RUN;
                    busy_s    <= '1';
                    done_s    <= '0';

                    remainder <= (others => '0');
                    root      <= (others => '0');
                    count     <= 7;

                    x_reg     <= root_in;
                end if;

            ---------------------------------------------------------------------
            when RUN =>
                -- extract next two MSB bits
                next_pair := x_reg(15 downto 14);

                -- shift x_reg left to drop used bits
                x_reg <= x_reg(13 downto 0) & "00";

                -- shift remainder left and add next pair
                remainder <= (remainder(15 downto 0) & next_pair);

                -- trial value = (root << 2) + 1
                if remainder >= ((root(7 downto 0) & "00") + 1) then
                    remainder <= remainder - ((root(7 downto 0) & "00") + 1);
                    root      <= (root(7 downto 0) & '1');
                else
                    root      <= (root(7 downto 0) & '0');
                end if;

                -- count down
                if count = 0 then
                    st <= FINISH;
                else
                    count <= count - 1;
                end if;

            ---------------------------------------------------------------------
            when FINISH =>
                busy_s <= '0';
                done_s <= '1';   -- stays high until next start
                st     <= IDLE;

            end case;
        end if;
    end process;

end architecture;
