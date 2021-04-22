# SUSE's openQA tests
#
# Copyright © 2016-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Waits for the guest to boot, sets some variables for LTP then
#          dynamically loads the test modules based on the runtest file
#          contents.
# Maintainer: QE Kernel <kernel-qa@suse.de>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use LTP::utils;
use version_utils 'is_jeos';
use utils 'assert_secureboot_status';

sub run {
    my ($self) = @_;
    my $cmd_file = get_var('LTP_COMMAND_FILE') || '';
    # Use standard boot for ipmi backend with IPXE
    if (check_var('BACKEND', 'ipmi') && !get_var('IPXE_CONSOLE')) {
        record_info('INFO', 'IPMI boot');
        select_console 'sol', await_console => 0;
        assert_screen('linux-login', 1800);
    }
    elsif (is_jeos) {
        record_info('Loaded JeOS image', 'nothing to do...');
    }
    else {
        record_info('INFO', 'normal boot or boot with params');
        # during install_ltp, the second boot may take longer than usual
        $self->wait_boot(ready_time => 1800);
    }

    $self->select_serial_terminal;
    assert_secureboot_status(1) if (get_var('SECUREBOOT'));

    # check kGraft patch if KGRAFT=1
    if (check_var('KGRAFT', '1') && !check_var('REMOVE_KGRAFT', '1')) {
        assert_script_run("uname -v| grep -E '(/kGraft-|/lp-)'");
    }

    prepare_ltp_env();
    upload_logs('/boot/config-$(uname -r)', failok => 1);
    init_ltp_tests($cmd_file);

    # If the command file (runtest file) is set then we dynamically schedule
    # the test and shutdown modules.
    schedule_tests($cmd_file) if $cmd_file;
}

sub test_flags {
    return {
        fatal     => 1,
        milestone => 1,
    };
}

1;

=head1 Configuration

See run_ltp.pm.

=cut
