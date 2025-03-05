from scapy.all import *

destination = "192.168.1.2"
#destination2="172.20.10.2"

while True:
    choice = input("Decide what you want to do:\n1: Send packet\n2: Change IP\n3: Exit\n")
    
    match choice:
        case "1":
            # Send a TCP packet to the destination IP
            send(IP(dst=destination) / UDP(sport=1234, dport=1234)) # type: ignore
            print(f"Packet sent to {destination}")
            
        case "2":
            # Change the destination IP
            new_ip = input(f"Enter new IP address (current: {destination}):\n0:Stop ")
            if new_ip:  # Check if the input is not empty
                if new_ip!="0":
                    destination = new_ip
                    print(f"Destination IP changed to {destination}")
                
        case "3":
            print("Exiting the program.")
            break
        
        case _:
            print("Invalid option. Please enter 1, 2, or 3.")