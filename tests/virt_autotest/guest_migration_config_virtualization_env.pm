# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: Virtualization multi-machine job : Guest Migration
# Maintainer: jerry <jtang@suse.com>

use base multi_machine_job_base;
use strict;
use warnings;
use testapi;
use utils 'systemctl';
use guest_migration_base;

sub run {
    my ($self) = @_;

    #settle all common settings
    set_common_settings;

    systemctl 'stop ' . $self->firewall;

    #Create disk backup directory
    $self->execute_script_run("[ -d /tmp/pesudo_mount_server ] || mkdir -p /tmp/pesudo_mount_server", 500);

    #Change the config file for hyper_visor
    if ($hyper_visor =~ /xen/) {
        $self->execute_script_run("source /usr/share/qa/virtautolib/lib/virtlib;changeXendConfig", 500);
    }
    else {
        $self->execute_script_run("source /usr/share/qa/virtautolib/lib/virtlib;changeLibvirtConfig", 500);
    }

    #Query and save the ip addres
    my $ip_out = $self->execute_script_run('ip route show|grep kernel|cut -d" " -f12|head -1', 3);
    my $name_out = $self->execute_script_run('hostname', 3);

    $self->set_ip_and_hostname_to_var;
}
1;
