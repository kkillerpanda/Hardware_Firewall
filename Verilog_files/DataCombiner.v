module DataCombiner (
    output  reg  [127:0] data_out,
    input   wire n_rst,
    input   wire clk,
    input   wire arp_spoofing_threat_phy1,
    input   wire port_scanning_threat_phy1,
    input   wire ddos_threat_phy1,
    input   wire arp_spoofing_threat_phy2,
    input   wire port_scanning_threat_phy2,
    input   wire ddos_threat_phy2,
    input   wire close_connection_phy2_to_phy1,
    input   wire close_connection_phy1_to_phy2,
    input   wire [31:0] ip_addr_arp1,                // Current IP address
    input   wire [47:0] mac_addr_arp1,               // Current MAC address
    input   wire [31:0] ip_addr_dos1,                // Current IP address
    input   wire [47:0] mac_addr_dos1,               // Current MAC address
    input   wire [15:0] port_dos1,                   // Current port access
    input   wire [31:0] ip_addr_port1,                // Current IP address
    input   wire [47:0] mac_addr_port1,               // Current MAC address
    input   wire [15:0] port_port1,                   // Current port access
    input   wire [31:0] ip_addr_arp2,                // Current IP address
    input   wire [47:0] mac_addr_arp2,               // Current MAC address
    input   wire [31:0] ip_addr_dos2,                // Current IP address
    input   wire [47:0] mac_addr_dos2,               // Current MAC address
    input   wire [15:0] port_dos2,                   // Current port access
    input   wire [31:0] ip_addr_port2,                // Current IP address
    input   wire [47:0] mac_addr_port2,               // Current MAC address
    input   wire [15:0] port_port2                    // Current port access
);
    reg [31:0] ip_addr1;
    reg [31:0] ip_addr2;
    reg [47:0] mac_addr1;
    reg [47:0] mac_addr2;
    reg [15:0] port1; 
    reg [15:0] port2; 
    always@(posedge clk or negedge n_rst)
        begin
            if(!n_rst)
                begin
                    data_out<=128'b0;
                    ip_addr1 <= 32'b0;
                    ip_addr2 <= 32'b0;
                    mac_addr1 <= 48'b0;
                    mac_addr2 <= 48'b0;
                    port1 <=  16'b0;
                    port2 <=  16'b0;                    
                end
            else
                begin
                    ip_addr1 <= ip_addr_arp1 | ip_addr_dos1 | ip_addr_port1;
                    ip_addr2 <= ip_addr_arp2 | ip_addr_dos2 | ip_addr_port2;
                    mac_addr1 <= mac_addr_arp1 | mac_addr_dos1 | mac_addr_port1;
                    mac_addr2 <= mac_addr_arp2 | mac_addr_dos2 | mac_addr_port2;
                    port1 <= port_dos1 | port_port1;
                    port2 <=  port_dos2 | port_port2;

                    if (close_connection_phy1_to_phy2)
                        begin
                            data_out <= {16'b0,8'b1,5'b0,ddos_threat_phy1,arp_spoofing_threat_phy1,port_scanning_threat_phy1,port1,mac_addr1,ip_addr1};        
                        end
                    else if (close_connection_phy2_to_phy1)
                        begin
                            data_out <= {16'b0,8'b10,5'b0,ddos_threat_phy2,arp_spoofing_threat_phy2,port_scanning_threat_phy2,port2,mac_addr2,ip_addr2};
                        end
                    else
                        begin
                            data_out <= 128'b0;        
                        end
                end
        end
endmodule