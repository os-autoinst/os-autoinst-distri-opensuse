# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure WSL users
# Maintainer: qa-c  <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi;
use version_utils qw(is_sle);
use wsl qw(is_sut_reg);

sub is_fake_scc_url_needed {
    return get_var('SCC_URL') && get_var('BETA', 0);
}

sub set_fake_scc_url {
    return unless is_fake_scc_url_needed;
    my $proxyscc = get_var('SCC_URL');

    assert_screen 'yast2-wsl-firstboot-welcome';
    # Exit YaST2 Firstboot
    # Pop up warning should appear
    send_key 'alt-r';
    assert_screen 'wsl-firsboot-exit-warning-pop-up';
    # Confirm to close YaST2 firstboot
    send_key 'alt-y';
    assert_screen 'wsl-installing-prompt';

    wait_screen_change(sub {
            type_string qq{echo "url: $proxyscc" > /etc/SUSEConnect}, max_interval => 125, wait_screen_change => 2;
    }, 5);
    send_key 'ret';
    save_screenshot;
    # Start YaST2 Firstboot with changed SCC url
    wait_screen_change(sub {
            type_string q{/usr/lib/YaST2/startup/YaST2.call firstboot firstboot}, max_interval => 125, wait_screen_change => 2;
    }, 5);
    send_key 'ret';

    assert_screen 'yast2-wsl-firstboot-welcome';
}

sub enter_user_details {
    my $creds = shift;

    foreach (@{$creds}) {
        if (defined($_)) {
            wait_still_screen stilltime => 1, timeout => 5;
            wait_screen_change { type_string "$_", max_interval => 125, wait_screen_change => 2 };
            wait_screen_change(sub { send_key 'tab' }, 10);
            wait_still_screen stilltime => 3, timeout => 10;
        } else {
            wait_screen_change(sub { send_key 'tab' }, 10);
            next;
        }
    }
}

sub license {
    # license agreement
    assert_screen 'wsl-license';
    send_key 'alt-n';

    if (is_sle) {
        # license warning
        assert_screen 'wsl-license-not-accepted';
        send_key 'ret';
        # Accept license
        assert_screen 'wsl-license';
        send_key 'alt-a';
        assert_screen 'license-accepted';
        send_key 'alt-n';
    }
}

sub register_via_scc {
    my $skip = shift;
    assert_screen 'wsl-registration', 120;

    unless (!!$skip) {
        wait_screen_change(sub { send_key 'alt-s' }, 10);
        assert_screen 'wsl-skip-registration-warning';
        send_key 'ret';
        assert_screen 'wsl-skip-registration-checked';
        send_key 'alt-n';
        return;
    }

    my $reg_code = get_required_var('SCC_REGCODE');

    wait_screen_change(sub { send_key 'alt-c' }, 10);
    wait_screen_change { type_string $reg_code, max_interval => 125, wait_screen_change => 2 };
    send_key 'alt-n';
    assert_screen 'wsl-registration-repository-offer', 180;
    send_key 'alt-y';
    assert_screen 'wsl-extension-module-selection';
    send_key 'alt-n';
}

sub run {
    # WSL installation is in progress
    assert_screen [qw(yast2-wsl-firstboot-welcome wsl-installing-prompt)], 420;

    if (match_has_tag 'yast2-wsl-firstboot-welcome') {
        assert_and_click 'window-max';
        wait_still_screen stilltime => 3, timeout => 10;
        set_fake_scc_url();
        send_key 'alt-n';
        # License handling
        license;
        # User credentials
        assert_screen 'local-user-credentials';
        enter_user_details([$realname, undef, $password, $password]);
        send_key 'alt-n';
        # Registration
        is_sle && register_via_scc(get_var('SCC_REGISTER', 0));
        # And done!
        assert_screen 'wsl-installation-completed', 120;
        send_key 'alt-f';
        # Back to CLI
        assert_screen 'wsl-linux-prompt';
    } else {
        #1) skip registration, we cannot register against proxy SCC
        assert_and_click 'window-max';
        assert_screen 'wsl-registration-prompt', 300;
        send_key 'ret';

        #2) enter user credentials
        assert_screen 'wsl-image-setup-enter-username', 120;
        enter_user_details([$username, $password, $password]);
        assert_screen 'wsl-image-setup-use-password-for-root', 120;
        wait_screen_change { type_string 'y' };
        sleep 2;
        send_key 'ret';
        assert_screen 'wsl-image-ready-prompt', 120;
    }

    # Nothing to do in WSL2 pts w/o serialdev support
    # https://github.com/microsoft/WSL/issues/4322
    if (get_var('WSL2')) {
        type_string "exit\n";
        return;
    }

    become_root unless (get_var('BETA', 0) && is_sut_reg());

    assert_script_run 'cd ~';
    if (script_run "zypper ps") {
        record_soft_failure 'bsc#1170256 - [Build 3.136] zypper ps is missing lsof package';
    }
    type_string "exit\n";
    sleep 3;
    save_screenshot;
    type_string "exit\n" unless (get_var('BETA', 0) && is_sut_reg());
}

sub post_fail_hook {
    assert_screen 'yast2-wsl-active';
    # function keys are not encoded in consoles/VNC.pm
    send_key 'alt-q';
    wait_still_screen stilltime => 5, timeout => 35;
    send_key 'alt-r';
    assert_screen 'wsl-firsboot-exit-warning-pop-up';
    send_key 'alt-a';
    assert_screen 'wsl-installing-prompt';
    wait_still_screen stilltime => 2, timeout => 11;
    script_run 'save_y2logs wsl-fb.tar.xz';
    upload_logs '/root/wsl-fb.tar.xz';
}

1;
