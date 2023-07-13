# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare SLEM on PC for testing
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use transactional qw(trup_call process_reboot);

sub run {
    my ($self, $args) = @_;
    my $instance = $args->{my_instance};
    select_serial_terminal;

    if (get_var("PUBLIC_CLOUD_CONTAINERS")) {
        my $runtime = get_required_var('CONTAINER_RUNTIME');
        # Install packages for container test runs
        trup_call("pkg install $runtime toolbox");
        $instance->softreboot();
    }
}

sub test_flags {
    return {fatal => 1};
}

1;

