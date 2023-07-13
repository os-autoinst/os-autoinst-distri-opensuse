# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Waits for the guest to boot, sets some variables for LTP then
#          dynamically loads the test modules based on the runtest file
#          contents.
# Maintainer: QE Kernel <kernel-qa@suse.de>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use LTP::utils;
use version_utils qw(is_jeos is_sle);
use utils 'assert_secureboot_status';

sub run {
    my ($self) = @_;
    my $cmd_file = get_var('LTP_COMMAND_FILE') || '';

    # Use standard boot for ipmi backend with IPXE
    if (is_ipmi && !get_var('IPXE_CONSOLE')) {
        record_info('INFO', 'IPMI boot');
        select_console 'sol', await_console => 0;
        assert_screen('linux-login', 1800);
    }
    elsif (is_jeos) {
        record_info('Loaded JeOS image', 'nothing to do...');
    }
    elsif (is_backend_s390x) {
        record_info('s390x backend', 'nothing to do...');
    }
    else {
        record_info('INFO', 'normal boot or boot with params');
        # during install_ltp, the second boot may take longer than usual
        $self->wait_boot(ready_time => 1800);
    }

    select_serial_terminal;

    # Debug code for poo#81142
    script_run('gzip -9 </dev/fb0 >framebuffer.dat.gz');
    upload_logs('framebuffer.dat.gz', failok => 1);

    assert_secureboot_status(1) if (get_var('SECUREBOOT'));

    log_versions;

    # check kGraft patch if KGRAFT=1
    if (check_var('KGRAFT', '1') && !check_var('REMOVE_KGRAFT', '1')) {
        my $lp_tag = is_sle('>=15-sp4') ? 'lp' : 'lp-';
        assert_script_run("uname -v | grep -E '(/kGraft-|/${lp_tag})'");
    }

    # module is used by non-LTP tests, i.e. kernel-live-patching
    return unless (get_var('LTP_COMMAND_FILE'));

    prepare_ltp_env;
    init_ltp_tests($cmd_file);

    # If the command file (runtest file) is set then we dynamically schedule
    # the test and shutdown modules.
    schedule_tests($cmd_file) if $cmd_file;
}

sub test_flags {
    return {
        fatal => 1,
        milestone => 1,
    };
}

1;

=head1 Configuration

See run_ltp.pm.

=cut
