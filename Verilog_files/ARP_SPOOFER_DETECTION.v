module arp_spoofing_detector (
    input wire clk,
    input wire rst_n,
	input [1:0] rxd,
    output reg alert,             					// Spoofing alert
	output  reg [31:0] ip_addr_export,           	// Current IP address to export
    output  reg [47:0] mac_addr_export, 		 		// Current MAC address to export
	input wire data_capture
);
	parameter [2:0] IDLE=3'b000, IP_state=2'b001, MAC_state=3'b010, TYPE =3'b011, CHECK=3'b100;
    // A simple table for IP to MAC mapping (assume up to 50 IP addresses for this instance)
	reg [2:0] state;
	reg [31:0] ip_addr;
	reg [47:0] mac_addr;
    reg [31:0] ip_table [0:50];    // Table of known IP addresses
    reg [47:0] mac_table [0:50];   // Corresponding MAC addresses
	reg [7:0] positional_timer;
	reg [15:0] type;
	reg flag = 0;
    integer i = 0;

    always @(posedge clk or negedge rst_n) 
	begin
        if (!rst_n)
			begin
            // Reset the tables and clear the alert
            	for (i = 0; i < 51; i = i + 1)
					begin
                		ip_table[i] <= 32'b0;
                		mac_table[i] <= 48'b0;
            		end
				ip_addr_export <= 32'b0;
				mac_addr_export <= 48'b0;
				ip_addr <= 32'b0;
				mac_addr <= 48'b0;
            	alert <= 1'b0;
				state<=IDLE;
				positional_timer<=0;
				type<=16'b0;
				flag <= 0;
        	end
			else
				begin
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
												mac_addr<={mac_addr[45:0],rxd};
												state<=MAC_state;
												positional_timer<=0;
											end
									end
								MAC_state:
									begin
										positional_timer<=positional_timer+2'd2;
										if (positional_timer<=8'd46)
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
										else if(type==16'h0806)
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
										if(8'd110<=positional_timer && positional_timer<=8'd140)
											begin
												ip_addr<={ip_addr[29:0],rxd};
											end
										else if(positional_timer<8'd110)
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
										if(!flag)
											begin
												for (i = 0; i < 51; i = i + 1) 
													begin
														// Check if IP exists in the table
														if (ip_table[i] == ip_addr) 
															begin
															// If the IP exists, check for MAC address inconsistency
															if (mac_table[i] != mac_addr)
																begin
																	alert <= 1'b1;  // ARP spoofing detected
																	ip_addr_export <= ip_addr;
																	mac_addr_export <= mac_addr;
																end
															end 
															else if (ip_table[i] == 32'b0) 
																begin
																	// If the IP is new, add it to the table
																	ip_table[i] <= ip_addr;
																	mac_table[i] <= mac_addr;
																end
													end
											end
									end
							endcase
						end
						else
							begin
								flag <= 0; 
								state<=IDLE;
								positional_timer<=0;
							end
				end
	end
endmodule

// // module ARP_SPOOFER_DETECTION
// // (
// // 	input [1000:0] Incoming_packet_buffer,
// // 	input refCLK,
// // 	input [15:0] p_type,
// // 	input ARP_reply,
// // 	//input [7:0] ip_type,
// // 	input [31:0] ip,
// // 	//input [47:0] mac,
// // 	output sus
// // );
// // parameter IPv4=16'h0800,IPv6=16'h86DD; 
// // reg [31:0] original_ipv4 [49:0];
// // reg [127:0] original_ipv6 [49:0];
// // reg [47:0] original_mac [49:0];

// // always@(posedge refCLK)
// // 	begin
// // 		if(ARP_reply)
// // 			begin
// // 				case(ip)
// // 					IPv4:
// // 						begin
							
// // 						end
// // 					IPv6:
// // 						begin
							
// // 						end
// // 					default:
// // 						begin
// // 						end
// // 				endcase
// // 			end	
// // 	end


// // endmodule