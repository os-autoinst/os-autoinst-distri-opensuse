# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: QAM incident install test in openQA
#    1) boots prepared image / clean install
#    2) update it to last released updates
#    3) install packages mentioned in patch
#    5) try install update and store install_logs
#    6) try reboot
#    7) all done
#
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base "opensusebasetest";

use strict;
use warnings;

use utils;
use power_action_utils qw(prepare_system_shutdown power_action);

use qam;
use testapi;

sub install_packages {
    my $patch_info = shift;
    my $pattern    = qr/\s+(.+)(?!\.src)\..*\s<\s.*/;

    # loop over packages in patchinfo and try installation
    foreach my $line (split(/\n/, $patch_info)) {
        if (my ($package) = $line =~ $pattern and $line !~ "xen-tools-domU" and $line !~ "-devel" and $line !~ "-base\$") {
            zypper_call("in $package", exitcode => [0, 102, 103, 104]);
            save_screenshot;
        }
    }
}

sub get_patch {
    my ($incident_id, $repos) = @_;
    $repos =~ tr/,/ /;
    my $patches = script_output("zypper patches -r $repos | awk -F '|' '/$incident_id/ { printf \$2 }'");
    $patches =~ s/\r//g;
    return $patches;
}
sub get_patchinfos {
    my ($patches) = @_;
    my $patches_status = script_output("zypper -n info -t patch $patches");
    return $patches_status;
}

sub change_repos_state {
    my ($repos, $state) = @_;
    $repos =~ tr/,/ /;
    zypper_call("mr --$state $repos");
}

sub run {
    my ($self)      = @_;
    my $incident_id = get_required_var('INCIDENT_ID');
    my $repos       = get_required_var('INCIDENT_REPO');

    select_console 'root-console';

    fully_patch_system;

    set_var('MAINT_TEST_REPO', $repos);
    add_test_repositories;

    my $patches = get_patch($incident_id, $repos);

    my $patch_infos = get_patchinfos($patches);

    change_repos_state($repos, 'disable');

    install_packages($patch_infos);

    change_repos_state($repos, 'enable');

    zypper_call("in -l -t patch ${patches}", exitcode => [0, 102, 103], log => 'zypper.log');

    prepare_system_shutdown;
    power_action("reboot");
    $self->wait_boot;
}

sub test_flags {
    return {fatal => 1};
}

1;
