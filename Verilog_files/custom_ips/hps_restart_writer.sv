module hps_restart_writer 
(
    input               clk,         // Clock signal
    input               reset_n,     // Active-low reset signal from HPS
    input  [7:0]        hps_reset_export,
    output reg          hps_restart   // Reset signal to the top-level entity
);
    // Writing logic
    always @(posedge clk or negedge reset_n) 
    begin
        if (!reset_n) 
        begin
            hps_restart <= 1'b0;
        end 
        else
            if (hps_reset_export==8'h01) 
            begin
                hps_restart <= 1'b1;  // Capture the least significant bit
            end
    end
endmodule
