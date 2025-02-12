#include <error.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdbool.h>
#include <ncurses.h>
#include <curses.h>
#include <time.h>
#include <pthread.h>

#define BRIDGE 0xC0000000
#define ADDRESS_SPAN 0x40

#define HPS_RESET_ADDRESS 0x00
#define THREAT_DETECTION_ADDRESS 0x10
#define AUTHENTICATION_ADDRESS 0x20

#define IP_ADDRESS_OFFSET 0
#define MAC_ADDRESS_OFFSET 4
#define PORT_OFFSET 10
#define THREAT_OFFSET 12
#define PHY_OFFSET 13

static pthread_t fpga_thread;
static bool thread_running = false;
static pthread_mutex_t file_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t auth_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t auth_cond = PTHREAD_COND_INITIALIZER;
bool authentication_done = false;

pthread_mutex_t auth_process_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t auth_process_cond = PTHREAD_COND_INITIALIZER;
bool authentication_processing = false;

pthread_mutex_t file_creation_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t file_creation_cond = PTHREAD_COND_INITIALIZER;
bool file_created = false;

typedef struct 
{
  bool system_Reset;
} hps_bridge_input;

// // Helper function to check if memory is zeroed
// bool is_memory_zero(uint8_t *mem, size_t size)
// {
//     for (size_t i = 0; i < size; i++) {
//         if (mem[i] != 0) {
//             return false;
//         }
//     }
//     return true;
// }

void* hps_fpga_comm(void* arg)
{
    hps_bridge_input* input = (hps_bridge_input*)arg;
    FILE *file_ptr;
    int fd = 0;
    uint8_t* bridge_map = NULL;

    // Open file in append mode
    file_ptr = fopen("output.txt", "a");
    if (file_ptr == NULL) 
    {
        perror("Error opening file!");
        pthread_exit((void*)-1);
    }

    pthread_mutex_lock(&file_creation_mutex);
    file_created = true;               // Set flag
    pthread_cond_signal(&file_creation_cond);   // Signal main thread
    pthread_mutex_unlock(&file_creation_mutex);

    fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("Couldn't open /dev/mem\n");
        fclose(file_ptr);
        pthread_exit((void *)-2);
    }

    bridge_map = (uint8_t*)mmap(NULL, ADDRESS_SPAN, PROT_READ | PROT_WRITE, MAP_SHARED, fd, BRIDGE);
    if (bridge_map == MAP_FAILED) {
        perror("Couldn't map bridge.");
        close(fd);
        fclose(file_ptr);
        pthread_exit((void*)-3);
    }
    uint8_t* prev_threat_map = NULL;
    uint8_t* hps_reset_map = bridge_map + HPS_RESET_ADDRESS;
    uint8_t* threat_map = bridge_map + THREAT_DETECTION_ADDRESS;
    uint8_t* authentication_map = bridge_map + AUTHENTICATION_ADDRESS;
    int wrote_to_file = 0;
    int error = 0;

    uint32_t ip_address, prev_ip_address;
    uint8_t *mac_address;
    uint16_t port;
    uint8_t threat;
    uint8_t phy_number;
    bool system_Reset;

    while(thread_running)
    {
        system_Reset = input->system_Reset
        ip_address = *((uint32_t *)(threat_map + IP_ADDRESS_OFFSET));
        if(ip_address!=prev_ip_address)
        {
            // Extract fields from memory
            *mac_address = (uint8_t *)(threat_map + MAC_ADDRESS_OFFSET);
            port = *((uint16_t *)(threat_map + PORT_OFFSET));
            threat = *((uint8_t *)(threat_map + THREAT_OFFSET));
            phy_number = *((uint8_t *)(threat_map + PHY_OFFSET));
            prev_ip_address = ip_address;
            
            // Convert IP address to string
            char ip_str[16]; // Max length for IPv4 dotted-decimal + null terminator
            pthread_mutex_lock(&file_mutex); // Lock file access
            snprintf(ip_str, sizeof(ip_str), "%u.%u.%u.%u",
                    (ip_address >> 24) & 0xFF,
                    (ip_address >> 16) & 0xFF,
                    (ip_address >> 8) & 0xFF,
                    ip_address & 0xFF);

            // Convert MAC address to string
            char mac_str[18]; // Max length for MAC (XX:XX:XX:XX:XX:XX) + null terminator
            snprintf(mac_str, sizeof(mac_str), "%02X:%02X:%02X:%02X:%02X:%02X",
                    mac_address[0], mac_address[1], mac_address[2],
                    mac_address[3], mac_address[4], mac_address[5]);

            // Write data to the file
            fprintf(file_ptr, "IP Address: %s\n", ip_str);
            fprintf(file_ptr, "MAC Address: %s\n", mac_str);
            fprintf(file_ptr, "Port Number: %u\n", port);
            fprintf(file_ptr, "PHY Number: %u\n", phy_number);
            
            fprintf(file_ptr, "Threats Detected:\n");
            if (threat & (1 << 0)) fprintf(file_ptr, "  - Port Scanning\n");
            if (threat & (1 << 1)) fprintf(file_ptr, "  - ARP Spoofing\n");
            if (threat & (1 << 2)) fprintf(file_ptr, "  - DoS Attack\n");
            if (threat & (1 << 3)) fprintf(file_ptr, "  - DDoS Attack\n");
            if (threat == 0) fprintf(file_ptr, "  - None\n");
            
            time_t clk = time(NULL);
            fprintf(file_ptr,"This was detected at:  %s", ctime(&clk));
            fflush(file_ptr);
            pthread_mutex_unlock(&file_mutex); // Unlock file access
            
        }

        if(system_Reset)
        {
            uint8_t authentication = *((uint8_t *)(authentication_map));
            time_t endwait = time(NULL) + 2;
            while (time(NULL) < endwait)
            {
                if (authentication)
                {
                    uint8_t hps_reset = input->system_Reset;
                    *((uint8_t *)hps_reset_map) = hps_reset;

                    pthread_mutex_lock(&auth_process_mutex);
                    authentication_processing = false; // Update the flag
                    pthread_cond_signal(&auth_process_cond);
                    pthread_mutex_unlock(&auth_process_mutex);

                    sleep(1);
                    time_t clk = time(NULL);
                    pthread_mutex_lock(&file_mutex); // Lock file access
                    fprintf(file_ptr,"system restarted at:  %s", ctime(&clk));
                    pthread_mutex_unlock(&file_mutex); // Unlock file access

                    *((uint8_t *)hps_reset_map) = !hps_reset;
                    input->system_Reset = false;
                    pthread_mutex_lock(&auth_mutex);
                    authentication_done = true; // Update the flag
                    pthread_cond_signal(&auth_cond); // Signal the main thread
                    pthread_mutex_unlock(&auth_mutex);

                    break;
                }
            }
            pthread_mutex_lock(&auth_mutex);
            if (!authentication_done)
            {
                pthread_mutex_lock(&auth_process_mutex);
                authentication_processing = false; // Update the flag
                pthread_cond_signal(&auth_process_cond);
                pthread_mutex_unlock(&auth_process_mutex);
                pthread_mutex_lock(&file_mutex); // Lock file access
                fprintf(file_ptr,"Authentication failed\n");
                fflush(file_ptr);
                authentication_done = true; // Update the flag
                pthread_cond_signal(&auth_cond); // Signal the main thread
                pthread_mutex_unlock(&file_mutex); // Unlock file access
            }
            pthread_mutex_unlock(&auth_mutex);
            input->system_Reset = false;
        }

        sleep(100);
    }

    fclose(file_ptr);
    error = munmap(bridge_map, ADDRESS_SPAN);
    if (error < 0) 
    {
        perror("Couldn't unmap bridge.");
        close(fd);
        pthread_exit((void*)-4);
    }

    close(fd);
    pthread_exit(NULL);
}

// Start the thread
void start_fpga_thread(hps_bridge_input* input) 
{
    thread_running = true;
    if (pthread_create(&fpga_thread, NULL, hps_fpga_comm, input) != 0) {
        perror("Failed to start FPGA thread");
        exit(EXIT_FAILURE);
    }
}

// Stop the thread
void stop_fpga_thread() 
{
    thread_running = false;
    pthread_join(fpga_thread, NULL);
}
