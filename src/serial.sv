`include "parity.sv"

// general design-test interface
interface serial_if (input bit clk);
  
  logic in;
  logic reset;
  logic [7:0] out_byte;
  logic done;
  
endinterface

// interface for some extra testbench variables
interface serial_tbif();
  
  bit [7:0] in_byte;
  bit par_bit;
  bit stop_bit;
  bit odd_parity; 
  
  bit pckt_sent;
  
endinterface

// Design module
module serial(
    input logic clk,
    input logic in,
    input logic reset,    // Synchronous reset
    output logic [7:0] out_byte,
    output logic done
); 

  	// states
	  parameter I=0,B1=1,B2=2,B3=3,B4=4,B5=5,B6=6,B7=7,B8=8,P=9,S=10,V=11,NV=12;
  
    logic [12:0] state, next_state; 
    logic temp1, temp2;
    logic parity_reset, odd;
    
    //next_state logic
    assign next_state[I]  = ( in && ( state[NV] || state[I] || state[V] ) );
    assign next_state[B1] = ( !in && ( state[I] || state[V] ) );
    assign next_state[B2] = ( state[B1] );
    assign next_state[B3] = ( state[B2] );
    assign next_state[B4] = ( state[B3] );
    assign next_state[B5] = ( state[B4] ); 
    assign next_state[B6] = ( state[B5] );
    assign next_state[B7] = ( state[B6] );
    assign next_state[B8] = ( state[B7] );
    assign next_state[P]  = ( state[B8] );
    assign next_state[S]  = ( state[P] );
    assign next_state[NV] = ( !in && ( state[NV] || state[S] ) );
    assign next_state[V]  = ( in && state[S] );
    
    //flip-flops
    always @(posedge clk) begin
        if (reset) begin
            state <= 13'b1;
        end
        else begin
            state <= next_state;
        end
    end
    
    //output logic
  	assign done = ( state[V] && odd );

    // Datapath to latch input bits: Ignore parity and stop bits.
    always @(posedge clk) begin
        temp1 <= in;
        temp2 <= temp1;
      	out_byte[7:0] <= { temp2, out_byte[7:1] };
    end       
    
    // Parity checking: Toggle flip-flop with reset
    assign parity_reset = ( reset || ( !in && ( state[I] || state[V] ) ) );
   
    parity inst1 (.clk(clk),.reset(parity_reset),.in(temp1),.odd(odd));

endmodule
