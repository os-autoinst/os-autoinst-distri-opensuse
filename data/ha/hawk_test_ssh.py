#!/usr/bin/python3
"""Define SSH related functions to test the HAWK GUI"""

from distutils.version import LooseVersion as Version
import paramiko, hawk_test_results, warnings
# Ignore CryptographyDeprecationWarning shown when using paramiko
try:
    from cryptography.utils import CryptographyDeprecationWarning
    warnings.simplefilter('ignore', CryptographyDeprecationWarning)
except ImportError:
    pass

class hawkTestSSHError(Exception):
    """Base class for exceptions in this module."""
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return repr(self.value)

class hawkTestSSH:
    def __init__(self, hostname, secret):
        self.ssh = paramiko.SSHClient()
        self.ssh.load_system_host_keys()
        self.ssh.set_missing_host_key_policy(paramiko.WarningPolicy)
        self.ssh.connect(hostname=hostname.lower(), username="root", password=secret)

    def is_ssh(self):
        clase = str(type(self.ssh)).split(' ')[1][1:26]
        if clase != 'paramiko.client.SSHClient':
            raise hawkTestSSHError('SSH object must be of type %s. Got: [%s]' %
                                   ('paramiko.client.SSHClient', type(s)))
        return True

    def check_cluster_conf_ssh(self, command, mustmatch):
        command = str(command)
        if self.is_ssh():
            resp = self.ssh.exec_command(command)
            out = resp[1].read().decode().rstrip('\n')
            err = resp[2].read().decode().rstrip('\n')
            print("INFO: ssh command [%s] got output [%s] and error [%s]" % (command, out, err))
            if err:
                print("ERROR: got an error over SSH: [%s]" % err)
                return False
            if isinstance(mustmatch, str):
                if mustmatch:
                    if mustmatch in out:
                        return True
                    return False
                return out == mustmatch
            elif isinstance(mustmatch, list):
                for exp in mustmatch:
                    if str(exp) not in out:
                        return False
                return True
            else:
                raise hawkTestSSHError("check_cluster_conf_ssh: mustmatch must be str or list")
        return False

    def set_test_status(self, results, test, status):
        if isinstance(results, hawk_test_results.resultSet):
            results.set_test_status(test, status)

    def verify_stonith_in_maintenance(self, results):
        if self.check_cluster_conf_ssh("crm status | grep stonith-sbd", "unmanaged"):
            print("INFO: stonith-sbd is unmanaged")
            self.set_test_status(results, 'verify_stonith_in_maintenance', 'passed')
            return 0
        print("ERROR: stonith-sbd is not unmanaged but should be")
        self.set_test_status(results, 'verify_stonith_in_maintenance', 'failed')
        return 1    # return non zero value on error

    def verify_node_maintenance(self, results):
        if self.check_cluster_conf_ssh("crm status | grep -i ^node", "maintenance"):
            print("INFO: cluster node set successfully in maintenance mode")
            self.set_test_status(results, 'verify_node_maintenance', 'passed')
            return 0
        print("ERROR: cluster node failed to switch to maintenance mode")
        self.set_test_status(results, 'verify_node_maintenance', 'failed')
        return 1    # return non zero value on error

    def verify_primitive(self, myprimitive, version, results):
        matches = ["%s anything" % str(myprimitive), "binfile=file", "op start timeout=35s",
                   "op monitor timeout=9s interval=13s", "meta target-role=Started"]
        if Version(str(version)) < Version('15'):
            matches.append("op stop timeout=15s")
        else:
            matches.append("op stop timeout=15s on-fail=stop")
        if self.check_cluster_conf_ssh("crm configure show", matches):
            print("INFO: primitive [%s] correctly defined in the cluster configuration" %
                  myprimitive)
            self.set_test_status(results, 'verify_primitive', 'passed')
            return 0
        print("ERROR: primitive [%s] missing from cluster configuration" % myprimitive)
        self.set_test_status(results, 'verify_primitive', 'failed')
        return 1    # return non zero value on error

    def verify_primitive_removed(self, results):
        if self.check_cluster_conf_ssh("crm resource list | grep ocf::heartbeat:anything", ''):
            print("INFO: primitive successfully removed")
            self.set_test_status(results, 'verify_primitive_removed', 'passed')
            return 0
        print("ERROR: primitive [%s] still present in the cluster while checking with SSH" %
              myprimitive)
        self.set_test_status(results, 'verify_primitive_removed', 'failed')
        return 1    # return non zero value on error
