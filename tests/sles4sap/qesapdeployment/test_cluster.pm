# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;

use constant GIT_CLONE_LOG => '/tmp/git_clone.log';

sub run {
    my ($self) = @_;
    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));

    my $ansible_args = "-i $inventory -u cloudadmin -b --become-user=root";
    assert_script_run('ansible all ' . $ansible_args . ' -a "pwd"');
    assert_script_run('ansible all ' . $ansible_args . ' -a "uname -a"');
    assert_script_run('ansible all ' . $ansible_args . ' -a "cat /etc/os-release"');
    assert_script_run('ansible hana ' . $ansible_args . ' -a "ls -lai /hana/"');
    assert_script_run('ansible vmhana01 ' . $ansible_args . ' -a "crm status"');
    assert_script_run('ansible vmhana01 ' . $ansible_args . ' -a "crm_mon -R -r -n -N -1"');
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300);
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    $self->SUPER::post_fail_hook;
}

1;
