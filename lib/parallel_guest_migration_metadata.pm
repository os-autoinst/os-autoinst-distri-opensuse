# PARALLEL GUEST MIGRATION BASE AND METADATA MODULE
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Base and metadata module to define common or shared metadata:
# %_guest_matrix to hold all qualified guests under test.
# %_guest_network_matrix to specify various types of guest network.
# %_guest_migration_matrix to store all guest migration tests.
# %_test_result to record test reults for all guests and tests.
# %_host_params to define common or shared setings to be used on hosts.
# %_guest_paramas to define global settings for all guests under test.
# All global data is exported and to be used for higher-level modules.
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt <qe-virt@suse.de>
package parallel_guest_migration_metadata;

use strict;
use warnings;
use testapi;
use Tie::IxHash;
use Exporter qw(import);
use virt_autotest::utils qw(get_default_ssh_keyfile);

our @EXPORT = qw(
  %_guest_matrix
  %_guest_network_matrix
  %_test_result
  %_guest_migration_matrix_kvm
  %_guest_migration_matrix_xen
  %_guest_migration_matrix
  %_host_params
  %_guest_params
);

tie our %_guest_matrix, 'Tie::IxHash', ();
tie our %_guest_network_matrix, 'Tie::IxHash', ();
tie our %_test_result, 'Tie::IxHash', ();
%_guest_network_matrix = (
    nat => {
        device => 'vn_nat_vbrX',
        ipaddr => '192.168.X.1',
        netmask => '255.255.255.0',
        masklen => '24',
        startaddr => '192.168.X.2',
        endaddr => '192.168.X.254'
    },
    route => {
        device => 'vn_route_vbrX',
        ipaddr => '192.168.X.1',
        netmask => '255.255.255.0',
        masklen => '24',
        startaddr => '192.168.X.2',
        endaddr => '192.168.X.254'
    },
    default => {
        device => 'virbr0',
        ipaddr => 'default',
        netmask => 'default',
        masklen => 'default',
        startaddr => 'default',
        endaddr => 'default'
    },
    host => {
        device => 'br0',
        ipaddr => '',
        netmask => '',
        masklen => '',
        startaddr => '',
        endaddr => ''
    },
    bridge => {
        device => 'brX',
        ipaddr => '192.168.X.1',
        netmask => '255.255.255.0',
        masklen => '24',
        startaddr => '192.168.X.2',
        endaddr => '192.168.X.254'
    }
);
tie our %_guest_migration_matrix_kvm, 'Tie::IxHash', (
    virsh_live_native => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --unsafe guest dsturi',
    virsh_live_native_p2p => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --p2p --persistent --change-protection --unsafe --compressed --abort-on-error --undefinesource guest dsturi',
    virsh_live_tunnel_p2p => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --p2p --tunnelled --persistent --change-protection --unsafe --compressed --abort-on-error --undefinesource guest dsturi',
    virsh_live_native_p2p_auto_postcopy => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --p2p --persistent --change-protection --unsafe --compressed --abort-on-error --postcopy --postcopy-after-precopy --undefinesource guest dsturi',
    virsh_live_native_p2p_manual_postcopy => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --p2p --persistent --change-protection --unsafe --compressed --abort-on-error --postcopy --undefinesource guest dsturi#virsh --connect=srcuri --debug=0 migrate-postcopy guest',
    virsh_offline_native_p2p => 'virsh --connect=srcuri --debug=0 migrate --verbose --offline --p2p --persistent --unsafe --undefinesource guest dsturi');
tie our %_guest_migration_matrix_xen, 'Tie::IxHash', (
    xl_online => 'xl -vvv migrate guest dstip',
    virsh_online => 'virsh --connect=srcuri --debug=0 migrate --verbose --undefinesource guest dsturi',
    virsh_live => 'virsh --connect=srcuri --debug=0 migrate --verbose --live --undefinesource guest dsturi');
tie our %_guest_migration_matrix, 'Tie::IxHash', (kvm => \%_guest_migration_matrix_kvm, xen => \%_guest_migration_matrix_xen);

our %_host_params = (
    'ssh_command' => 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ' . get_var('HOST_SSH_KEYFILE', get_default_ssh_keyfile()), # SSH command used for ssh login, for example, "ssh -vvv -i identity_file username"
    'ssh_keyfile' => get_var('HOST_SSH_KEYFILE', get_default_ssh_keyfile()),    # Customized ssh key file for host communication
    'external_nfsshare' => get_var('EXTERNAL_NFS_SHARE', ''),    # External NFS share to be used for guest migration
    'host_nfsshare' => get_var('HOST_NFS_SHARE', '/home/virt'),    # NFS share on source host for guest migration
    'source_imgpath' => get_var('SOURCE_IMAGE_PATH', '/var/lib/libvirt/images'),    # The folder in which guest assets are stored
    'target_imgpath' => get_var('TARGET_IMAGE_PATH', '/var/lib/libvirt/images'),    # The folder to which NFS share should be mounted
    'use_storage_pool' => get_var('USE_STORAGE_POOL', ''),    # Whether use libvirt storage pool (1 or 0)
    'storage_pool_name' => get_var('STORAGE_POOL_NAME', 'libvirt_guest_migration'),    # libvirt storage pool name
    'reconsole_counter' => get_var('RESELECT_CONSOLE_COUNTER', 180)    # Reselect disconnected console if condition triggered in counter
);

our %_guest_params = (
    'ssh_command' => 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ' . get_var('GUEST_SSH_KEYFILE', get_default_ssh_keyfile()), # SSH command used for ssh login, for example, "ssh -vvv -i identity_file username"
    'ssh_keyfile' => get_var('GUEST_SSH_KEYFILE', get_default_ssh_keyfile()),    # Customized ssh key file for guest communication
    'dns_domainname' => get_var('GUEST_DNS_DOMAINNAME', 'testvirt.net'),    # Domain suffix to be used for guest communication
    'use_dns' => get_var('GUEST_USE_DNS', 0),    # Whether use DNS/FQDN (1 or 0)
    'check_ipaddr' => get_var('GUEST_CHECK_IPADDR', 1)    #Whether check ip first before or after doing some operations
);

1;
