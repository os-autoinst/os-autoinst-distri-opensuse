# Get the original file from https://gitlab.suse.de/hana-perf/qa_test_hanaonkvm/-/blob/master/kvm_role.py
import os
import re
import sys
import ssl
import dbus
import psutil
import logging
import argparse
from glob import glob

formatter = "%(asctime)s [%(name)s][%(levelname)s] %(message)s"
logger = logging.getLogger('KVM_ROLE')
logger.setLevel(logging.DEBUG)
streamhandler = logging.StreamHandler(sys.stdout)
streamhandler.setLevel(logging.DEBUG)
streamhandler.setFormatter(logging.Formatter(formatter))
logger.addHandler(streamhandler)
# not verify certificate(suse ca) when handling url
ssl._create_default_https_context = ssl._create_unverified_context


class TimeoutError(Exception):
    pass

# wrapper script arguments parser
def init_argparser():
    parser = argparse.ArgumentParser(description='The Usage of create_host_bridge.py')
    parser.add_argument(
        'excluded_macs',
        help='Excluded NIC MAC list for bridge creation, for example "mac1,mac2"',
        metavar="excluded_macs",
        type=str
    )

    args = parser.parse_args()
    if not args.excluded_macs:
        excluded_macs = []
    else:
        excluded_macs = [
            mac.strip()
            for mac in args.excluded_macs.split(',')
            if mac.strip()
        ]

    return excluded_macs


class NetworkManagerClient:
    def __init__(self):
        self.bus = dbus.SystemBus()

        self.nm = self.bus.get_object(
            'org.freedesktop.NetworkManager',
            '/org/freedesktop/NetworkManager'
        )
        self.nm_iface = dbus.Interface(
            self.nm,
            'org.freedesktop.NetworkManager'
        )

        self.settings = self.bus.get_object(
            'org.freedesktop.NetworkManager',
            '/org/freedesktop/NetworkManager/Settings'
        )
        self.settings_iface = dbus.Interface(
            self.settings,
            'org.freedesktop.NetworkManager.Settings'
        )

    def get_connections(self):
        connections = []
        for path in self.settings_iface.ListConnections():
            conn_obj = self.bus.get_object(
                'org.freedesktop.NetworkManager',
                path
            )
            conn_iface = dbus.Interface(
                conn_obj,
                'org.freedesktop.NetworkManager.Settings.Connection'
            )
            config = conn_iface.GetSettings()
            connections.append(json.dumps(config))

        return connections

    def add_connection(self, config):
        try:
            dbus_config = dbus.Dictionary(config)
            new_conn_path = self.settings_iface.AddConnection(dbus_config)
            return str(new_conn_path)
        except dbus.exceptions.DBusException as e:
            raise RuntimeError(f"Failed to activate connection: {e}")

    def activate_connection(self, connection_path, device_path="/"):
        try:
            active_path = self.nm_iface.ActivateConnection(
                connection_path,
                device_path,
                "/"
            )
            return str(active_path)
        except dbus.exceptions.DBusException as e:
            raise RuntimeError(f"Failed to activate connection: {e}")

    def deactivate_connection(self, active_path):
        try:
            self.nm_iface.DeactivateConnection(active_path)
            return True
        except dbus.exceptions.DBusException as e:
            raise RuntimeError(f"Failed to deactivate connection: {e}")

    def delete_connection(self, connection_path):
        try:
            conn_obj = self.bus.get_object(
                'org.freedesktop.NetworkManager',
                connection_path
            )
            conn_iface = dbus.Interface(
                conn_obj,
                'org.freedesktop.NetworkManager.Settings.Connection'
            )
            conn_iface.Delete()
            return True
        except dbus.exceptions.DBusException as e:
            raise RuntimeError(f"Failed to delete connection: {e}")

    def create_bridge_config(self,
        connection_id,
        bridge_name,
        stp=False,
        mac_address=None
    ):
        config = {
            'connection': {
                'id': connection_id,
                'type': 'bridge',
                'interface-name': bridge_name,
            },
            'bridge': {
                'stp': stp,
            },
            'ipv4': {
                'method': 'auto',
            },
            'ipv6': {
                'method': 'auto',
            }
        }

        if mac_address:
            config['bridge']['mac-address'] = dbus.ByteArray(
                bytes.fromhex(mac_address.replace(':', ''))
            )

        return config

    def create_bridge_slave_config(self,
        physical_iface,
        bridge_conn_id,
        mac_address=None
    ):
        config = {
            'connection': {
                'id': f'{physical_iface}-slave',
                'type': '802-3-ethernet',
                'interface-name': physical_iface,
                'master': bridge_conn_id,
                'slave-type': 'bridge'
            },
            '802-3-ethernet': {
            }
        }

        if mac_address:
            config['802-3-ethernet']['cloned-mac-address'] = dbus.ByteArray(
                bytes.fromhex(mac_address.replace(':', ''))
            )

        return config

    def find_settings_path_by_interface(self, interface_name):
        for conn_path in self.settings_iface.ListConnections():
            conn_obj = self.bus.get_object(
                'org.freedesktop.NetworkManager',
                conn_path
            )
            conn_iface = dbus.Interface(
                conn_obj,
                'org.freedesktop.NetworkManager.Settings.Connection'
            )
            settings = conn_iface.GetSettings()
            if settings['connection'].get('interface-name', '') == interface_name:
                return str(conn_path)

        return None

    def find_device_path_by_interface(self, interface_name):
        devices = self.nm_iface.GetDevices()
        for dev_path in devices:
            dev_obj = self.bus.get_object(
                'org.freedesktop.NetworkManager',
                dev_path
            )
            dev_props = dbus.Interface(
                dev_obj,
                'org.freedesktop.DBus.Properties'
            )

            try:
                dev_interface = dev_props.Get(
                    'org.freedesktop.NetworkManager.Device',
                    'Interface'
                )
                if dev_interface == interface_name:
                    return str(dev_path)
            except dbus.exceptions.DBusException:
                continue
        return None

    def find_active_connection_by_interface(self, interface_name):
        try:
            device_path = self.nm_iface.GetDeviceByIpIface(interface_name)
            device_proxy = self.bus.get_object(
                'org.freedesktop.NetworkManager',
                device_path
            )
            device_iface = dbus.Interface(
                device_proxy,
                'org.freedesktop.DBus.Properties'
            )
            device_conn_path = device_iface.Get(
                'org.freedesktop.NetworkManager.Device',
                'ActiveConnection'
            )
            return device_conn_path
        except dbus.exceptions.DBusException as e:
            raise RuntimeError(f"Failed to deactivate connection: {e}")


def getAllInfterfacesName():
    interface_info = psutil.net_if_addrs()
    interface_names = list(interface_info.keys())

    return interface_names


# get bridge name which is not taken
# filters: the names of all interfaces
def getValidBridgeName(filters):
    for n in range(100):
        bridge = "br{}".format(n)
        if bridge not in filters:
            return bridge

    return None


def creatBridgeInterfaceNM(physical_iface):
    bridge = getValidBridgeName(getAllInfterfacesName())
    _, mac_address = runCMD(
        f'cat /sys/class/net/{physical_iface}/address'
    )

    nm = NetworkManagerClient()
    bridge_config = nm.create_bridge_config(
        connection_id=bridge,
        bridge_name=bridge,
        mac_address=mac_address
    )
    bridge_slave_config = nm.create_bridge_slave_config(
        physical_iface=physical_iface,
        bridge_conn_id=bridge,
        mac_address=mac_address
    )

    try:
        bridge_conn_path = nm.add_connection(bridge_config)
        bridge_slave_conn_path = nm.add_connection(bridge_slave_config)
        logger.info("bridge_conn_path: %s" % bridge_conn_path)
        logger.info("bridge_slave_conn_path: %s" % bridge_slave_conn_path)

        physical_iface_active_conn = nm.find_active_connection_by_interface(physical_iface)
        logger.info(f"physical_iface_conn: {physical_iface_active_conn}")

        inactive_path = nm.deactivate_connection(physical_iface_active_conn)
        logger.info(f"deactive the connection: {inactive_path}")

        active_path = nm.activate_connection(bridge_conn_path)
        logger.info(f"active the connection: {active_path}")
    except dbus.exceptions.DBusException as e:
        raise RuntimeError(f"Failed to bridge connection: {e}")

    return bridge


# filter out the detached interfaces from all active interfaces
# pick up the first one from all available interfaces, or
# pick up a bridge to return
def getValidInterfaceInfo(interfaceinfo, filters):
    valid_interface, bridge = [], []
    for dname, macaddr, ipaddr in interfaceinfo:
        if macaddr not in filters:
            if dname.startswith('br'):
                bridge.append((dname, ipaddr))
            else:
                valid_interface.append((dname, ipaddr))

    if not valid_interface and not bridge:
        return None, None

    if not valid_interface:
        return bridge[0]

    return valid_interface[0]


def getAllActiveInterfacesInfo():
    filters = ('tun', 'ppp', 'vnet', 'virbr', 'vbox', 'vmnet')
    interface_record = []

    # interface info is like this:
    # {'interfacename':
    #     [('AF_INET is 2', 'ip x.x.x.x', 'netmask x.x.x.x', 'broadcast x.x.x.x', ptp=None),
    #      ('AF_INET6 is 10', 'ip x.x.x.x', 'netmask x.x.x.x', broadcast=None, ptp=None),
    #      ('AF_LINK is 17', 'macaddr m:m:m:m:m:m', netmask=None, 'broadcast f:f:f:f:f:f', ptp=None)],
    # }
    interface_info = psutil.net_if_addrs()
    for dname, info in interface_info.items():
        if dname.startswith(filters):
            continue

        ipaddr, macaddr = '', ''
        for i in info:
            if i[0] == 2 and not i[1] == '127.0.0.1':
                ipaddr = i[1]
            if i[0] == 17:
                macaddr = i[1]
            # make sure interface is up
            if ipaddr and macaddr:
                interface_record.append((dname, macaddr, ipaddr))

    return interface_record


# according to the pci id of network cards, get mac addrs from sysfs
def getMacAddrOfPCINetDevs(pcilist):
    macaddrs = []
    # pcilist like ['pci_0000_33_00_0', 'pci_0000_17_00_0']
    regex = r'pci_([\da-fA-F]{4})_([\da-fA-F]{2})_([\da-fA-F]{2})_(\d{1})'
    for pci in pcilist:
        g = re.search(regex, pci)
        if g:
            pciid = g.group(1, 2, 3, 4)
            pcistr = "{}:{}:{}.{}".format(*pciid)

            path_addr = "/sys/bus/pci/devices/{}/net/*/address".format(pcistr)
            for file in glob(path_addr):
                with open(file, 'r') as f:
                    mac = f.readline().strip('\n')

                if mac:
                    macaddrs.append(mac)

    return macaddrs


# execute a command
def runCMD(cmd, timeout=300, realtime=True):
    import subprocess, datetime
    from time import sleep
    logger.info("Run Command: %s" % cmd)
    p = subprocess.Popen(cmd,
                         bufsize=0,
                         shell=True,
                         stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT,
                         close_fds=True,
                         start_new_session=True)

    try:
        msg = ''
        time_start = datetime.datetime.now()
        while True:
            line = p.stdout.readline()
            line = line.decode()
            if p.poll() is not None and line == '':
                break
            msg += line
            if realtime and line:
                logger.info(line.strip())

            sleep(0.01)
            time_now = datetime.datetime.now()
            if (time_now - time_start).seconds > timeout:
                raise TimeoutError(cmd, timeout)

        ret_code = p.returncode
    except TimeoutError:
        p.kill()
        p.terminate()
        # os.killpg(ret.pid, signal.SIGTERM)
        os.killpg(p.pid, 15)
        ret_code = 2
        msg = "[Error]Timeout Error: '" + cmd + \
              "' timed out after " + str(timeout) + " seconds"
    except Exception as e:
        ret_code = 4
        msg = "[Error]Unknown Error: " + str(e)

    return (ret_code, msg)


excluded_macs = init_argparser()
logger.debug("NIC MAC to be excluded from bridge creation: %s " % excluded_macs)

active_interfaces = getAllActiveInterfacesInfo()
logger.debug("Active Interfaces: %s" % active_interfaces)

interface, ipaddr = getValidInterfaceInfo(active_interfaces, excluded_macs)
if not interface:
    logger.error("No valid interface or bridge, please check hypervisor")
    sys.exit(2)
logger.debug("Interface: %s\tIP Addr: %s" % (interface, ipaddr))

bridge = creatBridgeInterfaceNM(interface)
print("bridge: %s" % bridge)
