#!/usr/bin/python3
import scapy.all as scapy
import ipaddress
import time
import argparse
import sys
import time


def defend(interface, network, count, robustness):
    myMAC = scapy.get_if_hwaddr(interface)
    counter = 0

    def handle_packet(packet, ctx):
        if packet[scapy.ARP].op != 1: 
            return

        if ipaddress.ip_address(packet.pdst) not in ctx['net']:
            print("IGN: Ignore incoming arp request with pdst=" + packet.pdst)
            return

        if str(packet.src) in ctx['ignore_src']:
            print("IGN: Ignore incoming arp request by MAC with src=" + packet.src)
            return

        if str(packet.pdst) in ctx['ignore_dst_ip']:
            print("IGN: Ignore incoming arp request by pdst=" + packet.pdst)
            return

        print("RCV: " + packet.__repr__())
        reply = scapy.ARP(op=2,  hwsrc=myMAC, psrc=packet.pdst, hwdst=packet[scapy.ARP].hwsrc, pdst="0.0.0.0")
        reply = scapy.Ether(dst="ff:ff:ff:ff:ff:ff", src=myMAC) / reply

        robustness = ctx['robustness']
        while True:
            scapy.sendp(reply, iface=ctx['ifc'], verbose=False)
            print("SND: " + reply.__repr__())
            robustness -= 1
            if robustness > 0:
                time.sleep(0.2)
            else:
                break
        print("")


        ctx['pkt_count'] += 1
        if ctx['max_count'] > 0 and ctx['pkt_count'] >= ctx['max_count']:
                sys.exit(0)
        return

    my_macs=list(filter(lambda x: x != '00:00:00:00:00:00', [scapy.get_if_hwaddr(i) for i in scapy.get_if_list()]))
    ctx = dict( pkt_count = 0, max_count = count, net = network, ifc = interface, ignore_src = my_macs, ignore_dst_ip=[scapy.get_if_addr(interface)], robustness = robustness);
    # Sniff for ARP packets. Run handle_packet() on each one
    scapy.sniff(filter="arp",prn=lambda x: handle_packet(x,ctx), iface=interface)

def network(string):
    return ipaddress.ip_network(string)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='arp-tool', description='Test utility to for various ARP fake tasks')
    subparsers = parser.add_subparsers(dest='tool')

    defend_arg = subparsers.add_parser('defend', help='This tool can be used to send on each "HOW-HAS-IP" ARP-request a claim ARP-response. Used to fake address in use cases.')
    defend_arg.add_argument('interface', help="The network interface where we listen and send the ARP reply")
    defend_arg.add_argument('network', default="169.254.0.0/16", type=network, help="The network which we asume to claim for us")
    defend_arg.add_argument('--count', default=1, type=int, help="The number of ARP-requests we are going to answer")
    defend_arg.add_argument('--robustness', default=1, type=int, help="How often the arp-response will be send (default: 1)")

    kwargs = vars(parser.parse_args())
    tool = kwargs.pop('tool')
    if tool is None:
        print("ERROR missing tool parameter")
        parser.print_help()
        sys.exit(2)
    globals()[tool](**kwargs)

