# Evolution tests
#
# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case #1503857: Evolution First time launch and setup assistant
# - Cleanup evolution config files and start application
# - Handle evolution first time wizard
# - Register an account using the provided credentials
# - Check for authentication or folder scan attempts
# - Open help and then go to about
# - Send esc to close help
# - Exit evolution
# Maintainer: Zhaocong Jia <zcjia@suse.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);

sub run {
    my $self        = shift;
    my $mail_box    = 'nooops_test3@aim.com';
    my $mail_passwd = 'opensuse';

    mouse_hide(1);
    x11_start_program('xterm -e "gsettings set org.gnome.desktop.session idle-delay 0"', valid => 0);
    $self->start_evolution($mail_box);

    if (check_screen "evolution_mail-auth", 5) {
        send_key "alt-a";    #disable keyring option, in SP2 or tumbleweed
        send_key "alt-p";
        type_string "$mail_passwd";
        send_key "ret";
    }
    send_key "super-up" if (check_screen "evolution_mail-init-window", 2);
    assert_screen "evolution_mail-max-window";

    # Help
    send_key "alt-h";
    wait_still_screen(2);
    send_key "a";
    assert_screen "evolution_about";
    send_key "esc";
    wait_still_screen(2);

    # Exit
    send_key "ctrl-q";
}

1;
