# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare SLEM on PC for testing
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::zypper qw(pc_pkg_call);
use publiccloud::utils qw(ssh_allow_openqa_port_selinux);
use version_utils qw(is_public_cloud is_sle_micro);

sub run {
    my ($self, $args) = @_;
    my $instance = $args->{my_instance};

    # Moved here from ssh_interactive_start.pm (poo#207027/#206808): done before the
    # interactive tunnel is established, so any reboot it triggers takes softreboot()'s
    # simple untunneled path instead of the fragile tunneled leave/reconnect dance.
    ssh_allow_openqa_port_selinux($instance) if (is_public_cloud && is_sle_micro(">=5.4"));

    if (get_var("PUBLIC_CLOUD_CONTAINERS")) {
        my $runtime = get_required_var('CONTAINER_RUNTIMES');
        # Install packages for container test runs
        pc_pkg_call($instance, "in $runtime toolbox");
        $instance->softreboot();
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
