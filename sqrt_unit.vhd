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

    -- 18-bit remainder is enough for 16-bit input (two bits per iteration)
    signal remainder : unsigned(17 downto 0) := (others => '0');
    -- 9-bit internal root; low 8 bits are the final integer sqrt
    signal root      : unsigned(8 downto 0)  := (others => '0');

    -- We do 8 iterations (two bits per iteration) for a 16-bit operand
    signal count : integer range 0 to 7 := 0;

    signal x_reg : unsigned(15 downto 0) := (others => '0');

begin

    busy   <= busy_s;
    done   <= done_s;
    -- Expose the 8-bit integer sqrt in the low byte, zero-extend to 16 bits
    output <= ("00000000" & root(7 downto 0));

    process(clk, resetn)
        variable next_pair : unsigned(1 downto 0);
        variable rem_v     : unsigned(17 downto 0);
        variable root_v    : unsigned(8 downto 0);
        variable trial_v   : unsigned(17 downto 0);
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
            -- default: DONE is a one-cycle pulse (like mul/div)
            done_s <= '0';

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
                -- Extract next two MSB bits from x_reg
                next_pair := x_reg(15 downto 14);
                -- Shift x_reg left (drop used bits, append 00)
                x_reg     <= x_reg(13 downto 0) & "00";

                -- Work with local copies for correct sequencing
                rem_v  := remainder;
                root_v := root;

                -- Shift remainder left two and add next bit-pair
                rem_v := (rem_v(15 downto 0) & next_pair);

                -- trial = (root << 2) + 1 (classic digit-by-digit sqrt)
                trial_v := resize((root_v(7 downto 0) & "00") + 1, rem_v'length);

                if rem_v >= trial_v then
                    rem_v  := rem_v - trial_v;
                    root_v := (root_v(7 downto 0) & '1');
                else
                    root_v := (root_v(7 downto 0) & '0');
                end if;

                remainder <= rem_v;
                root      <= root_v;

                -- Count down iterations (8 total for 16-bit operand)
                if count = 0 then
                    st <= FINISH;
                else
                    count <= count - 1;
                end if;

            ---------------------------------------------------------------------
            when FINISH =>
                busy_s <= '0';
                done_s <= '1';  -- one-cycle DONE pulse
                st     <= IDLE;

            end case;
        end if;
    end process;

end architecture;
