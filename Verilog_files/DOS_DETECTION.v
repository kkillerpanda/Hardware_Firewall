module ddos_check (
    input wire clk,
    input wire rst_n,
    input wire [1:0] rxd,
    output reg alert,                // Signal indicating a threat has been detected
    output  reg [31:0] ip_addr_export,           // Current IP address to export
    output  reg [47:0] mac_addr_export,          // Current MAC address to export 
    output  reg [15:0] port_export,               // Current port access to export
	input wire data_capture
);
    // Parameters for threshold and tracking
    parameter IDLE = 3'b0,MAC_state=3'b001, IP_state = 3'b010, PORT_State = 3'b011,TYPE =3'b100, CHECK = 3'b101;
    parameter DDoS_THRESHOLD = 100 ; // Packets per time period

	reg [2:0] state;
    reg [31:0] ip_addr;
    reg [47:0] mac_addr;
    reg [15:0] port;
    reg [31:0] ip_table [0:50];
    reg [6:0] ip_packet_count [0:50]; // Count of packets for each IP
    reg [26:0] last_checked_time;   // Last checked time (could be a simple counter)
	reg [7:0] positional_timer;
    reg [15:0] type;
    reg flag = 0;
    integer i = 0;

    // Reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 50; i = i + 1) 
                begin
                    ip_packet_count[i] <= 7'b0; // Reset all IP counts
                    ip_table[i] <= 32'b0;
                end
            last_checked_time <= 27'b0;
            alert <= 1'b0;
            state<=IDLE;
            positional_timer<=0;
            type<=16'b0;
            flag <= 0;
            ip_addr_export <= 32'b0;
            mac_addr_export <= 48'b0;
            ip_addr <= 32'b0;
            mac_addr <= 48'b0;
            port <= 16'b0;
            port_export <= 16'b0;
        end 
        else 
            begin
                last_checked_time<=last_checked_time+1'b1;
		        if(data_capture)
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
                                            mac_addr<={mac_addr[45:0],rxd};
											state<=MAC_state;
											positional_timer<=0;
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
									else if (positional_timer<8'd94)
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
                                        end
                                end
							CHECK:
								begin
                                    flag <= 1;
                                    if (!flag)
                                        begin
                                            for (i = 0;i < 50 ;i=i+1'b1 )
                                                begin
                                                    if (ip_table[i]==ip_addr)
                                                        begin
                                                            ip_packet_count[i]<=ip_packet_count[i]+1'b1;
                                                            if (ip_packet_count[i] > DDoS_THRESHOLD) 
                                                                begin
                                                                    alert <= 1'b1; // Detected DDoS attack
                                                                    ip_addr_export <= ip_addr;
                                                                    mac_addr_export <= mac_addr;
                                                                    port_export <= port;
                                                                end 
                                                            else 
                                                                begin
                                                                    alert <= 1'b0; // No threat detected
                                                                end
                                                        end
                                                    else if(ip_table[i]==32'b0)
                                                        begin
                                                            ip_table[i] <= ip_addr;
                                                        end
                                                end
                                        end
                                end
                        endcase
                    end
                    else
                        begin
                            state<=IDLE;
                            flag <= 0;
                            positional_timer<=0;
                        end
                if(last_checked_time>27'h07735940)
                    begin
                        for (i = 0; i < 50; i = i + 1) 
                            begin
                                ip_packet_count[i] <= 7'b0; // Reset all IP counts
                                ip_table[i] <= 32'b0;
                            end
                        last_checked_time <= 27'b0;
                    end
            end
    end
endmodule


// module dos_attack_detector (
//     input wire clk,
//     input wire rst,
//     input wire rx_valid,       // Valid signal for received data
//     output reg alert           // DoS attack alert
// );

//     reg [31:0] packet_count;   // Packet counter
//     reg [31:0] timer;          // Timer for detection window

//     always @(posedge clk or negedge rst) begin
//         if (!rst) begin
//             packet_count <= 32'b0;
//             timer <= 32'b0;
//             alert <= 1'b0;
//         end else begin
//             // Increment timer
//             timer <= timer + 1;

//             if (rx_valid) begin
//                 packet_count <= packet_count + 1;  // Increment packet count on valid packet reception
//             end

//             // Check if packet rate exceeds threshold (e.g., 1000 packets in 1 second)
//             if (packet_count > 1000 && timer < 32'd50000000) begin
//                 alert <= 1'b1;  // DoS attack detected
//             end

//             // Reset packet count and timer periodically (e.g., every 1 second)
//             if (timer >= 32'd50000000) begin
//                 timer <= 32'b0;
//                 packet_count <= 32'b0;
//                 alert <= 1'b0;  // Reset alert after each time window
//             end
//         end
//     end

// endmodule
