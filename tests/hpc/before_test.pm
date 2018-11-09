# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary:  Basic preparation before any HPC test
# Maintainer: mgriessmeier <mgriessmeier@suse.com>

use base "hpcbase";
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use registration 'add_suseconnect_product';

sub ensure_registered {
    assert_script_run('SUSEConnect --cleanup', 200);
    add_suseconnect_product('SLES', get_var('VERSION'), get_var('ARCH'), ' -e testing@suse.com -r ' . get_required_var('SCC_REGCODE'));
    add_suseconnect_product('sle-module-hpc',           get_var('VERSION'));
    add_suseconnect_product('sle-module-web-scripting', get_var('VERSION'));
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # disable packagekitd
    pkcon_quit();

    # Stop firewall
    systemctl 'stop ' . $self->firewall;
    set_hostname(get_var('HOSTNAME', 'susetest'));
    ensure_registered();
    if (get_var('HPC_REPO')) {
        my $repo     = get_var('HPC_REPO');
        my $reponame = get_required_var('HPC_REPONAME');
        zypper_call("ar -f $repo $reponame");
        assert_script_run "zypper lr | grep $reponame";

        zypper_call("--gpg-auto-import-keys ref");
        zypper_call 'up';
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
