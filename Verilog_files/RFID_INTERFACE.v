// Standard Verilog module to interface CR95HF RFID reader and validate card permissions
module RFID_INTERFACE (
    output wire IRQ_IN,              // Interrupt from CR95HF
    input wire IRQ_OUT,                  // Interrupt output for external use
    input clk,                      // System clock
    input rst_n,                    // Active low reset                        
    input miso,                     // SPI MISO from CR95HF
    output mosi,                    // SPI MOSI to CR95HF
    output sck,                     // SPI clock
    output cs,                      // SPI chip select (active low)
    output reg valid_card,          // Output signal for valid card detection
    output reg [31:0] card_uid      // Captured card UID (optional for validation)
);
    reg [31:0] valid_ids [0:3];
    // Parameters for commands
    parameter CMD_PROTOCOL_SELECT = 8'h02;
    parameter CMD_POLLING         = 8'h03;
    parameter CMD_SEND_RECV       = 8'h04;
    parameter PROTOCOL_ISO14443A  = 8'h02;
    parameter RST_SPI             = 8'h01; // ill figure out how to do the rst later

    // SPI signals
    reg [79:0] spi_tx_data = 0;
    reg [7:0] BitsToSend = 0;
    reg spi_start = 0;   
    wire spi_busy;
    wire [7:0] spi_rx_data;
    reg [15:0] clk_counter = 0;
    wire powered;
    reg [1:0] received_full = 0;



    // State machine states
    reg [2:0] state;
    parameter IDLE          = 3'b000,
               PROTOCOL_SEL  = 3'b001,
               POLLING       = 3'b010,
               SEND_RECV     = 3'b011,
               WAIT_RESPONSE = 3'b100,
               PROCESS_DATA  = 3'b101,
               sent          = 1'b0,
               collision     = 1'b1;
    reg requesting =  sent;
    reg flag = 0;

    // Registers for data handling
    reg [31:0] received_uid;
    reg commandSent = 0;


    // SPI module instantiation (assume SPI_Controller module is available)
    SPI_Controller spi_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .miso(miso),
        .BitsToSend(BitsToSend),
        .mosi(mosi),
        .sck(sck),
        .cs(cs),
        .IRQ_IN(IRQ_IN),
        .IRQ_OUT(IRQ_OUT),
        .tx_data(spi_tx_data),
        .rx_data(spi_rx_data),
        .start(spi_start),
        .busy(spi_busy),
        .poweredup(powered)
    );

    // State machine logic
    always @(posedge clk or negedge rst_n) 
        begin
            if (!rst_n)
                begin
                    received_full <= 0;
                    state <= IDLE;
                    received_full <= 0;
                    clk_counter <= 0;
                    spi_tx_data <= 0;
                    spi_start <= 0;
                    valid_ids[0]    <=32'hb364de05; 
                    valid_ids[1]    <=32'h33221100; 
                    valid_ids[2]   <=32'h01234567; 
                    valid_ids[3]    <=32'h76543210; 
                end
            else
                begin
                    clk_counter <= clk_counter + 1'b1;
                    if (clk_counter>50000 && state != PROCESS_DATA) 
                        begin
                            clk_counter <= 0;
                            valid_card <= 0;        
                        end
                    if (powered) 
                        begin
                            // Default values
                            case (state)
                                IDLE: begin
                                    spi_tx_data <= {8'h00,CMD_PROTOCOL_SELECT,24'h020200,40'b0};
                                    BitsToSend <= 8'd40;
                                    spi_start <= 1'b1;
                                    state <= POLLING;
                                end
                                POLLING: begin
                                    if (!spi_busy && flag) 
                                        begin
                                            flag <= 0;
                                            if(spi_rx_data == 8'h04)
                                                begin
                                                    state <= SEND_RECV;    
                                                end
                                            else
                                                begin
                                                    BitsToSend <= 8'd8;
                                                    spi_start <= 1;
                                                    spi_tx_data <= {CMD_POLLING,72'b0}; // POLLING command
                                                end
                                        end
                                    else
                                        begin
                                            spi_start <= 0;
                                            flag <= 1;  
                                        end
                                end

                                SEND_RECV: begin
                                    if (!spi_busy && flag) begin
                                        flag <= 0;
                                        case(requesting) 
                                            sent: begin
                                                spi_tx_data <= {CMD_SEND_RECV,32'h04022607,40'b0}; // SENDRECV command
                                                BitsToSend <= 8'd40;
                                                requesting<=collision;
                                                spi_start <= 1;
                                            end
                                            collision: begin
                                                requesting<=sent;
                                                spi_start <= 1;
                                                spi_tx_data <= {40'h0403932008,40'b0}; 
                                                BitsToSend <= 8'd40;
                                                state <= WAIT_RESPONSE;
                                            end
                                        endcase
                                    end
                                    else
                                        begin
                                            spi_start <= 0;
                                            flag <= 1;
                                        end
                                end

                                WAIT_RESPONSE: begin
                                    if (!spi_busy && flag) begin
                                        received_uid <= {received_uid[23:0], spi_rx_data}; // Shift in response data
                                        received_full <= received_full + 1'b1;
                                        if (received_full==3) begin
                                            state <= PROCESS_DATA;
                                            received_full <= 0;
                                        end
                                    end
                                    else
                                        begin
                                            flag<=1;
                                        end
                                end

                                PROCESS_DATA: begin
                                    valid_card <= check_permission(received_uid);  // checks uids of cards
                                    card_uid <= received_uid;                      // Store captured UID maybe ill want to add what id card was used?
                                    state <= IDLE;                    
                                end
                            endcase
                        end
                    else   
                        begin
                            spi_start <= 0;
                            state <= IDLE;
                        end
                end
        end

        function check_permission;
            input [31:0] id;
            integer i;
            begin
                check_permission = 0;  // Default to no access
                for (i = 0; i < 4; i = i + 1) begin
                    if (id == valid_ids[i]) begin
                        check_permission = 1;  // Grant access if ID matches
                    end
                end
            end
        endfunction

endmodule
