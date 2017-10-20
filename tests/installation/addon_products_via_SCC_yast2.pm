# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: add addon to SLES via SCC
#          https://progress.opensuse.org/issues/16402
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base qw(y2logsstep y2x11test);
use strict;
use testapi;
use registration 'fill_in_registration_data';

sub run {
    my ($self) = @_;
    x11_start_program('xterm');
    # add every used addon to regurl for proxy SCC
    if (get_var('SCC_ADDONS')) {
        my @addon_proxy = ("url: http://server-" . get_var('BUILD_SLE'));
        for my $addon (split(/,/, get_var('SCC_ADDONS', ''))) {
            my $uc_addon = uc $addon;    # change to uppercase to match variable
            push(@addon_proxy, "\b.$addon-" . get_var("BUILD_$uc_addon"));
        }
        script_sudo "echo \"@addon_proxy.proxy.scc.suse.de\" > /etc/SUSEConnect", 0;
    }
    # Disable screensaver
    type_string "gsettings set org.gnome.desktop.session idle-delay 0\n";
    send_key "ctrl-d";
    $self->launch_yast2_module_x11('scc', target_match => [qw(scc-registration packagekit-warning)]);
    if (match_has_tag 'packagekit-warning') {
        send_key 'alt-y';
        assert_screen 'scc-registration';
    }
    fill_in_registration_data;
    send_key 'alt-f4';    # close yast2 control center
    assert_screen 'generic-desktop';
}

1;
# vim: set sw=4 et:
