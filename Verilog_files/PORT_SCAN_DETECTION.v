module port_scanning_check (
    input   wire clk,
    input   wire rst_n,
    input   wire [1:0] rxd,
    output  reg alert,                           // Signal indicating a threat has been detected
    output  reg [31:0] ip_addr_export,           // Current IP address to export
    output  reg [47:0] mac_addr_export,          // Current MAC address to export 
    output  reg [15:0] port_export,               // Current port access to export
	input wire data_capture
);
    // Parameters for threshold and tracking
    parameter IDLE = 3'b0,MAC_state=3'b001, IP_state = 3'b010, PORT_State = 3'b011, TYPE =3'b100, CHECK = 3'b101; // State of packet
    parameter Empty = 16'b0;
    parameter SCAN_THRESHOLD = 5;       // Threshold for scanning
    reg [31:0] ip_tracker [0:50];      // Tracking IP addresses
    reg [31:0] ip_addr;                 // Current IP address
    reg [47:0] mac_addr;                // Current MAC address
    reg [15:0] port;                    // Current port access
    reg [79:0] port_instance [0:50];   // Count of accessed ports
    reg [2:0] state;                    // Positional state of current packet
    reg [7:0] positional_timer;         // Positional timer of the packet
    integer i = 0;
    reg [27:0] timed_reset;             // Timer for periodic reset
	reg [15:0] type;
    reg flag = 0;
    reg found = 0;



    // Reset logic
    always @(posedge clk or negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            for (i = 0; i < 50; i = i + 1) 
                begin 
                    ip_tracker[i] <= 32'b0; // Reset all IP trackers
                    port_instance[i] <= 80'b0;  // Reset all port counts
                end
            ip_addr_export <= 32'b0;
            mac_addr_export <= 48'b0;
            ip_addr <= 32'b0;
            mac_addr <= 48'b0;
            port <= 16'b0;
            port_export <= 16'b0;
			positional_timer<=8'b0;
            alert <= 1'b0;
            state<=IDLE;
            timed_reset<=27'b0;
            type<=16'b0;
            flag <= 0;
        end 
        else 
            begin
                timed_reset <= timed_reset+1'b1;
                if (data_capture) 
                    begin
                        case(state)
                            IDLE:
                                begin	
                                    if(positional_timer<8'd100)
                                        begin
                                            positional_timer<=positional_timer+2'd2;
                                        end
                                    else
                                        begin
                                            state<=MAC_state;
                                            positional_timer<=8'b0;
                                        end
                                end
                            MAC_state:
                                begin
                                    positional_timer<=positional_timer+2'd2;
                                    if(positional_timer<=8'd46)
                                        begin
                                            mac_addr<={mac_addr[45:0],rxd};
                                        end
                                    else
                                        begin
                                            type<={type[13:0],rxd};
                                            state<=TYPE;
                                            positional_timer<=0;
                                        end
                                end
                            TYPE:
                                begin
                                    positional_timer<=positional_timer+2'd2;
                                    if(positional_timer<=8'd12)
                                        begin
                                            type<={type[13:0],rxd};
                                        end
                                    else if(type==16'h0800)
                                        begin
                                            state<=IP_state;
                                            positional_timer<=0;
                                        end
                                    else
                                        begin
                                            state<=IDLE;
                                            positional_timer<=0;
                                        end 
                                end
                            IP_state: 
                                begin
                                    positional_timer<=positional_timer+2'd2;
                                    if(8'd94<=positional_timer && positional_timer<=8'd124)
                                        begin
                                            ip_addr<={ip_addr[29:0],rxd};
                                        end
                                    else if(positional_timer<8'd94)
                                        begin

                                        end
                                    else
                                        begin
                                            state<=PORT_State;
                                            positional_timer<=0;
                                        end
                                end
                            PORT_State:
                                begin
                                    positional_timer<=positional_timer+2'd2;
                                    if(8'd46<=positional_timer && positional_timer<=8'd60)
                                        begin
                                            port<={port[13:0],rxd};
                                        end
                                    else if (positional_timer<8'd46)
                                        begin
                                            
                                        end
                                    else
                                        begin
                                            state<=CHECK;
                                            positional_timer<=0;
                                            found = 0;  
                                        end
                                end
                            CHECK:
                                begin
                                    flag <= 1;
                                    // Check if the incoming IP address is already tracked
                                    if (!flag)
                                        begin
                                            for (i = 0; i < 50 ; i = i + 1) 
                                            begin
                                                    begin
                                                        if(ip_addr==ip_tracker[i])
                                                            begin
                                                            found = 1;
                                                                // Port is already recorded, no need to add it again
                                                                if (port_instance[i][15:0] == port  || 
                                                                    port_instance[i][31:16] == port || 
                                                                    port_instance[i][47:32] == port || 
                                                                    port_instance[i][63:48] == port || 
                                                                    port_instance[i][79:64] == port) 
                                                                    begin
                                                                        alert <= 0;
                                                                    end
                                                                else
                                                                    begin
                                                                        // If the port is not found, insert it into the first available empty slot
                                                                        port_instance[i]<={port_instance[i][63:0],port};
                                                                        if(port_instance[i][79:64]!=Empty)
                                                                            begin
                                                                                alert <= 1'b1;  // All slots are full; raise alert for port scanning
                                                                                ip_addr_export <= ip_addr;
                                                                                mac_addr_export <= mac_addr;
                                                                                port_export <= port;
                                                                            end
                                                                    end
                                                            end
                                                        else if(ip_tracker[i] == 32'b0 && !found) 
                                                            begin
                                                                found = 1;
                                                                // If the IP is new, add it to the table
                                                                ip_tracker[i] <= ip_addr;
                                                                port_instance[i]<={64'b0,port};
                                                            end
                                                    end
                                            end
                                        end
                                end
                        endcase
                    end
                else
                    begin
                        flag<=0;
                        state<=IDLE;
                        positional_timer<=0;
                    end
                if(timed_reset>27'h07735940)
                    begin
                        for (i = 0; i < 50; i = i + 1) 
                            begin 
                                ip_tracker[i] <= 32'b0; // Reset all IP trackers
                                port_instance[i] <= 80'b0;  // Reset all port counts
                            end
                        timed_reset<=27'b0;
                    end
            end         
    end
endmodule


// module port_scanning_detector (
//     input wire clk,
//     input wire rst,
//     input wire [15:0] dest_port,  // Destination port of the received packet
//     input wire rx_valid,          // Valid signal for received data
//     output reg alert              // Port scanning alert
// );

//     reg [15:0] port_table [0:15];  // A table of recently accessed ports
//     reg [3:0] port_count;          // Counter for unique ports
//     reg [31:0] timer;              // Timer for detecting scan within a time window

//     integer i;

//     always @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             port_count <= 4'b0;
//             alert <= 1'b0;
//             timer <= 32'b0;
//             for (i = 0; i < 16; i = i + 1) begin
//                 port_table[i] <= 16'b0;
//             end
//         end else begin
//             // Increment the timer for time window
//             timer <= timer + 1;

//             if (rx_valid) begin
//                 // Reset alert by default
//                 alert <= 1'b0;
                
//                 // Check if the port is already recorded
//                 for (i = 0; i < 16; i = i + 1) begin
//                     if (port_table[i] == dest_port) begin
//                         // Port already accessed, no need to record again
                       
//                     end else if (port_table[i] == 16'b0) begin
//                         // New port accessed, record it
//                         port_table[i] <= dest_port;
//                         port_count <= port_count + 1;
                       
//                     end
//                 end
//             end

//             // Check for port scanning condition
//             if (port_count > 4 && timer < 32'd500000) begin
//                 alert <= 1'b1;  // Port scanning detected if more than 4 ports accessed within time window
//             end

//             // Reset timer and port count periodically (e.g., every 500ms)
//             if (timer >= 32'd500000) begin
//                 timer <= 32'b0;
//                 port_count <= 4'b0;
//                 for (i = 0; i < 16; i = i + 1) begin
//                     port_table[i] <= 16'b0;
//                 end
//             end
//         end
//     end

// endmodule
