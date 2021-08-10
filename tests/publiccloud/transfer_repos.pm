# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: rsync
# Summary: Transfer repositories to the public cloud instasnce
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::ssh_interactive_init';
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::utils "select_host_console";

sub run {
    my ($self, $args) = @_;
    select_host_console();    # select console on the host, not the PC instance

    my @addons  = split(/,/, get_var('SCC_ADDONS', ''));
    my $skip_mu = get_var('PUBLIC_CLOUD_SKIP_MU', get_var('QAM_PUBLICCLOUD_SKIP_DOWNLOAD', 0));

    # Trigger to skip the download to speed up verification runs
    if ($skip_mu) {
        record_info('Skip download', 'Skipping maintenance update download (triggered by setting)');
    } else {
        assert_script_run('du -sh ~/repos');
        my $timeout = 2400;
        assert_script_run("rsync --timeout=$timeout -uvahP -e ssh ~/repos root@" . $args->{my_instance}->public_ip . ":'/tmp/repos'", timeout => $timeout + 10);
        $args->{my_instance}->run_ssh_command(cmd => "sudo find /tmp/repos/ -name *.repo -exec sed -i 's,http://,/tmp/repos/repos/,g' '{}' \\;");
        $args->{my_instance}->run_ssh_command(cmd => "sudo find /tmp/repos/ -name *.repo -exec zypper ar -p10 '{}' \\;");
        $args->{my_instance}->run_ssh_command(cmd => "sudo find /tmp/repos/ -name *.repo -exec echo '{}' \\;");

        $args->{my_instance}->run_ssh_command(cmd => "zypper lr -P");
    }
}

1;

