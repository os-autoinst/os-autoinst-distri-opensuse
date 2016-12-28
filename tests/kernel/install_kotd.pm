# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module installs the KOTD (kernel of the day) and then reboots.
# Maintainer: Nathan Zhao <jtzhao@suse.com>
use 5.018;
use base "opensusebasetest";
use utils;
use testapi;

# Add kotd repo
sub add_repos {
    my $release = get_required_var("INSTALL_KOTD");
    my $url     = "http://download.suse.de/ibs/Devel:/Kernel:/$release/standard/";
    zypper_call("--no-gpg-check ar -f '$url' kotd", timeout => 600);
    zypper_call("--gpg-auto-import-keys ref",       timeout => 1200);
}

# Install kotd kernel and reboot
sub install_from_repo {
    zypper_call("install --from kotd kernel-default", timeout => 1200);
    type_string("reboot\n");
}

sub run {
    my $self = shift;
    $self->wait_boot;
    select_console('root-console');
    add_repos;
    install_from_repo;
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Notes

=head2 INSTALL_KOTD

INSTALL_KOTD is the version of operating system, such as openSUSE-42.2, SLE12-SP3

=cut
