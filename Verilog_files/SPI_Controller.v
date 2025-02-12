
// SPI Controller module for handling SPI communication
module SPI_Controller (
    input clk,                // System clock
    input IRQ_OUT,
    output reg IRQ_IN,
    input rst_n,              // Active low reset
    input miso,               // Master In Slave Out
    output reg mosi,          // Master Out Slave In
    output reg sck,           // SPI Clock
    output reg cs,            // SPI Slave Select (active low)
    input [79:0] tx_data,      // Data to transmit
    output reg [7:0] rx_data, // Received data
    input start,              // Start signal
    output reg busy,         // Busy ignal
    output wire poweredup,
    input wire [7:0] BitsToSend
);

    // SPI clock divider for slower communication
    parameter CLK_DIV = 20; // Generates 1.25 MHz SCK for 50 MHz clock 
    reg [4:0] clk_count;
    reg LEN_FOUND = 0;
    reg [7:0] bit_count;
    reg [79:0] shift_reg;
    reg [79:0] whatHEgets;

    reg [7:0] LEN = 0;

    // SPI state machine states
    reg [1:0]               spi_state;
    localparam              SPI_IDLE   = 2'b00,
                            SPI_START  = 2'b01,
                            SPI_TRANSFER = 2'b10,
                            SPI_DONE   = 2'b11;
    
    reg                     powered = 0;
    reg [12:0]              counter = 0;
    reg                     POLLING = 0;

    
    assign poweredup = powered;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            powered <= 0;
            sck <= 0;
            cs <= 1;
            mosi <= 0;
            busy <= 0;
            rx_data <= 0;
            clk_count <= 0;
            bit_count <= 0;
            shift_reg <= 0;
            spi_state <= SPI_IDLE;
            POLLING <= 0;
        end 
        else 
            begin
                if (!powered)
                    begin
                        IRQ_IN <= 1;
                        counter <= counter + 1'b1;
                        if(counter>13'd5050)
                            begin
                                IRQ_IN <= 0;
                                if(counter>13'd5600)
                                    begin
                                        powered <= 1;
                                        counter <= 0;
                                    end
                            end
                    end
                else
                    begin
                        IRQ_IN <= 1;
                
                        case (spi_state)
                            SPI_IDLE: begin
                                sck <= 0;
                                cs <= 1;
                                if (start) begin
                                    busy <= 1;
                                    spi_state <= SPI_START;
                                end
                            end
                            SPI_START:  begin
                                    shift_reg <= tx_data;
                                    if(tx_data=={8'h03,72'b0})
                                        begin
                                            POLLING <= 1'b1;
                                        end
                                    spi_state <= SPI_TRANSFER;       
                            end
                            SPI_TRANSFER: begin
                                cs <= 0;
                                if (clk_count == (CLK_DIV - 1)) begin
                                    clk_count <= 0;
                                    sck <= ~sck;
                                    if (!sck) begin
                                        mosi <= shift_reg[79];
                                        whatHEgets <= {whatHEgets[78:0],shift_reg[79]};
                                        shift_reg <= {shift_reg[78:0], miso};
                                        bit_count <= bit_count + 8'b1;
                                        if (bit_count == (BitsToSend - 1'b1)) begin
                                            LEN<=8'h00;
                                            bit_count <= 8'b00;
                                            spi_state <= SPI_DONE;
                                        end
                                    end
                                end else begin
                                    clk_count <= clk_count + 1'b1;
                                end
                            end

                            SPI_DONE: begin
                                if (clk_count == (CLK_DIV - 1)) begin
                                    clk_count <= 0;
                                    sck <= ~sck;
                                    if (!sck) begin
                                        shift_reg <= {shift_reg[78:0], miso};
                                        bit_count <= bit_count + 1'b1;
                                        if (!POLLING) begin
                                            if(LEN_FOUND == 0 && bit_count == 8'd15)
                                                begin
                                                    LEN_FOUND <= 1;
                                                    LEN <= shift_reg[15:8];
                                                    if (shift_reg[15:8]==8'b0) begin
                                                        LEN_FOUND <= 0;
                                                        busy <= 0;
                                                        bit_count<=0;
                                                        spi_state <= SPI_IDLE;
                                                        sck <= 0;
                                                        cs <= 1;
                                                        shift_reg <= 0;
                                                    end
                                                    shift_reg <= 0;
                                                end
                                            else if (LEN_FOUND == 1'b1 && LEN == 8'b1) begin
                                                LEN_FOUND <=0;
                                                bit_count <=0;
                                                spi_state <= SPI_IDLE;
                                                sck <= 0;
                                                cs <= 1;
                                                busy <= 0;
                                                rx_data <= shift_reg[7:0];
                                                LEN_FOUND <= 0;
                                            end
                                            else if(LEN_FOUND == 1 && bit_count == 8'd7)
                                                begin
                                                    busy <= 0;
                                                    rx_data <= shift_reg[7:0];
                                                    shift_reg <= 0;
                                                    LEN <= LEN - 1'b1;
                                                    bit_count <= 0;
                                                end
                                        end
                                        else
                                            begin
                                                if(bit_count < 8)
                                                    begin
                                                        bit_count <= 0;
                                                        LEN_FOUND <= 0;
                                                        busy <= 0;
                                                        rx_data <= shift_reg[7:0];
                                                        shift_reg <= 0;
                                                        POLLING <= 0;
                                                        spi_state <= SPI_IDLE;
                                                    end
                                            end
                                    end
                                end else begin
                                    clk_count <= clk_count + 1'b1;
                                end
                            end

                        endcase
                end
            end
    end
endmodule


// module SPI_COM_RFID
// (
//    input wire clk,
//    input wire SDO,
//    input wire SPI_INTERRUPT,
//    input rst_n,
//    output reg sclk,
//    output reg cs,
//    output reg SDI,
//    output reg [1:0] INTERFACE_SELECT,
//    output reg valid,
//    output reg access_granted,
//    input wire start_transfer     
// );

//    parameter CLK_DIV = 20;        // Divider for 1.25 MHz SPI clock
//    reg [4:0] clk_divider;         // Counter for SPI clock generation
//    reg [4:0] bit_counter;         // Counter for bits transferred
//    reg [7:0] shift_reg;           // Shift register for received data
//    reg [7:0] tag_id;              // Captured tag ID
//    reg spi_clk_en;                // SPI clock enable signal
//    reg [7:0] valid_ids [0:3];     // Array of valid IDs (predefined for permission checking)
//    reg [31:0] counter;

//    // State encoding
//    parameter IDLE     = 2'b00;
//    parameter COMMANDS = 2'b01;
//    parameter TRANSFER = 2'b10;
//    parameter DONE     = 2'b11;

//    parameter [7:0] POLLING = 8'b00000011;

//    reg [1:0] state;

//     // Clock divider for SPI clock generation (1.25 MHz)
//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             clk_divider <= 0;
//             sclk <= 0;
//             spi_clk_en <= 0;
//         end else if (clk_divider == (CLK_DIV - 1)) begin
//             clk_divider <= 0;
//             sclk <= ~sclk;          // Toggle SPI clock
//             if(sclk==0)
//                 begin
//                     spi_clk_en <= 1;        // Enable SPI clock edge for data sampling
//                 end
//         end else begin
//             clk_divider <= clk_divider + 1;
//             spi_clk_en <= 0;
//         end
//     end

//     // Reset-driven initialization of valid IDs
//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             valid_ids[0] <= 8'hA1;
//             valid_ids[1] <= 8'hB2;
//             valid_ids[2] <= 8'hC3;
//             valid_ids[3] <= 8'hD4;
//         end
//     end

//     // SPI state machine
//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             state <= IDLE;
//             cs <= 1;
//             bit_counter <= 0;
//             shift_reg <= 0;
//             tag_id <= 0;
//             valid <= 0;
//             access_granted <= 0;
//             counter<=0;
//             INTERFACE_SELECT<=2'b00;
//         end else begin
//             case (state)
//                 IDLE: begin
//                     INTERFACE_SELECT<=2'b01;
//                     cs <= 1;
//                     valid <= 0;
//                     if (start_transfer)
//                         begin
//                             access_granted <= 0;
//                             counter <= 0;
//                             cs <= 0;
//                             bit_counter <= 15;
//                             shift_reg <= 0;
//                             state <= COMMANDS;
//                         end
//                     if (access_granted) 
//                         begin
//                             if (counter==150000000) 
//                                 begin
//                                     counter <= 0;
//                                     access_granted <= 0;
//                                 end
//                             else
//                                 begin
//                                     counter <= counter + 1'b1;
//                                 end
//                         end
//                 end
                
//                 COMMANDS: begin
//                      if (16 > bit_counter > 8) 
//                         begin
//                             bit_counter <= bit_counter - 1'b1;
//                             SDI <= POLLING[bit_counter - 8];
//                         end
//                      else if (8 >= bit_counter >= 0 )
//                         begin
//                             bit_counter <= bit_counter - 1'b1;
//                             SDI <= READ[bit_counter];
//                         end
//                      else
//                         begin
                            
//                         end
//                 end

//                 TRANSFER: begin
//                     if (spi_clk_en) begin
//                       if (bit_counter == 7) 
//                             begin           // Transfer complete after 8 bit
//                                 tag_id <= {shift_reg[6:0],SDO};                     // Capture received tag ID
//                                 state <= DONE;
//                                 cs <= 1;
//                             end
//                         else
//                             begin
//                                 shift_reg <= {shift_reg[6:0], SDO};  // Shift in data from SDO
//                                 bit_counter <= bit_counter + 1;
//                             end
//                     end
//                 end

//                 DONE: begin
//                     counter<=counter+1'b1;
//                     valid <= 1;                              // Indicate valid data
//                     access_granted <= check_permission(tag_id);
//                     state <= IDLE;
//                 end
//             endcase
//         end
//     end

//     // Function to check if the received tag ID is in the valid list
  

// endmodule
