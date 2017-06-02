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
    my $url = get_required_var("INSTALL_KOTD");
    if ($url =~ /^[\w.]+-[\w.]+$/) {
        $url = "http://download.suse.de/ibs/Devel:/Kernel:/$url/standard/";
    }
    zypper_call("--no-gpg-check ar -f '$url' kotd", timeout => 600);
    zypper_call("--gpg-auto-import-keys ref",       timeout => 1200);
}

# Install kotd kernel and reboot
sub install_from_repo {
    zypper_call("install --oldpackage --from kotd kernel-default", timeout => 1200);
}

sub run {
    my $self = shift;
    $self->wait_boot;
    if (get_var('VIRTIO_CONSOLE')) {
        select_console('root-virtio-terminal');
    }
    else {
        select_console('root-console');
    }
    add_repos;
    install_from_repo;

    select_console('root-console');
    type_string "reboot\n";
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Notes

=head2 INSTALL_KOTD

INSTALL_KOTD can be the version of operating system(e.g. openSUSE-42.2, SLE12-SP3) or the entire url of a zypper repo(e.g. http://download.suse.de/ibs/Devel:/Kernel:/SLE12-SP3/standard/)

=cut
