# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that there is access to the local hard disk from rescuesystem
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use testapi;
use version_utils qw (is_sle);

sub run {
    my $cmd;
    my $hdddev = check_var('VIRSH_VMM_FAMILY', 'xen') ? 'xvda2' : 'vda2';

    if (is_sle(">=16.0") && check_var('AGAMA_GRUB_SELECTION', 'rescue_system')) {
        assert_screen 'inst-console';
        select_console 'install-shell';
        $cmd = "cat /mnt/etc/os-release | grep -oP \"(?<=PRETTY_NAME=).*\"";
    }
    else {
        $cmd = "cat /mnt/etc/SuSE-release";
    }
    assert_script_run "mount /dev/$hdddev /mnt";
    validate_script_output($cmd, sub { m/SUSE Linux Enterprise Server.*/ });
}

sub test_flags {
    return {fatal => 1};
}

1;
