# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: Virtualization multi-machine job : Guest Migration
# Maintainer: jerry <jtang@suse.com>

package guest_migration_base;
use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use mmapi;
use Exporter 'import';

our @EXPORT = qw($guest_install_prepare_keep_guest $hyper_visor $vm_disk_dir $guest_os $nfs_local_dir $install_script $scenario_name set_common_settings);

our ($guest_install_prepare_keep_guest, $hyper_visor, $vm_disk_dir, $guest_os, $nfs_local_dir, $install_script, $scenario_name);

sub set_common_settings {
    #get the guest product
    $guest_os = get_var('GUEST_OS', 'sles-12-sp2-64-fv-def-net');

    #Detect the host product version
    $scenario_name = get_var('NAME');
    $hyper_visor   = ($scenario_name =~ /xen/) ? "xen" : "kvm";

    #Setup different var on different products
    my $host_os = get_var('HOST_OS');
    if ($host_os =~ /current_build/) {

        $vm_disk_dir                      = "/var/lib/libvirt/images";
        $install_script                   = "/usr/share/qa/qa_test_virtualization/virt_installos";
        $guest_install_prepare_keep_guest = qq(sed -i '/-d -o/s/-d -o/-d -u -o/' $install_script );
    }

    if ($host_os =~ /sles-11/i) {

        $vm_disk_dir                      = "/var/lib/$hyper_visor/images";
        $install_script                   = "/usr/share/qa/qa_test_virtualization/installos";
        $guest_install_prepare_keep_guest = qq(sed -i 's/INSTALL_METHOD$/& -g/' $install_script);
        $install_script .= " standalone";
    }

    $nfs_local_dir = "/tmp/pesudo_mount_server";
}
1;
