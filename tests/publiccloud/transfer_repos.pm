# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Transfer repositories to the public cloud instasnce
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::ssh_interactive_init';
use registration;
use warnings;
use testapi;
use strict;
use utils;

sub run {
    my ($self, $args) = @_;

    my @addons = split(/,/, get_var('SCC_ADDONS', ''));

    select_console 'tunnel-console';

    assert_script_run("du -sh ~/repos");
    assert_script_run("rsync -va -e ssh ~/repos root@" . $args->{my_instance}->public_ip . ":'/tmp/repos'", timeout => 900);
    $args->{my_instance}->run_ssh_command(cmd => "sudo find /tmp/repos/ -name *.repo -exec sed -i 's,http://,/tmp/repos/repos/,g' '{}' \\;");
    $args->{my_instance}->run_ssh_command(cmd => "sudo find /tmp/repos/ -name *.repo -exec zypper ar '{}' \\;");
    $args->{my_instance}->run_ssh_command(cmd => "sudo find /tmp/repos/ -name *.repo -exec echo '{}' \\;");
}

1;

