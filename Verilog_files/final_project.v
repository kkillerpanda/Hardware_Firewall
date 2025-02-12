
module HADES (
    //hps
    output   [14: 0]    HPS_DDR3_ADDR,
    output   [ 2: 0]    HPS_DDR3_BA,
    output              HPS_DDR3_CAS_N,
    output              HPS_DDR3_CK_N,
    output              HPS_DDR3_CK_P,
    output              HPS_DDR3_CKE,
    output              HPS_DDR3_CS_N,
    output   [ 3: 0]    HPS_DDR3_DM,
    inout    [31: 0]    HPS_DDR3_DQ,
    inout    [ 3: 0]    HPS_DDR3_DQS_N,
    inout    [ 3: 0]    HPS_DDR3_DQS_P,
    output              HPS_DDR3_ODT,
    output              HPS_DDR3_RAS_N,
    output              HPS_DDR3_RESET_N,
    input               HPS_DDR3_RZQ,
    output              HPS_DDR3_WE_N,

    input wire        clk,                  // 50 MHz clock
    input wire        rst_n,                // Active-low reset signal
    
    
    // PHY 1 RMII interface
    output wire 	  rst_n_outside_phy1,
    output wire       clk_out_phy1,
    input wire [1:0]  phy1_rxd,             // Received data from PHY 1 (2 bits)
    input wire        phy1_crs_dv,          // Carrier sense / data valid from PHY 1
	input wire        phy1_sigdet,			// Signal detect connection from PHY 1
    output wire [1:0] phy1_txd,             // Transmit data to PHY 1 (2 bits)
    output wire       phy1_tx_en,           // Transmit enable for PHY 1

    // PHY 2 RMII interface
    output wire 	  rst_n_outside_phy2,
    output wire       clk_out_phy2,
    input wire [1:0]  phy2_rxd,             // Received data from PHY 2 (2 bits)
    input wire        phy2_crs_dv,          // Carrier sense / data valid from PHY 2
	input wire	      phy2_sigdet,			 // Signal detect connection from PHY 1
    output wire [1:0] phy2_txd,             // Transmit data to PHY 2 (2 bits)
    output wire       phy2_tx_en,            // Transmit enable for PHY 2

    // RFID interface pins
    output wire IRQ_IN,
    input wire miso,
    output wire mosi,
    output wire sck,
    output wire cs



);
    wire    hps_restart;
    wire    system_rst_n;
    wire    data_capture1;
    wire    data_capture2;
    assign  system_rst_n = rst_n | hps_restart;
    assign  clk_out_phy1 = clk;
    assign  clk_out_phy2 = clk;
    assign  rst_n_outside_phy1 = rst_n | hps_restart; 
    assign  rst_n_outside_phy2 = rst_n | hps_restart;
    wire [7:0]   authentication_export;
    wire [127:0] threat_data_export;  // threat_data.export into the hps outputs to the ram 
    wire [7:0]   hps_reset_export;   //   hps_reset.export from hps gets the reset signal from the hps
    
    hps_restart_writer system_restart
    (
        .clk(clk),         // Clock signal
        .reset_n(rst_n),     // Active-low reset signal from HPS
        .hps_reset_export(hps_reset_export),
        .hps_restart(hps_restart)   // Reset signal to the top-level entity
    );
    hades u0
    (       
                .clk_clk(clk),                              //         clk.clk
                .hps_reset_export(hps_reset_export),        //   hps_reset.export
                .memory_mem_a(HPS_DDR3_ADDR),               //        memory.mem_a
                .memory_mem_ba(HPS_DDR3_BA),                 //        .mem_ba
                .memory_mem_ck(HPS_DDR3_CK_P),               //        .mem_ck
                .memory_mem_ck_n(HPS_DDR3_CK_N),             //        .mem_ck_n
                .memory_mem_cke(HPS_DDR3_CKE),               //        .mem_cke
                .memory_mem_cs_n(HPS_DDR3_CS_N),             //        .mem_cs_n
                .memory_mem_ras_n(HPS_DDR3_RAS_N),           //        .mem_ras_n
                .memory_mem_cas_n(HPS_DDR3_CAS_N),           //        .mem_cas_n
                .memory_mem_we_n(HPS_DDR3_WE_N),             //        .mem_we_n
                .memory_mem_reset_n(HPS_DDR3_RESET_N),       //        .mem_reset_n
                .memory_mem_dq(HPS_DDR3_DQ),                 //        .mem_dq
                .memory_mem_dqs(HPS_DDR3_DQS_P),             //        .mem_dqs
                .memory_mem_dqs_n(HPS_DDR3_DQS_N),           //        .mem_dqs_n
                .memory_mem_odt(HPS_DDR3_ODT),               //        .mem_odt
                .memory_mem_dm(HPS_DDR3_DM),                 //        .mem_dm
                .memory_oct_rzqin(HPS_DDR3_RZQ),             //        .oct_rzqin
                .reset_reset_n(rst_n),                      //       reset.reset_n
                .threat_data_export(threat_data_export),     // threat_data.export
                .authentication_export(authentication_export)
           );
     // Threat detection signals
    wire arp_spoofing_threat_phy1;
    wire port_scanning_threat_phy1;
    wire ddos_threat_phy1;

    wire arp_spoofing_threat_phy2;
    wire port_scanning_threat_phy2;
    wire ddos_threat_phy2;
    // Signals for packet transfer
    wire [1:0] processed_phy1_to_phy2;     // Processed data from PHY 1 to PHY 2
    wire [1:0] processed_phy2_to_phy1;     // Processed data from PHY 2 to PHY 1

     // Combine threat detection signals for PHY 2 to PHY 1,
    wire close_connection_phy2_to_phy1;
    assign close_connection_phy2_to_phy1 = arp_spoofing_threat_phy2 | port_scanning_threat_phy2 | ddos_threat_phy2;

    // Output to PHY 1 based on threat detection 
    assign phy1_txd = close_connection_phy2_to_phy1 ? 2'b00 : processed_phy2_to_phy1;

	assign rst_n_outside=rst_n;
    // Instantiate RMII processor for PHY 1
    rmii_processor rmii_proc_phy1 (
        .clk(clk),
        .rst_n(system_rst_n),
        .rxd(phy1_rxd),
        .crs_dv(phy1_crs_dv),
		.sigdet(phy1_sigdet),
        .txd(processed_phy1_to_phy2),      // Send to inspection modules
        .tx_en(phy1_tx_en),
        .close_connection(close_connection_phy2_to_phy1),
        .data_capture(data_capture1)
    );
        // Combine threat detection signals for PHY 1 to PHY 2
    wire close_connection_phy1_to_phy2;
    assign close_connection_phy1_to_phy2 = arp_spoofing_threat_phy1 | port_scanning_threat_phy1 | ddos_threat_phy1;
    
    // Output to PHY 2 based on threat detection 
    assign phy2_txd = close_connection_phy1_to_phy2 ? 2'b00 : processed_phy1_to_phy2;
    
    // Instantiate RMII processor for PHY 2
    rmii_processor rmii_proc_phy2 (
        .clk(clk),
        .rst_n(system_rst_n),
        .rxd(phy2_rxd),
        .crs_dv(phy2_crs_dv),
		.sigdet(phy2_sigdet),
        .txd(processed_phy2_to_phy1),      // Send to inspection modules
        .tx_en(phy2_tx_en),
        .close_connection(close_connection_phy1_to_phy2),
        .data_capture(data_capture2)
    );



    wire [31:0] ip_addr_arp1;                 // Current IP address
    wire [47:0] mac_addr_arp1;                // Current MAC address
    wire [31:0] ip_addr_dos1;                 // Current IP address
    wire [47:0] mac_addr_dos1;                // Current MAC address
    wire [15:0] port_dos1;                    // Current port access
    wire [31:0] ip_addr_port1;                 // Current IP address
    wire [47:0] mac_addr_port1;                // Current MAC address
    wire [15:0] port_port1;                    // Current port access
    // Instantiate Threat Inspection Modules for PHY 1 to PHY 2
    arp_spoofing_detector arp_check_phy1 (
        .clk(clk),
        .rst_n(system_rst_n),
		.rxd(phy1_rxd),
        .alert(arp_spoofing_threat_phy1),
        .ip_addr_export(ip_addr_arp1),           // Current IP address to export
        .mac_addr_export(mac_addr_arp1),          // Current MAC address to export
        .data_capture(data_capture1) 
    );

    port_scanning_check port_scan_check_phy1 (
        .clk(clk),
        .rst_n(system_rst_n),
		.rxd(phy1_rxd),
        .alert(port_scanning_threat_phy1),
        .ip_addr_export(ip_addr_dos1),           // Current IP address to export
        .mac_addr_export(mac_addr_dos1),          // Current MAC address to export 
        .port_export(port_dos1),               // Current port access to export
        .data_capture(data_capture1) 

    );

    ddos_check ddos_check_phy1 (
        .clk(clk),
        .rst_n(system_rst_n),
        .rxd(phy1_rxd),
        .alert(ddos_threat_phy1),
        .ip_addr_export(ip_addr_port1),           // Current IP address to export
        .mac_addr_export(mac_addr_port1),          // Current MAC address to export 
        .port_export(port_port1),               // Current port access to export
        .data_capture(data_capture1)
    );



    
    
    wire [31:0] ip_addr_arp2;                 // Current IP address
    wire [47:0] mac_addr_arp2;                // Current MAC address
    wire [31:0] ip_addr_dos2;                 // Current IP address
    wire [47:0] mac_addr_dos2;                // Current MAC address
    wire [15:0] port_dos2;                    // Current port access
    wire [31:0] ip_addr_port2;                 // Current IP address
    wire [47:0] mac_addr_port2;                // Current MAC address
    wire [15:0] port_port2;                    // Current port access
    // Similar threat inspection for PHY 2 to PHY 1
    arp_spoofing_detector arp_check_phy2 (
        .clk(clk),
        .rst_n(system_rst_n),
        .rxd(phy2_rxd),
        .alert(arp_spoofing_threat_phy2),
        .ip_addr_export(ip_addr_arp2),           // Current IP address to export
        .mac_addr_export(mac_addr_arp2),          // Current MAC address to export 
        .data_capture(data_capture2)
    );

    port_scanning_check port_scan_check_phy2 (
        .clk(clk),
        .rst_n(system_rst_n),
        .rxd(phy2_rxd),
        .alert(port_scanning_threat_phy2),
        .ip_addr_export(ip_addr_dos2),           // Current IP address to export
        .mac_addr_export(mac_addr_dos2),          // Current MAC address to export 
        .port_export(port_dos2),               // Current port access to export
        .data_capture(data_capture2) 
    );

    ddos_check ddos_check_phy2 (
        .clk(clk),
        .rst_n(system_rst_n),
        .rxd(phy2_rxd),
        .alert(ddos_threat_phy2),
        .ip_addr_export(ip_addr_port2),           // Current IP address to export
        .mac_addr_export(mac_addr_port2),          // Current MAC address to export 
        .port_export(port_port2),               // Current port access to export
        .data_capture(data_capture2)
    );



    DataCombiner ExportDataCombiner(
        .data_out(threat_data_export),
        .clk(clk),
        .n_rst(n_rst),
        .arp_spoofing_threat_phy1(arp_spoofing_threat_phy1),
        .port_scanning_threat_phy1(port_scanning_threat_phy1),
        .ddos_threat_phy1(ddos_threat_phy1),
        .arp_spoofing_threat_phy2(arp_spoofing_threat_phy2),
        .port_scanning_threat_phy2(port_scanning_threat_phy2),
        .ddos_threat_phy2(ddos_threat_phy2),
        .close_connection_phy2_to_phy1(close_connection_phy2_to_phy1),
        .close_connection_phy1_to_phy2(close_connection_phy1_to_phy2),
        .ip_addr_arp1(ip_addr_arp1),
        .mac_addr_arp1(mac_addr_arp1),
        .ip_addr_dos1(ip_addr_dos1),
        .mac_addr_dos1(mac_addr_dos1),
        .port_dos1(port_dos1),
        .ip_addr_port1(ip_addr_port1),
        .mac_addr_port1(mac_addr_port1),
        .port_port1(port_port1),
        .ip_addr_arp2(ip_addr_arp2),
        .mac_addr_arp2(mac_addr_arp2),
        .ip_addr_dos2(ip_addr_dos2),
        .mac_addr_dos2(mac_addr_dos2),
        .port_dos2(port_dos2),
        .ip_addr_port2(ip_addr_port2),
        .mac_addr_port2(mac_addr_port2),
        .port_port2(port_port2)
    );


    RFID_INTERFACE RFID_click(
    .IRQ_IN(IRQ_IN),              // Interrupt from CR95HF
    .IRQ_OUT(),                  // Interrupt output for external use
    .clk(clk),                      // System clock
    .rst_n(system_rst_n),                    // Active low reset 
    .miso(miso),                     // SPI MISO from CR95HF
    .mosi(mosi),                    // SPI MOSI to CR95HF
    .sck(sck),                     // SPI clock
    .cs(cs),                      // SPI chip select (active low)
    .valid_card(authentication_export),          // Output signal for valid card detection
    .card_uid()      // Captured card UID (validation on the gui: later stage)
    );

   
endmodule

// module final_project
// (
// 	input adminpermission,
// 	input wire [15:0] p_type_in,
// 	input rst, 
// 	output reg ARP_detect,
// 	output reg IPv4_detect,
// 	output reg IPV6_detect,
// 	output n_rst_in,
// 	output n_rst_out,
// 	input refCLK,
// 	output CLK_OUTSIDE,
// 	output CLK_INSIDE,
// 	input [1:0] RXD_out,
// 	output [1:0] TXD_out,
// 	output TX_EN_out,
// 	input [1:0] RXD_INSIDE,
// 	output [1:0] TXD_INSIDE,
// 	output TX_EN_INSIDE,
// 	output wire start_out, 
// 	output wire [15:0] size_out,
// 	output wire start_in,
// 	output wire [15:0] size_in,
// 	input sigdet_in,
// 	input sigdet_out,
// 	input [15:0] packet_size_in,
// 	input [15:0] packet_size_out
// );
// parameter IPv4=16'h0800,IPv6=16'h86DD, ARP=16'h0806; 
// reg [15:0] p_type;
// reg [1000:0] packet_out, packet_in;
// assign CLK_OUTSIDE = refCLK;
// assign CLK_INSIDE = refCLK;

// PHY_COMPONENT PHY_OUTSIDE
// (
// 	.refCLK(refCLK),
// 	.RXD(RXD_out),
// 	.TXD(TXD_out),
// 	.TX_EN(TX_EN_out),
// 	.start(start_out),
// 	.size(size_out),
// 	.packet_size(packet_size_out),
// 	.sigdet(sigdet_out),
// 	.rst(rst),
// 	.n_rst(n_rst_out),
// 	.RXD_OUTBOUND()
// );

// PHY_COMPONENT PHY_INSIDE
// (
// 	.refCLK(refCLK),
// 	.RXD(RXD_INSIDE), 
// 	.TXD(TXD_INSIDE),
// 	.TX_EN(TX_EN_INSIDE),
// 	.start(start_in),
// 	.size(size_in),
// 	.packet_size(packet_size_in),
// 	.sigdet(sigdet_in),
// 	.rst(rst),
// 	.n_rst(n_rst_in),
// 	.RXD_OUTBOUND()	
// );

// ARP_SPOOFER_DETECTION ARP_detector
// (
// 	.refCLK(refCLK),
// 	.Incoming_packet_buffer(packet_outside),
// 	.p_type(p_type)
// );

// always@(posedge refCLK or negedge rst)
// begin
// 	if(!rst)
// 	begin
// 		p_type<=0;
// 		packet_out<=0;
// 		packet_in<=0;
// 	end
// 	else
// 	begin

// 		packet_out<={packet_out[1000-2:0],TXD_out};
// 		packet_in<={packet_in[1000-2:0],TXD_INSIDE};
// 		case (p_type)
// 			IPv4:
// 				begin
// 					IPv4_detect<=1;
// 				end
// 			IPv6:
// 				begin
// 					IPV6_detect<=1;
// 				end 
// 			ARP:
// 				begin
// 					ARP_detect<=1;
// 				end
// 			default:
// 				begin
// 				end	
// 		endcase
// 	end

// end
	
// endmodule

// module top_level_security (
//     input wire clk,              // 50 MHz clock
//     input wire rst,              // Reset signal

//     // RMII PHY Interface
//     input wire [31:0] rx_ip_addr,   // Received IP address from packet (simplified)
//     input wire [47:0] rx_mac_addr,  // Received MAC address from packet
//     input wire [15:0] rx_dest_port, // Received destination port from packet

//     // Threat Detection Alerts
//     output wire arp_spoofing_alert,  // ARP spoofing detected
//     output wire port_scan_alert,     // Port scanning detected
//     output wire dos_attack_alert     // DoS attack detected
// );

//     // ARP Spoofing Detection
//     arp_spoofing_detector arp_detector (
//         .clk(clk),
//         .rst(rst),
//         .ip_addr(rx_ip_addr),
//         .mac_addr(rx_mac_addr),
//         .alert(arp_spoofing_alert)
//     );

//     // Port Scanning Detection
//     port_scanning_detector port_scanner (
//         .clk(clk),
//         .rst(rst),
//         .dest_port(rx_dest_port),
//         .alert(port_scan_alert)
//     );

//     // DoS Attack Detection
//     dos_attack_detector dos_detector (
//         .clk(clk),
//         .rst(rst),
//         .alert(dos_attack_alert)
//     );

// endmodule

// module final_project (
//     input clk,                            // 50 MHz clock
//     input rst,                            // Reset signal

//     // RMII PHY Interface 1
//     input wire [1:0] phy1_rxd,                // Receive data from PHY 1
//     input wire phy1_crs_dv,                   // Carrier sense / data valid for PHY 1
//     output wire [1:0] phy1_txd,               // Transmit data to PHY 1
//     output wire phy1_tx_en,                   // Transmit enable signal to PHY 1
//     input wire [31:0] phy1_rx_ip_addr,        // Received IP address from PHY 1
//     input wire [47:0] phy1_rx_mac_addr,       // Received MAC address from PHY 1
//     input wire [15:0] phy1_rx_dest_port,      // Received destination port from PHY 1

//     // RMII PHY Interface 2
//     input wire [1:0] phy2_rxd,                // Receive data from PHY 2
//     input wire phy2_crs_dv,                   // Carrier sense / data valid for PHY 2
//     output wire [1:0] phy2_txd,               // Transmit data to PHY 2
//     output wire phy2_tx_en,                   // Transmit enable signal to PHY 2
//     input wire [31:0] phy2_rx_ip_addr,        // Received IP address from PHY 2
//     input wire [47:0] phy2_rx_mac_addr,       // Received MAC address from PHY 2
//     input wire [15:0] phy2_rx_dest_port,      // Received destination port from PHY 2

//     // Threat Detection Alerts
//     output wire arp_spoofing_alert_phy1,     // ARP spoofing detected from PHY 1
//     output wire port_scan_alert_phy1,         // Port scanning detected from PHY 1
//     output wire dos_attack_alert_phy1,        // DoS attack detected from PHY 1

//     output wire arp_spoofing_alert_phy2,     // ARP spoofing detected from PHY 2
//     output wire port_scan_alert_phy2,         // Port scanning detected from PHY 2
//     output wire dos_attack_alert_phy2         // DoS attack detected from PHY 2
// );

//     // ARP Spoofing Detection for PHY 1
//     arp_spoofing_detector arp_detector_phy1 (
//         .clk(clk),
//         .rst(rst),
//         .ip_addr(phy1_rx_ip_addr),
//         .mac_addr(phy1_rx_mac_addr),
//         .alert(arp_spoofing_alert_phy1)
//     );

//     // Port Scanning Detection for PHY 1
//     port_scanning_detector port_scanner_phy1 (
//         .clk(clk),
//         .rst(rst),
//         .dest_port(phy1_rx_dest_port),
//         .alert(port_scan_alert_phy1)
//     );

//     // DoS Attack Detection for PHY 1
//     dos_attack_detector dos_detector_phy1 (
//         .clk(clk),
//         .rst(rst),
//         .alert(dos_attack_alert_phy1)
//     );

//     // ARP Spoofing Detection for PHY 2
//     arp_spoofing_detector arp_detector_phy2 (
//         .clk(clk),
//         .rst(rst),
//         .ip_addr(phy2_rx_ip_addr),
//         .mac_addr(phy2_rx_mac_addr),
//         .alert(arp_spoofing_alert_phy2)
//     );

//     // Port Scanning Detection for PHY 2
//     port_scanning_detector port_scanner_phy2 (
//         .clk(clk),
//         .rst(rst),
//         .dest_port(phy2_rx_dest_port),
//         .alert(port_scan_alert_phy2)
//     );

//     // DoS Attack Detection for PHY 2
//     dos_attack_detector dos_detector_phy2 (
//         .clk(clk),
//         .rst(rst),
//         .alert(dos_attack_alert_phy2)
//     );

// endmodule


// module final_project
// (
//     input wire clk,                            // 50 MHz clock
//     input wire rst,                            // Reset signal

//     // RMII PHY Interface 1
//     input wire [1:0] phy1_rxd,                // Receive data from PHY 1
//     input wire phy1_crs_dv,                   // Carrier sense / data valid for PHY 1
//     output wire [1:0] phy1_txd,               // Transmit data to PHY 1
//     output wire phy1_tx_en,                   // Transmit enable signal to PHY 1

//     // RMII PHY Interface 2
//     input wire [1:0] phy2_rxd,                // Receive data from PHY 2
//     input wire phy2_crs_dv,                   // Carrier sense / data valid for PHY 2
//     output wire [1:0] phy2_txd,               // Transmit data to PHY 2
//     output wire phy2_tx_en,                   // Transmit enable signal to PHY 2

//     // Threat Detection Alerts
//     output wire arp_spoofing_alert_phy1,     // ARP spoofing detected from PHY 1
//     output wire port_scan_alert_phy1,         // Port scanning detected from PHY 1
//     output wire dos_attack_alert_phy1,        // DoS attack detected from PHY 1

//     output wire arp_spoofing_alert_phy2,     // ARP spoofing detected from PHY 2
//     output wire port_scan_alert_phy2,         // Port scanning detected from PHY 2
//     output wire dos_attack_alert_phy2          // DoS attack detected from PHY 2
// );

//     // Intermediate signals for extracted data
//     wire [31:0] rx_ip_addr_phy1;        // Extracted IP address from PHY 1
//     wire [47:0] rx_mac_addr_phy1;       // Extracted MAC address from PHY 1
//     wire [15:0] rx_dest_port_phy1;      // Extracted destination port from PHY 1

//     wire [31:0] rx_ip_addr_phy2;        // Extracted IP address from PHY 2
//     wire [47:0] rx_mac_addr_phy2;       // Extracted MAC address from PHY 2
//     wire [15:0] rx_dest_port_phy2;      // Extracted destination port from PHY 2

//     // Logic to process RMII data from PHY 1
//     rmii_processor rmii_proc_phy1 (
//         .clk(clk),
//         .rst(rst),
//         .rxd(phy1_rxd),
//         .crs_dv(phy1_crs_dv),
//         .rx_ip_addr(rx_ip_addr_phy1),
//         .rx_mac_addr(rx_mac_addr_phy1),
//         .rx_dest_port(rx_dest_port_phy1)
//     );

//     // Logic to process RMII data from PHY 2
//     rmii_processor rmii_proc_phy2 (
//         .clk(clk),
//         .rst(rst),
//         .rxd(phy2_rxd),
//         .crs_dv(phy2_crs_dv),
//         .rx_ip_addr(rx_ip_addr_phy2),
//         .rx_mac_addr(rx_mac_addr_phy2),
//         .rx_dest_port(rx_dest_port_phy2)
//     );

//     // ARP Spoofing Detection for PHY 1
//     arp_spoofing_detector arp_detector_phy1 (
//         .clk(clk),
//         .rst(rst),
//         .ip_addr(rx_ip_addr_phy1),
//         .mac_addr(rx_mac_addr_phy1),
//         .alert(arp_spoofing_alert_phy1)
//     );

//     // Port Scanning Detection for PHY 1
//     port_scanning_detector port_scanner_phy1 (
//         .clk(clk),
//         .rst(rst),
//         .dest_port(rx_dest_port_phy1),
//         .alert(port_scan_alert_phy1)
//     );

//     // DoS Attack Detection for PHY 1
//     dos_attack_detector dos_detector_phy1 (
//         .clk(clk),
//         .rst(rst),
//         .alert(dos_attack_alert_phy1)
//     );

//     // ARP Spoofing Detection for PHY 2
//     arp_spoofing_detector arp_detector_phy2 (
//         .clk(clk),
//         .rst(rst),
//         .ip_addr(rx_ip_addr_phy2),
//         .mac_addr(rx_mac_addr_phy2),
//         .alert(arp_spoofing_alert_phy2)
//     );

//     // Port Scanning Detection for PHY 2
//     port_scanning_detector port_scanner_phy2 (
//         .clk(clk),
//         .rst(rst),
//         .dest_port(rx_dest_port_phy2),
//         .alert(port_scan_alert_phy2)
//     );

//     // DoS Attack Detection for PHY 2
//     dos_attack_detector dos_detector_phy2 (
//         .clk(clk),
//         .rst(rst),
//         .alert(dos_attack_alert_phy2)
//     );

// endmodule
