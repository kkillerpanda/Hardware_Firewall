
module rmii_processor (
    input wire       clk,                  // 50 MHz clock
    input wire       rst_n,                // Active-low reset signal
    input wire       close_connection,		 // Close the connection signal
		
    // RMII interface
    input wire [1:0] rxd,                  // Received data (2 bits)
    input wire       crs_dv,               // Carrier sense / data valid signal
	input wire		 sigdet,           
    output reg [1:0] txd,                   // Transmit data (2 bits)
    output reg       tx_en,                 // Transmit enable signal
    output reg data_capture
);
    //reg data_capture = 1'b0;
    reg last_state=1'b0;                         //Buffer for last state of crs_dv
    // Internal signals for packet processing
    reg [1:0] rx_data=2'b0;                     // Buffer for received data
    // Always block for processing
    always @(posedge clk or negedge rst_n)
        begin
            if (!rst_n)
                begin
                    // Reset the transmit signals
                    data_capture<=1'b0;
                    txd <= 2'b00;
                    tx_en <= 1'b0;
                    rx_data <= 2'b00;
                    last_state<=1'b0;       // We want this to be 1 so it doesn't shut
                end 
            else 
                begin
                    last_state<=crs_dv;
                    if (data_capture)
                        begin
                            // Capture incoming data in fifo
                            rx_data <= rxd;
                            // Forward the received data to the transmit line
                            txd <= rx_data;  // Transmit the received data
                            tx_en <= 1'b1;   // Enable transmission
                            if (!last_state && !crs_dv) 
                                begin
                                    last_state<=1'b0;
                                    tx_en<=1'b0;
                                    rx_data<=2'b0;
                                    txd<=rx_data;
                                    data_capture<=1'b0;
                                end
                        end
                    else if ((sigdet && (crs_dv && rxd==2'b01)  && !close_connection)) 
                        begin
                            data_capture<=1'b1;
                            // Capture incoming data in fifo
                            rx_data <= rxd;
                            // Forward the received data to the transmit line
                        end
                    else 
                        begin
                            // No valid data to transmit
                            tx_en <= 1'b0;   // Disable transmission
                            txd<=2'b0;
                        end
                end
        end

endmodule
