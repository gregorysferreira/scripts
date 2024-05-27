#!/usr/bin/python3
## Author: Gregory Ferreira
## Date: 2024-05-27 
## Version : 1.5
import sys
import time
import socket
import threading
from colorama import Fore, Style

BANNER_SCAN = f"""{Fore.BLUE}
 ____  _____ _   _     ____    _    _   _ _   _ _____ ____  
/ ___|| ____| | | |   | __ )  / \  | \ | | \ | | ____|  _ \ 
\___ \|  _| | | | |   |  _ \ / _ \ |  \| |  \| |  _| | |_) |
 ___) | |___| |_| |   | |_) / ___ \| |\  | |\  | |___|  _ < 
|____/|_____|\___/    |____/_/   \_\_| \_|_| \_|_____|_| \_\\
{Style.RESET_ALL}"""

def port(ip, porta, protocolo):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM if protocolo == "TCP" else socket.SOCK_DGRAM)
        sock.settimeout(1)
        resultado = sock.connect_ex((ip, porta))
        sock.close()
        return resultado == 0
    except Exception as e:
        print(f"{Fore.RED}Erro ao verificar porta {porta}: {e}{Style.RESET_ALL}")
        return False

def anim():
    while True:
        for char in '/-\|':
            sys.stdout.write('\r' + f'Escaneando... {char}')
            sys.stdout.flush()
            time.sleep(0.1)

def main():
    print(BANNER_SCAN)
    ip = input("Digite o endereço IP do alvo: ")

    animation_thread = threading.Thread(target=anim)
    animation_thread.daemon = True
    animation_thread.start()

    portas_tcp = {
        80: "HTTP (servidor web)",
        443: "HTTPS (servidor web seguro)",
        3000: "HTTP (chatnode)",
        5000: "HTTP (automação)",
        5432: "PostgreSQL (banco de dados)",
    }

    portas_udp = {
        53: "DNS (serviço de nomes de domínio)",
        123: "NTP (serviço de data/hora)",
        5432: "PostgreSQL (banco de dados)",
        5060: "SIP (protocolo de comunicação em tempo real)",
        7760: "Algum serviço específico (protocolo de comunicação em tempo real)",
        50001: "Algum serviço específico (vpn jump)",
    }

    print(f"\n{Fore.CYAN}Escaneando portas TCP...{Style.RESET_ALL}")
    for porta, servico in portas_tcp.items():
        if port(ip, porta, "TCP"):
            print(f"{Fore.GREEN}Porta {porta} aberta (TCP) - Serviço: {servico}{Style.RESET_ALL}")
        else:
            print(f"{Fore.RED}Porta {porta} fechada (TCP){Style.RESET_ALL}")

    print(f"\n{Fore.CYAN}Escaneando portas UDP...{Style.RESET_ALL}")
    for porta, servico in portas_udp.items():
        if port(ip, porta, "UDP"):
            print(f"{Fore.GREEN}Porta {porta} aberta (UDP) - Serviço: {servico}{Style.RESET_ALL}")
        else:
            print(f"{Fore.RED}Porta {porta} fechada (UDP){Style.RESET_ALL}")

if __name__ == "__main__":
    main()
