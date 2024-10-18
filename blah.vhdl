library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blah is
  port(
    membus_value : in out STD_LOGIC_VECTOR(15 downto 0);
    membus_address : out STD_LOGIC_VECTOR(15 downto 0);
    -- Write if UP, Read if LOW
    membus_mode : out STD_LOGIC;
    -- For waitstate. 
    membus_ready : in std_logic;
    reset : in STD_LOGIC;
  ); 
end entity blah;

architecture blah_seq of blah is
  constant ZERO : STD_LOGIC_VECTOR(15 downto 0) := '0000000000000000';

  signal pipeline : unsigned(2 downto 0);
  signal instruction : STD_LOGIC_VECTOR(15 downto 0);

  alias operation is instruction(15 downto 13);
  alias register_a is instruction(12 downto 10);
  alias register_b is instruction(9 downto 7);
  alias register_c is instruction(2 downto 0);
  alias immediate_7 is instruction(6 downto 0);
  alias immediate_10 is instruction(9 downto 0);
  
  signal source_1 : STD_LOGIC_VECTOR(15 downto 0);
  signal source_2 : STD_LOGIC_VECTOR(15 downto 0);
  signal destination : STD_LOGIC_VECTOR(15 downto 0);

  signal program_counter_in : STD_LOGIC_VECTOR(15 downto 0);
  signal program_counter_out : STD_LOGIC_VECTOR(15 downto 0);
  
  signal r1_in : STD_LOGIC_VECTOR(15 downto 0);
  signal r2_in : STD_LOGIC_VECTOR(15 downto 0);
  signal r3_in : STD_LOGIC_VECTOR(15 downto 0);
  signal r4_in : STD_LOGIC_VECTOR(15 downto 0);
  signal r5_in : STD_LOGIC_VECTOR(15 downto 0);
  signal r6_in : STD_LOGIC_VECTOR(15 downto 0);
  signal r7_in : STD_LOGIC_VECTOR(15 downto 0);

  signal r1_out : STD_LOGIC_VECTOR(15 downto 0);
  signal r2_out : STD_LOGIC_VECTOR(15 downto 0);
  signal r3_out : STD_LOGIC_VECTOR(15 downto 0);
  signal r4_out : STD_LOGIC_VECTOR(15 downto 0);
  signal r5_out : STD_LOGIC_VECTOR(15 downto 0);
  signal r6_out : STD_LOGIC_VECTOR(15 downto 0);
  signal r7_out : STD_LOGIC_VECTOR(15 downto 0);
begin


  pc : process(clock) begin
    if rising_edge(clock)
      program_counter_out <= program_counter_out;
    end if;
  end process;

  r1 : process(clock) begin
    if rising_edge(clock)
      r1_out <= r1_out;
    end if;
  end process;

  r1 : process(clock) begin
    if rising_edge(clock)
      r1_out <= r1_out;
    end if;
  end process;

  r2 : process(clock) begin
    if rising_edge(clock)
      r2_out <= r2_out;
    end if;
  end process;

  r3 : process(clock) begin
    if rising_edge(clock)
      r3_out <= r3_out;
    end if;
  end process;

  r4 : process(clock) begin
    if rising_edge(clock)
      r1_out <= r1_out;
    end if;
  end process;

  r5 : process(clock) begin
    if rising_edge(clock)
      r5_out <= r5_out;
    end if;
  end process;

  r6 : process(clock) begin
    if rising_edge(clock)
      r6_out <= r6_out;
    end if;
  end process;

  r7 : process(clock) begin
    if rising_edge(clock)
      r7_out <= r7_out;
    end if;
  end process;

  decode_source_2: process(register_c)
    source_1 <= ZERO when (register_c = '000') else
      r1_out when (register_c = '001') else
      r2_out when (register_c = '010') else
      r3_out when (register_c = '011') else
      r4_out when (register_c = '100') else
      r5_out when (register_c = '101') else
      r6_out when (register_c = '110') else
      r7_out when (register_c = '111');
  end process; 

  decode_source_1: process(register_b)
    source_2 <= ZERO when (register_b = '000') else
      r1_out when (register_b = '001') else
      r2_out when (register_b = '010') else
      r3_out when (register_b = '011') else
      r4_out when (register_b = '100') else
      r5_out when (register_b = '101') else
      r6_out when (register_b = '110') else
      r7_out when (register_b = '111');
  end process;

  decode_source_3: process(register_a)
    source_2 <= ZERO when (register_a = '000') else
      r1_out when (register_a = '001') else
      r2_out when (register_a = '010') else
      r3_out when (register_a = '011') else
      r4_out when (register_a = '100') else
      r5_out when (register_a = '101') else
      r6_out when (register_a = '110') else
      r7_out when (register_a = '111');
  end process;


  write_destination : process(register_a)
    case operation
    when '000' | '001' | '010' | '011' | '101'
      case register_a
      when '001' 
        r1_in <= destination
      when '010' 
        r2_in <= destination;
      when '011' 
        r3_in <= destination;
      when '100' 
        r4_in <= destination;
      when '101' 
        r5_in <= destination;
      when '110' 
        r6_in <= destination;
      when '111' 
        r7_in <= destination;
      end case;
    end case;
  end process;

  main : process(clock, membus_ready)
    if membus_ready then
      case pipeline is
        when '0' 
          instruction <= membus_value;
          pipeline <= '1';
        when '1'
          case operation
          when '000' 
            destination <= std_logic_vector(signed(source_1) + signed(source_2));
            program_counter_in <= std_logic_vector(unsigned(program_counter_out) + 1);
            pipeline <= '0';
            when '001' 
            destination <= std_logic_vector(signed(source_1) + signed(immediate_7));
            program_counter_in <= std_logic_vector(unsigned(program_counter_out) + 1);
            pipeline <= '0';
            when '010' 
            destination <= source_1 nand source_2;
            program_counter_in <= std_logic_vector(unsigned(program_counter_out) + 1);
            pipeline <= '0';
            when '011' 
            destination <= immediate_10;
            program_counter_in <= std_logic_vector(unsigned(program_counter_out) + 1);
            pipeline <= '0';

          when '100' 
            pipeline <= '0';
          when '101'
            pipeline <= '0';
          
          when '110'
            if source_1 = source_3
              program_counter_in <= std_logic_vector(unsigned(program_counter_out) + 1 + signed(immediate_7));
            else
              program_counter_in <= std_logic_vector(unsigned(program_counter_out) + 1);
            end if;
            pipeline <= '0';
          when '111' 
            destination_in <= std_logic_vector(unsigned(program_counter_out) + 1);
            program_counter_in <= source_1;
            pipeline <= '0';
        end case;
      when '2'

      end case;
    end if;
  begin 
  end process;
end architecture;