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
use testapi;
use mmapi;
use Exporter qw(import);

our @EXPORT = qw($guest_install_prepare_keep_guest $hyper_visor $vm_disk_dir $guest_os $nfs_local_dir $install_script $scenario_name get_var_from_parent get_var_from_child set_hosts);

our ($guest_install_prepare_keep_guest, $hyper_visor, $vm_disk_dir, $guest_os, $nfs_local_dir, $install_script, $scenario_name);

#get the guest product
$guest_os = get_var('GUEST_OS', 'sles-12-sp2-64-fv-def-net');

#Detect the host product version
$scenario_name = get_var('NAME');
$hyper_visor = ($scenario_name =~ /xen/) ? "xen" : "kvm";

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

sub get_var_from_parent {
    my ($var) = @_;
    my $parents = get_parents();
    #Query every parent to find the var
    for my $job_id (@$parents) {
        my $ref = get_job_autoinst_vars($job_id);
        return $ref->{$var} if defined $ref->{$var};
    }
    return;
}

sub get_var_from_child {
    my ($var) = @_;
    my $child = get_children();
    #Query every child to find the var
    for my $job_id (keys %$child) {
        my $ref = get_job_autoinst_vars($job_id);
        return $ref->{$var} if defined $ref->{$var};
    }
    return;
}

sub set_hosts {
    my ($self) = @_;
    my ($target_ip, $target_name);
    if ($scenario_name =~ /_HT/) {

        $target_ip   = get_var_from_child('MY_IP');
        $target_name = get_var_from_child('MY_NAME');

    }
    else {

        $target_ip   = get_var_from_parent('MY_IP');
        $target_name = get_var_from_parent('MY_NAME');
    }

    $self->execute_script_run("sed -i '/$target_ip/d' /etc/hosts ;echo $target_ip $target_name >>/etc/hosts", 15);
    my $self_ip   = get_var('MY_IP');
    my $self_name = get_var('MY_NAME');
    $self->execute_script_run("sed -i '/$self_ip/d' /etc/hosts ;echo $self_ip $self_name >>/etc/hosts", 15);

}
1;
