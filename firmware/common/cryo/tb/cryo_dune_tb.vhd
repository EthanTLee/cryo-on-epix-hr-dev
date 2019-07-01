-------------------------------------------------------------------------------
-- Title      : Testbench for design full system
-- Project    : 
-------------------------------------------------------------------------------
-- File       : cryo_tb.vhd
-- Author     : Dionisio Doering  <ddoering@tid-pc94280.slac.stanford.edu>
-- Company    : 
-- Created    : 2017-05-22
-- Last update: 2019-07-01
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2017 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_textio.all;

library STD;
use STD.textio.all;      
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

use work.all;
use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.EpixHrCorePkg.all;
use work.AxiLitePkg.all;
use work.AxiPkg.all;
use work.Pgp2bPkg.all;
use work.SsiPkg.all;
use work.SsiCmdMasterPkg.all;
use work.HrAdcPkg.all;
use work.Code8b10bPkg.all;
use work.AppPkg.all;
use work.BuildInfoPkg.all;

library unisim;
use unisim.vcomponents.all;

-------------------------------------------------------------------------------

entity cryo_dune_tb is
     generic (
      TPD_G        : time := 1 ns;
      BUILD_INFO_G : BuildInfoType := BUILD_INFO_C;
      IDLE_PATTERN_C : slv(11 downto 0) := x"03F"  -- "11 0100 0000 0111"
      );
end cryo_dune_tb;

-------------------------------------------------------------------------------

architecture arch of cryo_dune_tb is


  

  --file definitions
  constant DATA_BITS   : natural := 12;
  constant DEPTH_C     : natural := 1024;
  constant FILENAME_C  : string  := "/afs/slac.stanford.edu/u/re/ddoering/localGit/epix-hr-dev/firmware/simulations/CryoEncDec/sin.csv";
  --simulation constants to select data type
  constant CH_ID       : natural := 0;
  constant CH_WF       : natural := 1;
  constant DATA_TYPE_C : natural := CH_ID;
  
  subtype word_t  is slv(DATA_BITS - 1 downto 0);
  type    ram_t   is array(0 to DEPTH_C - 1) of word_t;

  impure function readWaveFile(FileName : STRING) return ram_t is
    file     FileHandle   : TEXT open READ_MODE is FileName;
    variable CurrentLine  : LINE;
    variable TempWord     : integer; --slv(DATA_BITS - 1 downto 0);
    variable TempWordSlv  : slv(16 - 1 downto 0);
    variable Result       : ram_t    := (others => (others => '0'));
  begin
    for i in 0 to DEPTH_C - 1 loop
      exit when endfile(FileHandle);
      readline(FileHandle, CurrentLine);
      read(CurrentLine, TempWord);
      TempWordSlv  := toSlv(TempWord, 16);
      Result(i)    := TempWordSlv(15 downto 16 - DATA_BITS);
    end loop;
    return Result;
  end function;

  -- waveform signal
  signal ramWaveform      : ram_t    := readWaveFile(FILENAME_C);
  signal ramTestWaveform  : ram_t    := readWaveFile(FILENAME_C);


  -----------------------------------------------------------------------------
  -- Signals to mimic top module io
  -----------------------------------------------------------------------------
      -----------------------
      -- Application Ports --
      -----------------------
      -- System Ports
      signal digPwrEn      : sl;
      signal anaPwrEn      : sl;
      signal syncDigDcDc   : sl;
      signal syncAnaDcDc   : sl;
      signal syncDcDc      : slv(6 downto 0);
      signal daqTg         : sl;
      signal connTgOut     : sl;
      signal connMps       : sl;
      signal connRun       : sl;
      -- Fast ADC Ports
      signal adcSpiClk     : sl;
      signal adcSpiData    : sl;
      signal adcSpiCsL     : sl;
      signal adcPdwn       : sl;
      signal adcClkP       : sl;
      signal adcClkM       : sl;
      signal adcDoClkP     : sl;
      signal adcDoClkM     : sl;
      signal adcFrameClkP  : sl;
      signal adcFrameClkM  : sl;
      signal adcMonDoutP   : slv(4 downto 0);
      signal adcMonDoutN   : slv(4 downto 0);
      -- Slow ADC
      signal slowAdcSclk   : sl;
      signal slowAdcDin    : sl;
      signal slowAdcCsL    : sl;
      signal slowAdcRefClk : sl;
      signal slowAdcDout   : sl;
      signal slowAdcDrdy   : sl;
      signal slowAdcSync   : sl;
      -- Slow DACs Port
      signal sDacCsL       : slv(4 downto 0);
      signal hsDacCsL      : sl;
      signal hsDacLoad     : sl;
      signal dacClrL       : sl;
      signal dacSck        : sl;
      signal dacDin        : sl;
      -- ASIC Gbps Ports
      signal asicDataP     : slv(23 downto 0);
      signal asicDataN     : slv(23 downto 0);
      -- ASIC Control Ports
      signal asicR0        : sl;
      signal asicPpmat     : sl;
      signal asicGlblRst   : sl;
      signal asicSync      : sl;
      signal asicAcq       : sl;
      signal asicRoClkP    : slv(3 downto 0);
      signal asicRoClkN    : slv(3 downto 0);
      -- SACI Ports
      signal asicSaciCmd   : sl;
      signal asicSaciClk   : sl;
      signal asicSaciSel   : slv(3 downto 0);
      signal asicSaciRsp   : sl;
      -- Spare Ports
      signal spareHpP      : slv(11 downto 0);
      signal spareHpN      : slv(11 downto 0);
      signal spareHrP      : slv(5 downto 0);
      signal spareHrN      : slv(5 downto 0);
      -- GTH Ports
      signal gtRxP         : sl;
      signal gtRxN         : sl;
      signal gtTxP         : sl;
      signal gtTxN         : sl;
      signal gtRefP        : sl;
      signal gtRefN        : sl;
      signal smaRxP        : sl;
      signal smaRxN        : sl;
      signal smaTxP        : sl;
      signal smaTxN        : sl;
      ----------------
      -- Core Ports --
      ----------------   
      -- Board IDs Ports
      signal snIoAdcCard   : sl;
      signal snIoCarrier   : sl;
      -- QSFP Ports
      signal qsfpRxP       : slv(3 downto 0);
      signal qsfpRxN       : slv(3 downto 0);
      signal qsfpTxP       : slv(3 downto 0);
      signal qsfpTxN       : slv(3 downto 0);
      signal qsfpClkP      : sl := '1';
      signal qsfpClkN      : sl;
      signal qsfpLpMode    : sl;
      signal qsfpModSel    : sl;
      signal qsfpInitL     : sl;
      signal qsfpRstL      : sl;
      signal qsfpPrstL     : sl;
      signal qsfpScl       : sl;
      signal qsfpSda       : sl;
      -- DDR Ports
      signal ddrClkP       : sl := '1';
      signal ddrClkN       : sl;
      signal ddrBg         : sl;
      signal ddrCkP        : sl;
      signal ddrCkN        : sl;
      signal ddrCke        : sl;
      signal ddrCsL        : sl;
      signal ddrOdt        : sl;
      signal ddrAct        : sl;
      signal ddrRstL       : sl;
      signal ddrA          : slv(16 downto 0);
      signal ddrBa         : slv(1 downto 0);
      signal ddrDm         : slv(3 downto 0);
      signal ddrDq         : slv(31 downto 0);
      signal ddrDqsP       : slv(3 downto 0);
      signal ddrDqsN       : slv(3 downto 0);
      signal ddrPg         : sl;
      signal ddrPwrEn      : sl;
      -- SYSMON Ports
      signal vPIn          : sl;
      signal vNIn          : sl;
  
  -----------------------------------------------------------------------------
  -- Signals to communicate among app and core
  -----------------------------------------------------------------------------
  -- System Clock and Reset
  signal sysClk          : sl;
  signal sysRst          : sl;
  signal sysRst_n        : sl;
  -- AXI-Lite Register Interface (sysClk domain)
  signal axilReadMaster  : AxiLiteReadMasterType;
  signal axilReadSlave   : AxiLiteReadSlaveType;
  signal axilWriteMaster : AxiLiteWriteMasterType;
  signal axilWriteSlave  : AxiLiteWriteSlaveType;
  -- AXI Stream, one per QSFP lane (sysClk domain)
  signal axisMasters     : AxiStreamMasterArray(3 downto 0);
  signal axisSlaves      : AxiStreamSlaveArray(3 downto 0);
  -- Auxiliary AXI Stream, (sysClk domain)
  signal sAuxAxisMasters : AxiStreamMasterArray(1 downto 0);
  signal sAuxAxisSlaves  : AxiStreamSlaveArray(1 downto 0);
  -- ssi commands (Lane and Vc 0)
  signal ssiCmd          : SsiCmdMasterType;
  -- DDR's AXI Memory Interface (sysClk domain)
  signal axiReadMaster   : AxiReadMasterType;
  signal axiReadSlave    : AxiReadSlaveType;
  signal axiWriteMaster  : AxiWriteMasterType;
  signal axiWriteSlave   : AxiWriteSlaveType;
  -- Microblaze's Interrupt bus (sysClk domain)
  signal mbIrq           : slv(7 downto 0);

  -- encoder
  signal EncValidIn  : sl              := '1';
  signal EncReadyIn  : sl;
  signal EncDataIn   : slv(11 downto 0);
  signal EncDispIn   : slv(1 downto 0) := "00";
  signal EncDataKIn  : sl;
  signal EncValidOut : sl;
  signal EncReadyOut : sl              := '1';
  signal EncDataOut  : slv(13 downto 0);
  signal EncDataOut_d: Slv14Array(7 downto 0);
  signal EncDispOut  : slv(1 downto 0);
  signal EncSof      : sl := '0';
  signal EncEof      : sl := '0';

  signal dClkP : sl := '1'; -- Data clock
  signal dClkN : sl := '0';
  signal fClkP : sl := '0'; -- Frame clock
  signal fClkN : sl := '1';
  signal serialDataOut1 : sl;
  signal serialDataOut2 : sl;
  signal chId           : slv(11 downto 0);

  -- DUNE system level simulation
  signal duneClk    : sl := '1';
  signal duneClkInt : sl ;
  signal duneClkx4  : sl ;
  signal cryoClk    : sl ;
  signal duneRst    : sl := '1';
  signal duneRstInt : sl ;
  signal duneRstx4  : sl ;
  signal cryoRst    : sl ;
  signal phaseDuneCryo : slv(7 downto 0);


  signal protoDuneClk    : sl := '1';
  signal protoDuneClkInt : sl ;
  signal protoDuneClkx4  : sl ;
  signal protoCryoClk    : sl ;
  signal protoDuneRst    : sl := '1';
  signal protoDuneRstInt : sl ;
  signal protoDuneRstx4  : sl ;
  signal protoCryoRst    : sl ;
  signal phaseprotoDuneCryo : slv(7 downto 0);

signal dummy : slv(1 downto 0);

begin  --

  -- clock generation
  qsfpClkP  <= not qsfpClkP after 6.4 ns;
  qsfpClkN  <= not qsfpClkP;

  ddrClkP  <= not ddrCkP after 6.4 ns;
  ddrClkN  <= not ddrCkP;
  
--  fClkP <= not fClkP after 7 * 2 ns;
  fClkN <= not fClkP;
--  dClkP <= not dClkP after 2 ns; 
  dClkN <= not dClkP;

  -- dunel clk
  duneClk <= not duneClk after 8 ns;

  protoDuneClk <= not protoDuneClk after 10 ns;


  ------------------------------------------
  -- Generate clocks from 156.25 MHz PGP  --
  ------------------------------------------
  -- clkIn     :  62.50 MHz DUNE base clock
  -- clkOut(0) :  62.50 MHz -- Internal copy of the clock
  -- clkOut(1) : 250.00 MHz -- DUNE clock times 4 used for the deserializer
  -- clkOut(2) :  56.00 MHz -- CRYO clock


  U_DUNE_ClockGen : entity work.ClockManagerUltraScale 
    generic map(
      TPD_G                  => 1 ns,
      TYPE_G                 => "MMCM",  -- or "PLL"
      INPUT_BUFG_G           => true,
      FB_BUFG_G              => true,
      RST_IN_POLARITY_G      => '1',     -- '0' for active low
      NUM_CLOCKS_G           => 3,
      -- MMCM attributes
      BANDWIDTH_G            => "OPTIMIZED",
      CLKIN_PERIOD_G         => 16.0,    -- Input period in ns );
      DIVCLK_DIVIDE_G        => 1,
      CLKFBOUT_MULT_F_G      => 1.0,
      CLKFBOUT_MULT_G        => 16,
      CLKOUT0_DIVIDE_F_G     => 1.0,
      CLKOUT0_DIVIDE_G       => 16,
      CLKOUT0_PHASE_G        => 0.0,
      CLKOUT0_DUTY_CYCLE_G   => 0.5,
      CLKOUT0_RST_HOLD_G     => 3,
      CLKOUT0_RST_POLARITY_G => '1',
      CLKOUT1_DIVIDE_G       => 4,
      CLKOUT1_PHASE_G        => 0.0,
      CLKOUT1_DUTY_CYCLE_G   => 0.5,
      CLKOUT1_RST_HOLD_G     => 3,
      CLKOUT1_RST_POLARITY_G => '1',
      CLKOUT2_DIVIDE_G       => 18,
      CLKOUT2_PHASE_G        => 0.0,
      CLKOUT2_DUTY_CYCLE_G   => 0.5,
      CLKOUT2_RST_HOLD_G     => 3,
      CLKOUT2_RST_POLARITY_G => '1')
   port map(
      clkIn           => duneClk,
      rstIn           => duneRst,
      clkOut(0)       => duneClkInt,       
      clkOut(1)       => duneClkx4,
      clkOut(2)       => cryoClk,
      rstOut(0)       => duneRstInt,
      rstOut(1)       => duneRstx4,
      rstOut(2)       => cryoRst,
      locked          => open
   );


  U_ISERDESE3_62p5to56 : ISERDESE3
    generic map (
      DATA_WIDTH => 8,            -- Parallel data width (4,8)
      FIFO_ENABLE => "FALSE",     -- Enables the use of the FIFO
      FIFO_SYNC_MODE => "FALSE",  -- Enables the use of internal 2-stage synchronizers on the FIFO
      IS_CLK_B_INVERTED => '1',   -- Optional inversion for CLK_B
      IS_CLK_INVERTED => '0',     -- Optional inversion for CLK
      IS_RST_INVERTED => '0',     -- Optional inversion for RST
      SIM_DEVICE => "ULTRASCALE"  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,
                                  -- ULTRASCALE_PLUS_ES2)
      )
    port map (
      FIFO_EMPTY => OPEN,         -- 1-bit output: FIFO empty flag
      INTERNAL_DIVCLK => open,    -- 1-bit output: Internally divided down clock used when FIFO is
                                  -- disabled (do not connect)

      Q => phaseDuneCryo,            -- bit registered output
      CLK => duneClkx4,            -- 1-bit input: High-speed clock
      CLKDIV => duneClkInt,         -- 1-bit input: Divided Clock
      CLK_B => duneClkx4,        -- 1-bit input: Inversion of High-speed clock CLK
      D => cryoClk,               -- 1-bit input: Serial Data Input
      FIFO_RD_CLK => '1',         -- 1-bit input: FIFO read clock
      FIFO_RD_EN => '1',          -- 1-bit input: Enables reading the FIFO when asserted
      RST => duneRstInt              -- 1-bit input: Asynchronous Reset
      );


    ------------------------------------------
  -- Generate clocks from 156.25 MHz PGP  --
  ------------------------------------------
  -- clkIn     :  62.50 MHz DUNE base clock
  -- clkOut(0) :  62.50 MHz -- Internal copy of the clock
  -- clkOut(1) : 250.00 MHz -- DUNE clock times 4 used for the deserializer
  -- clkOut(2) :  56.00 MHz -- CRYO clock


  U_PROTODUNE_ClockGen : entity work.ClockManagerUltraScale 
    generic map(
      TPD_G                  => 1 ns,
      TYPE_G                 => "MMCM",  -- or "PLL"
      INPUT_BUFG_G           => true,
      FB_BUFG_G              => true,
      RST_IN_POLARITY_G      => '1',     -- '0' for active low
      NUM_CLOCKS_G           => 3,
      -- MMCM attributes
      BANDWIDTH_G            => "OPTIMIZED",
      CLKIN_PERIOD_G         => 20.0,    -- Input period in ns );
      DIVCLK_DIVIDE_G        => 1,
      CLKFBOUT_MULT_F_G      => 1.0,
      CLKFBOUT_MULT_G        => 20,
      CLKOUT0_DIVIDE_F_G     => 1.0,
      CLKOUT0_DIVIDE_G       => 20,
      CLKOUT0_PHASE_G        => 0.0,
      CLKOUT0_DUTY_CYCLE_G   => 0.5,
      CLKOUT0_RST_HOLD_G     => 3,
      CLKOUT0_RST_POLARITY_G => '1',
      CLKOUT1_DIVIDE_G       => 5,
      CLKOUT1_PHASE_G        => 0.0,
      CLKOUT1_DUTY_CYCLE_G   => 0.5,
      CLKOUT1_RST_HOLD_G     => 3,
      CLKOUT1_RST_POLARITY_G => '1',
      CLKOUT2_DIVIDE_G       => 18,
      CLKOUT2_PHASE_G        => 0.0,
      CLKOUT2_DUTY_CYCLE_G   => 0.5,
      CLKOUT2_RST_HOLD_G     => 3,
      CLKOUT2_RST_POLARITY_G => '1')
   port map(
      clkIn           => protoDuneClk,
      rstIn           => protoDuneRst,
      clkOut(0)       => protoDuneClkInt,       
      clkOut(1)       => protoDuneClkx4,
      clkOut(2)       => protoCryoClk,
      rstOut(0)       => protoDuneRstInt,
      rstOut(1)       => protoDuneRstx4,
      rstOut(2)       => protoCryoRst,
      locked          => open
   );


  U_ISERDESE3_50to56 : ISERDESE3
    generic map (
      DATA_WIDTH => 8,            -- Parallel data width (4,8)
      FIFO_ENABLE => "FALSE",     -- Enables the use of the FIFO
      FIFO_SYNC_MODE => "FALSE",  -- Enables the use of internal 2-stage synchronizers on the FIFO
      IS_CLK_B_INVERTED => '1',   -- Optional inversion for CLK_B
      IS_CLK_INVERTED => '0',     -- Optional inversion for CLK
      IS_RST_INVERTED => '0',     -- Optional inversion for RST
      SIM_DEVICE => "ULTRASCALE"  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1,
                                  -- ULTRASCALE_PLUS_ES2)
      )
    port map (
      FIFO_EMPTY => OPEN,         -- 1-bit output: FIFO empty flag
      INTERNAL_DIVCLK => open,    -- 1-bit output: Internally divided down clock used when FIFO is
                                  -- disabled (do not connect)

      Q => phaseProtoDuneCryo,            -- bit registered output
      CLK => protoDuneClkx4,            -- 1-bit input: High-speed clock
      CLKDIV => protoDuneClkInt,         -- 1-bit input: Divided Clock
      CLK_B => protoDuneClkx4,        -- 1-bit input: Inversion of High-speed clock CLK
      D => protoCryoClk,               -- 1-bit input: Serial Data Input
      FIFO_RD_CLK => '1',         -- 1-bit input: FIFO read clock
      FIFO_RD_EN => '1',          -- 1-bit input: Enables reading the FIFO when asserted
      RST => protoDuneRstInt              -- 1-bit input: Asynchronous Reset
      );

  ------------------------------------------
  -- Generate clocks from 156.25 MHz PGP  --
  ------------------------------------------
  -- clkIn     : 156.25 MHz PGP
  -- clkOut(0) : 448.00 MHz -- 8x cryo clock (default  56MHz)
  -- clkOut(1) : 112.00 MHz -- 448 clock div 4
  -- clkOut(2) : 64.00 MHz  -- 448 clock div 7
  -- clkOut(3) : 56.00 MHz  -- cryo input clock default is 56MHz

  U_TB_ClockGen : entity work.ClockManagerUltraScale 
    generic map(
      TPD_G                  => 1 ns,
      TYPE_G                 => "MMCM",  -- or "PLL"
      INPUT_BUFG_G           => true,
      FB_BUFG_G              => true,
      RST_IN_POLARITY_G      => '1',     -- '0' for active low
      NUM_CLOCKS_G           => 2,
      -- MMCM attributes
      BANDWIDTH_G            => "OPTIMIZED",
      CLKIN_PERIOD_G         => 6.4,    -- Input period in ns );
      DIVCLK_DIVIDE_G        => 8,
      CLKFBOUT_MULT_F_G      => 45.875,
      CLKFBOUT_MULT_G        => 5,
      CLKOUT0_DIVIDE_F_G     => 1.0,
      CLKOUT0_DIVIDE_G       => 2,
      CLKOUT0_PHASE_G        => 0.0,
      CLKOUT0_DUTY_CYCLE_G   => 0.5,
      CLKOUT0_RST_HOLD_G     => 3,
      CLKOUT0_RST_POLARITY_G => '1',
      CLKOUT1_DIVIDE_G       => 14,
      CLKOUT1_PHASE_G        => 0.0,
      CLKOUT1_DUTY_CYCLE_G   => 0.5,
      CLKOUT1_RST_HOLD_G     => 3,
      CLKOUT1_RST_POLARITY_G => '1')
   port map(
      clkIn           => sysClk,
      rstIn           => sysRst,
      clkOut(0)       => dClkP,       --bit clk
      clkOut(1)       => fClkP,
      rstOut(0)       => dummy(0),
      rstOut(1)       => dummy(1),
      locked          => open
   );


  U_asicModel : entity work.CryoAsicTopLevelModel 
   generic map(
      TPD_G              => TPD_G
   )
   port map(
      clk              => protoCryoClk,
      gRst             => protoCryoRst,
      -- simulated data
      analogData       => x"000",
      -- saci
      saciClk          => asicSaciClk,
      saciSelL         => asicSaciSel(0),
      saciCmd          => asicSaciCmd,
      saciRsp          => asicSaciRsp,
      -- static control
      SRO              => asicR0,
      
      -- data out
      bitClk0          => open,
      frameClk0        => open,
      sData0           => open,
      bitClk1          => open,
      frameClk1        => open,
      sData1           => open      
   );
  
  -- waveform generation
  WaveGen_Proc: process
    variable registerData    : slv(31 downto 0);  
  begin

    ---------------------------------------------------------------------------
    -- reset
    ---------------------------------------------------------------------------
    wait until sysClk = '1';
   
    wait;
  end process WaveGen_Proc;




-------------------------------------------------------------------------------
--  simulation process for channel ID. Counter from 0 to 31
-------------------------------------------------------------------------------  
  EncValid_Proc: process  
  begin
    wait until fClkP = '1';
    EncValidIn <= asicR0;
  end process;  
  
-------------------------------------------------------------------------------
--  simulation process for channel ID. Counter from 0 to 31
-------------------------------------------------------------------------------  
  chId_Proc: process
    variable chIdCounter : integer := 0;
  begin
    wait until fClkP = '1';
    if asicR0 = '1' then
      chIdCounter := ChIdCounter + 1;
      if chIdCounter = 32 then
        chIdCounter := 0;
      end if;
    else
      chIdCounter := 0;
    end if;
    chId <= toSlv(chIdCounter, 12);
  end process;  
-------------------------------------------------------------------------------
--  
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
  EncDataIn_Proc: process
    variable dataIndex : integer := 0;
  begin
    wait until fClkP = '1';
    if asicR0 = '1' then
      if DATA_TYPE_C = CH_ID then
        EncDataIn <= chId;
      else
        EncDataIn <= ramWaveform(dataIndex);
      end if;
      dataIndex := dataIndex + 1;
      if dataIndex = DEPTH_C then
        dataIndex := 0;
      end if;
    else
      EncDataIn <= IDLE_PATTERN_C;
    end if;
    EncDataOut_d(0) <= EncDataOut;
    for i in 1 to 7 loop
      EncDataOut_d(i) <= EncDataOut_d(i-1);
    end loop;
  end process;
  
  U_encoder : entity work.SspEncoder12b14b 
   generic map (
     TPD_G          => TPD_G,
     RST_POLARITY_G => '1',
     RST_ASYNC_G    => false,
     AUTO_FRAME_G   => true,
     FLOW_CTRL_EN_G => false)
   port map(
      clk      => fClkP,
      rst      => sysRst,
      validIn  => EncValidIn,
      readyIn  => EncReadyIn,
      sof      => EncSof,
      eof      => EncEof,
      dataIn   => EncDataIn,
      validOut => EncValidOut,
      readyOut => EncReadyOut,
      dataOut  => EncDataOut);

  U_serializer :  entity work.serializerSim 
    generic map(
        g_dwidth => 14 
    )
    port map(
        clk_i     => dClkP,
        reset_n_i => sysRst_n,
        data_i    => EncDataOut,        -- "00"&EncDataIn, --
        data_o    => serialDataOut1
    );


  U_serializer2 :  entity work.serializerSim 
    generic map(
        g_dwidth => 14 
    )
    port map(
        clk_i     => dClkP,
        reset_n_i => sysRst_n,
        data_i    => EncDataOut_d(7),        -- "00"&EncDataIn, --
        data_o    => serialDataOut2
    );


  sysRst_n      <= not sysRst;
  duneRst       <= sysRst;
  protoDuneRst  <= sysRst;
    
  asicDataP(0) <=     serialDataOut1;
  asicDataN(0) <= not serialDataOut1;
--  asicDataP(0) <= fClkP;
--  asicDataN(0) <= fClkN;  
  asicDataP(3) <=     serialDataOut2;
  asicDataN(3) <= not serialDataOut2;

  asicDataP(2) <= fClkP;
  asicDataN(2) <= fClkN;
  asicDataP(5) <= dClkP;
  asicDataN(5) <= dClkN;
 
  U_App : entity work.Application
      generic map (
         TPD_G => TPD_G,
         SIMULATION_G => true,
         BUILD_INFO_G => BUILD_INFO_G)
      port map (
         ----------------------
         -- Top Level Interface
         ----------------------
         -- System Clock and Reset
         sysClk           => sysClk,
         sysRst           => sysRst,
         -- AXI-Lite Register Interface (sysClk domain)
         -- Register Address Range = [0x80000000:0xFFFFFFFF]
         sAxilReadMaster  => axilReadMaster,
         sAxilReadSlave   => axilReadSlave,
         sAxilWriteMaster => axilWriteMaster,
         sAxilWriteSlave  => axilWriteSlave,
         -- AXI Stream, one per QSFP lane (sysClk domain)
         mAxisMasters     => axisMasters,
         mAxisSlaves      => axisSlaves,
         -- Auxiliary AXI Stream, (sysClk domain)
         sAuxAxisMasters  => sAuxAxisMasters,
         sAuxAxisSlaves   => sAuxAxisSlaves,
         ssiCmd           => ssiCmd,
         -- DDR's AXI Memory Interface (sysClk domain)
         -- DDR Address Range = [0x00000000:0x3FFFFFFF]
         mAxiReadMaster   => axiReadMaster,
         mAxiReadSlave    => axiReadSlave,
         mAxiWriteMaster  => axiWriteMaster,
         mAxiWriteSlave   => axiWriteSlave,
         -- Microblaze's Interrupt bus (sysClk domain)
         mbIrq            => mbIrq,
         -----------------------
         -- Application Ports --
         -----------------------
         -- System Ports
         digPwrEn         => digPwrEn,
         anaPwrEn         => anaPwrEn,
         syncDigDcDc      => syncDigDcDc,
         syncAnaDcDc      => syncAnaDcDc,
         syncDcDc         => syncDcDc,
         led              => open,
         daqTg            => daqTg,
         connTgOut        => connTgOut,
         connMps          => connMps,
         connRun          => connRun,
         -- Fast ADC Ports
         adcSpiClk        => adcSpiClk,
         adcSpiData       => adcSpiData,
         adcSpiCsL        => adcSpiCsL,
         adcPdwn          => adcPdwn,
         adcClkP          => adcClkP,
         adcClkM          => adcClkM,
         adcDoClkP        => adcDoClkP,
         adcDoClkM        => adcDoClkM,
         adcFrameClkP     => adcFrameClkP,
         adcFrameClkM     => adcFrameClkM,
         adcMonDoutP      => adcMonDoutP,
         adcMonDoutN      => adcMonDoutN,
         -- Slow ADC
         slowAdcSclk      => slowAdcSclk,
         slowAdcDin       => slowAdcDin,
         slowAdcCsL       => slowAdcCsL,
         slowAdcRefClk    => slowAdcRefClk,
         slowAdcDout      => slowAdcDout,
         slowAdcDrdy      => slowAdcDrdy,
         slowAdcSync      => slowAdcSync,
         -- Slow DACs Port         
         sDacCsL          => sDacCsL,
         hsDacCsL         => hsDacCsL,
         hsDacLoad        => hsDacLoad,
         dacClrL          => dacClrL,
         dacSck           => dacSck,
         dacDin           => dacDin,
         -- ASIC Gbps Ports
         asicDataP        => asicDataP,
         asicDataN        => asicDataN,
         -- ASIC Control Ports
         asicR0           => asicR0,
         asicPpmat        => asicPpmat,
         asicGlblRst      => asicGlblRst,
         asicSync         => asicSync,
         asicAcq          => asicAcq,
         asicRoClkP       => asicRoClkP,
         asicRoClkN       => asicRoClkN,
         -- SACI Ports
         asicSaciCmd      => asicSaciCmd,
         asicSaciClk      => asicSaciClk,
         asicSaciSel      => asicSaciSel,
         asicSaciRsp      => asicSaciRsp,
         -- Spare Ports
         spareHpP         => spareHpP,
         spareHpN         => spareHpN,
         spareHrP         => spareHrP,
         spareHrN         => spareHrN,
         -- GTH Ports
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRefP           => gtRefP,
         gtRefN           => gtRefN,
         smaRxP           => smaRxP,
         smaRxN           => smaRxN,
         smaTxP           => smaTxP,
         smaTxN           => smaTxN);

  U_Core : entity work.EpixHrCore
      generic map (
         TPD_G        => TPD_G,
         BUILD_INFO_G => BUILD_INFO_G,
         SIMULATION_G => true)
      port map (
         ----------------------
         -- Top Level Interface
         ----------------------
         -- System Clock and Reset
         sysClk           => sysClk,
         sysRst           => sysRst,
         -- AXI-Lite Register Interface (sysClk domain)
         -- Register Address Range = [0x80000000:0xFFFFFFFF]
         mAxilReadMaster  => axilReadMaster,
         mAxilReadSlave   => axilReadSlave,
         mAxilWriteMaster => axilWriteMaster,
         mAxilWriteSlave  => axilWriteSlave,
         -- AXI Stream, one per QSFP lane (sysClk domain)
         sAxisMasters     => axisMasters,
         sAxisSlaves      => axisSlaves,
         -- Auxiliary AXI Stream, (sysClk domain)
         sAuxAxisMasters  => sAuxAxisMasters,
         sAuxAxisSlaves   => sAuxAxisSlaves,
         ssiCmd           => ssiCmd,
         -- DDR's AXI Memory Interface (sysClk domain)
         -- DDR Address Range = [0x00000000:0x3FFFFFFF]
         sAxiReadMaster   => axiReadMaster,
         sAxiReadSlave    => axiReadSlave,
         sAxiWriteMaster  => axiWriteMaster,
         sAxiWriteSlave   => axiWriteSlave,
         -- Microblaze's Interrupt bus (sysClk domain)
         mbIrq            => mbIrq,
         ----------------
         -- Core Ports --
         ----------------   
         -- Board IDs Ports
         snIoAdcCard      => snIoAdcCard,
         snIoCarrier      => snIoCarrier,
         -- QSFP Ports
         qsfpRxP          => qsfpRxP,
         qsfpRxN          => qsfpRxN,
         qsfpTxP          => qsfpTxP,
         qsfpTxN          => qsfpTxN,
         qsfpClkP         => qsfpClkP,
         qsfpClkN         => qsfpClkN,
         qsfpLpMode       => qsfpLpMode,
         qsfpModSel       => qsfpModSel,
         qsfpInitL        => qsfpInitL,
         qsfpRstL         => qsfpRstL,
         qsfpPrstL        => qsfpPrstL,
         qsfpScl          => qsfpScl,
         qsfpSda          => qsfpSda,
         -- DDR Ports
         ddrClkP          => ddrClkP,
         ddrClkN          => ddrClkN,
         ddrBg            => ddrBg,
         ddrCkP           => ddrCkP,
         ddrCkN           => ddrCkN,
         ddrCke           => ddrCke,
         ddrCsL           => ddrCsL,
         ddrOdt           => ddrOdt,
         ddrAct           => ddrAct,
         ddrRstL          => ddrRstL,
         ddrA             => ddrA,
         ddrBa            => ddrBa,
         ddrDm            => ddrDm,
         ddrDq            => ddrDq,
         ddrDqsP          => ddrDqsP,
         ddrDqsN          => ddrDqsN,
         ddrPg            => ddrPg,
         ddrPwrEn         => ddrPwrEn,
         -- SYSMON Ports
         vPIn             => vPIn,
         vNIn             => vNIn);  

end arch;

