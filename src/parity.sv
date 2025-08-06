module parity (
    input logic clk,
    input logic reset,
    input logic in,
    output logic odd);

  	always @(posedge clk) begin
        if (reset) odd <= 0;
        else if (in) odd <= ~odd;
    end
endmodule
