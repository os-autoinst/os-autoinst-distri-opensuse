# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: transactional-update
# Summary: Host configuration operations (e.g. disable grub timeout,
#              kernel params, etc)
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use Mojo::Base qw(consoletest);
use testapi;
use transactional qw(process_reboot);
use bootloader_setup qw(change_grub_config);
use utils qw(ensure_ca_certificates_suse_installed zypper_call);
use version_utils qw(is_alp);

sub run {
    select_console 'root-console';

    # GRUB Configuration
    my $keep_grub_timeout = get_var('KEEP_GRUB_TIMEOUT');
    my $extrabootparams = get_var('EXTRABOOTPARAMS');
    change_grub_config('=\"[^\"]*', "& $extrabootparams", 'GRUB_CMDLINE_LINUX_DEFAULT') if $extrabootparams;
    $keep_grub_timeout or change_grub_config('=.*', '=-1', 'GRUB_TIMEOUT');

    if (!$keep_grub_timeout or $extrabootparams) {
        record_info('GRUB', script_output('cat /etc/default/grub'));
        assert_script_run('transactional-update grub.cfg');
        ensure_ca_certificates_suse_installed if get_var('HOST_VERSION');
        process_reboot(trigger => 1);
    }

    if (is_alp) {
        # Add Core repo
        my $repo = get_required_var('REPO_CORE');
        zypper_call("ar $repo 'ALP Build Repository'");
        zypper_call("--gpg-auto-import-keys ref");
    }
    record_info('REPOS', script_output('zypper lr --url', proceed_on_failure => 1));
}

sub test_flags {
    return {no_rollback => 1, fatal => 1, milestone => 1};
}

1;
