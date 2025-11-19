library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cordic_unit is
    port (
        clk       : in  std_logic;
        resetn    : in  std_logic;
        start     : in  std_logic;

        busy      : out std_logic;
        done      : out std_logic;

        theta_in  : in  signed(15 downto 0);
        cos_out   : out signed(15 downto 0);
        sin_out   : out signed(15 downto 0);
        valid     : out std_logic
    );
end entity;

architecture rtl of cordic_unit is

    -- precomputed atan(2^-i) scaled by 2^14 (Q2.14 / Q1.14-style)
    type atan_tab_t is array (0 to 15) of signed(15 downto 0);
    constant ATAN_TAB_16 : atan_tab_t := (
        to_signed(12868, 16), to_signed(7596, 16), to_signed(4014, 16), to_signed(2037, 16),
        to_signed(1023, 16),  to_signed(512, 16),  to_signed(256, 16),  to_signed(128, 16),
        to_signed(64, 16),    to_signed(32, 16),   to_signed(16, 16),   to_signed(8, 16),
        to_signed(4, 16),     to_signed(2, 16),    to_signed(1, 16),    to_signed(0, 16)
    );

    -- CORDIC gain for 16 iterations (also Q1.14-ish)
    constant K_GAIN : signed(15 downto 0) := to_signed(9949, 16);

    type state_t is (IDLE, RUN, FINISH);
    signal st       : state_t := IDLE;
    signal busy_s   : std_logic := '0';
    signal done_s   : std_logic := '0';

    -- Current CORDIC state
    signal x, y, z  : signed(15 downto 0);

    -- iteration counter (0..15)
    signal count    : integer range 0 to 31 := 0;

    -- Outputs
    signal cos_r, sin_r : signed(15 downto 0) := (others => '0');
    signal valid_r      : std_logic := '0';

    function atan_i(i : integer) return signed is
    begin
        if i <= 15 then
            return ATAN_TAB_16(i);
        else
            return (others => '0'); -- should never be used
        end if;
    end function;

begin
    busy    <= busy_s;
    done    <= done_s;
    cos_out <= cos_r;
    sin_out <= sin_r;
    valid   <= valid_r;

    process(clk, resetn)
        variable x_v, y_v, z_v : signed(15 downto 0);
    begin
        if resetn = '0' then
            st      <= IDLE;
            busy_s  <= '0';
            done_s  <= '0';
