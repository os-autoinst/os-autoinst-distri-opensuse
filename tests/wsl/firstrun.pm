# SUSE's openQA tests
#
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure WSL users
# Maintainer: qa-c  <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi;
use utils qw(enter_cmd_slow);
use version_utils qw(is_sle);
use wsl qw(is_sut_reg is_fake_scc_url_needed);

sub set_fake_scc_url {
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
        assert_screen(['wsl-license-not-accepted', 'wsl-sled-license-not-accepted']);
        if (match_has_tag 'wsl-license-not-accepted') {
            send_key 'ret';
        }
        else {
            # When activating SLED, license agreement for workstation module appears,
            # and this time the popup shows Yes or No options
            send_key 'alt-n';
        }
        # Accept license
        assert_screen 'wsl-license';
        send_key 'alt-a';
        assert_screen 'license-accepted';
        send_key 'alt-n';
    }
}

sub register_via_scc {
    assert_screen 'wsl-registration', 120;

    unless (is_sut_reg) {
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
    if (is_sle('>=15-SP5')) {
        assert_screen 'trust_nvidia_gpg_keys', timeout => 240;
        send_key 'alt-t';
    }
    assert_screen 'wsl-registration-repository-offer', timeout => 240;
    send_key 'alt-y';
    assert_screen 'wsl-extension-module-selection';
    send_key 'alt-n';
}

sub wsl_gui_pattern {
    assert_screen 'wsl-gui-pattern';
    if (is_sut_reg) {
        # Select product SLED if SLE_PRODUCT var is provided
        send_key_until_needlematch('wsl_sled_install', 'alt-u') if (check_var('SLE_PRODUCT', 'sled'));
        # Install wsl_gui pattern if WSL_GUI var is provided
        send_key_until_needlematch('wsl_gui-pattern-install', 'alt-i') if (get_var('WSL_GUI'));
    }
    send_key 'alt-n';
}

sub run {
    # WSL installation is in progress
    assert_screen [qw(yast2-wsl-firstboot-welcome wsl-installing-prompt)], 480;

    if (match_has_tag 'yast2-wsl-firstboot-welcome') {
        assert_and_click 'window-max';
        wait_still_screen stilltime => 3, timeout => 10;
        is_fake_scc_url_needed && set_fake_scc_url();
        send_key 'alt-n';
        # License handling
        license;
        # User credentials
        assert_screen 'local-user-credentials';
        enter_user_details([$realname, undef, $password, $password]);
        send_key 'alt-n';
        # wsl-gui pattern installation (only in SLE15-SP4+ by now)
        wsl_gui_pattern if (is_sle('>=15-SP4'));
        # Registration
        is_sle && register_via_scc();
        # SLED Workstation license agreement and trust nVidia GPG keys
        if (check_var('SLE_PRODUCT', 'sled')) {
            license;
            # Nvidia GPG keys screen does not always shows up
            assert_screen ['wsl-installation-completed', 'trust_nvidia_gpg_keys'], timeout => 240;
            send_key 'alt-t' if (match_has_tag 'trust_nvidia_gpg_keys');
        }
        # And done!
        assert_screen 'wsl-installation-completed', 240;
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
        enter_cmd_slow "exit\n";
        return;
    }

    is_fake_scc_url_needed || become_root;
    assert_script_run 'cd ~';
    assert_script_run "zypper ps";
    enter_cmd_slow "exit\n";
    sleep 3;
    save_screenshot;
    is_fake_scc_url_needed || enter_cmd_slow "exit\n";
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
