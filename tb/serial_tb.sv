// packet: transaction object

class packet;
  rand bit [7:0] in_byte;
  rand bit stop_bit;
  rand bit par_bit;
  bit odd_parity; //is odd parity?
  
  bit pckt_sent;
    
  bit [7:0] out_byte;
  bit done;
  
  function void post_randomize();
    this.odd_parity = (($countones(in_byte)+par_bit)%2==1);
  endfunction
  
  function void print (string tag="");
    $display ("T=%0t %s in_byte=0x%0h isOddParity=%b hasValidStopBit=%b : out_byte=0x%0h done=%b", $time, tag, in_byte, odd_parity, stop_bit, out_byte, done );
  endfunction
endclass


// generator: generate input stimulus and mail it to the driver

class generator;
  mailbox drv_mbx;
  event drv_done;
  int num = 7;
  
  task run_oddpar(); //odd parity tests
    $display ("T=%0t [Generator] --- Starting odd parity input stimulus of %0d test vectors ---",$time, num);
    for (int i = 0; i < num; i++) begin
      packet pckt = new;
      pckt.randomize() with {par_bit == !($countones(in_byte)%2);};
      $display ("T=%0t [Generator] - Loop:%0d/%0d creating next packet -", $time, i+1, num);
      drv_mbx.put(pckt);
      @(drv_done);
    end
    $display ("T=%0t [Generator] --- Finished odd parity input stimulus of %0d test vectors ---",$time, num);
  endtask
  
  task run_evenpar(); //even parity tests
    $display ("T=%0t [Generator] --- Starting even parity input stimulus of %0d test vectors ---",$time, num);
    for (int i = 0; i < num; i++) begin
      packet pckt = new;
      pckt.randomize() with {par_bit == ($countones(in_byte)%2);};
      $display ("T=%0t [Generator] - Loop:%0d/%0d creating next packet -", $time, i+1, num);
      drv_mbx.put(pckt);
      @(drv_done);
    end
    $display ("T=%0t [Generator] --- Finished even parity input stimulus of %0d test vectors ---",$time, num);
  endtask  
endclass


// driver: get packet from generator and drive data packets into virtual interface

class driver;
  mailbox drv_mbx;
  event drv_done;
  virtual serial_if vif;
  virtual serial_tbif tb_vif;
  
  task run();
    $display ("T=%0t [Driver] starting ...",$time);
    
    forever begin
      packet pckt;
      
      $display ("T=%0t [Driver] waiting for packet ...",$time);
      drv_mbx.get(pckt);
      pckt.print("Driver");
      
      tb_vif.pckt_sent <= 0;
      tb_vif.in_byte <= pckt.in_byte;
      tb_vif.par_bit <= pckt.par_bit;
      tb_vif.stop_bit <= pckt.stop_bit;
      tb_vif.odd_parity <= pckt.odd_parity;      
      
      for (int i = 0; i < 3; i++) begin
        vif.in <= 1'b1;        
        @(posedge vif.clk);
        $display ("T=%0t [Driver] clocked IDLE bit [1] ...",$time);
      end
      
      vif.in <= 1'b0;
      @(posedge vif.clk);
      $display ("T=%0t [Driver] clocked starting bit [0] ...",$time);
      
      for (int i = 0; i < 8; i++) begin
        vif.in <= pckt.in_byte[i];
        @(posedge vif.clk);
        $display ("T=%0t [Driver] clocked data bit %0d of 7 [%b] ...",$time,i, pckt.in_byte[i]);
      end
      
      vif.in <= pckt.par_bit;
      @(posedge vif.clk);
      $display ("T=%0t [Driver] clocked parity bit [%b] ...",$time, pckt.par_bit);
       
      vif.in <= pckt.stop_bit;
      @(posedge vif.clk);
      $display ("T=%0t [Driver] clocked stop bit [%b] ...",$time, pckt.stop_bit);
      
      tb_vif.pckt_sent <= 1;
      #2
      ->drv_done;
    end
  endtask
endclass


// monitor: capture data on the interface and mail it to the scoreboard

class monitor;
  mailbox scb_mbx;
  virtual serial_if vif;
  virtual serial_tbif tb_vif;
  
  task run();
    $display ("T=%0t [Monitor] starting ...", $time);
    
    forever begin
      packet pckt = new;
      #1;
      pckt.in_byte = tb_vif.in_byte;
      pckt.par_bit = tb_vif.par_bit;
      pckt.stop_bit = tb_vif.stop_bit;
      pckt.odd_parity = tb_vif.odd_parity;
      
      pckt.pckt_sent = tb_vif.pckt_sent;
      
      pckt.out_byte = vif.out_byte;
      pckt.done = vif.done;
      
      //pckt.print("Monitor");
      
      scb_mbx.put(pckt);
      @(posedge vif.clk);
    end
  endtask
endclass


// scoreboard: get packet from monitor and check with assertions.

class scoreboard;
  mailbox scb_mbx;
  
  task run();
    forever begin
      packet pckt;
      scb_mbx.get(pckt);
      
      if (pckt.pckt_sent)
      	pckt.print("Scoreboard");
      
      //if done is high
      if (pckt.done) begin        
        assert (pckt.out_byte === pckt.in_byte) //make sure out byte is the same as in byte
        else
          $error ("Mismatch: data_out=0x%0h expected=0x%0h when done is high", pckt.out_byte, pckt.in_byte);
        
        assert (pckt.stop_bit && pckt.odd_parity) //make sure stop bit and odd parity are valid
        else
          $error ("Done can only be high when stop bit and odd parity are valid");
      end
      
      //if done is not high
      if (pckt.pckt_sent && !pckt.done) begin      
        lostDone	:	assert (~pckt.stop_bit || ~pckt.odd_parity || (pckt.out_byte !== pckt.in_byte)); //make sure 'done' wasn't supposed to be high
      end
    end
  endtask
endclass


// environment: run the generator, driver, monitor, and scoreboard. connect the mailboxes, events, and virtual interfaces.

class env;
  generator g0;
  driver d0;
  monitor m0;
  scoreboard s0;
  
  mailbox drv_mbx;
  mailbox scb_mbx;
  
  event drv_done;
  
  virtual serial_if vif;
  virtual serial_tbif tb_vif;
  
  function new();
    g0 = new;
    d0 = new;
    m0 = new;
    s0 = new;
    drv_mbx = new;
    scb_mbx = new;
    
    g0.drv_mbx = drv_mbx;
    d0.drv_mbx = drv_mbx;
    m0.scb_mbx = scb_mbx;
    s0.scb_mbx = scb_mbx;
    
    g0.drv_done = drv_done;
    d0.drv_done = drv_done;
  endfunction
  
  virtual task run();
    d0.vif = vif;
    m0.vif = vif;
    
    d0.tb_vif = tb_vif;
    m0.tb_vif = tb_vif;
    
    fork
      begin
        g0.run_oddpar();
        g0.run_evenpar();
      end
      d0.run();
      m0.run();
      s0.run();
    join_any
  endtask
endclass


// test: run the environment

class test;
  env e0;
  
  function new();
    e0 = new;
  endfunction
  
  task run();
    e0.run();
  endtask
endclass


// top module

module tb;
  bit clk;
  
  always #5 clk = ~clk;
  
  serial_if _if (clk);
  serial_tbif _tbif ();
  
  serial u0 (	.clk(clk),
             	.in(_if.in),
             	.reset(_if.reset),
             	.out_byte(_if.out_byte),
             	.done(_if.done)				);
  
  test t0;
  
  initial begin
    clk <= 0;
    _if.reset <= 1;
    
    repeat(3) @(posedge clk);
    _if.reset <= 0;
    
    t0 = new;
    t0.e0.vif = _if; //connect virtual interface to interface
    t0.e0.tb_vif = _tbif;
    t0.run();
    #10 $finish;
  end
  
  // Dump VCD waveform file
  initial begin
    $dumpfile ("dump.vcd");    
    $dumpvars;
  end
endmodule
