# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Wait for installer welcome screen. Covers loading linuxrc
# - Check if system is on installer environment
# - Goes through install steps (welcome screen, product lists, beta warning,
# dhcp confirmation)
# - If scc url error is found, try to type one from "$SCC_URL_VALID" system variable
# - Handle self update server and untrusted ca warnings
# - Handle dhcp question
# - Handle beta warnings
# - Check product selection
# - Go to console and check bootloader parameters, checking /proc/cmdline and /etc/install.inf
# - Save screenshot
# - If necessary, change keyboard layout
# - Proceed install (Next, next) until license on welcome screen is found
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use y2_logs_helper qw(accept_license verify_license_translations verify_license_has_to_be_accepted);
use testapi;
use x11utils 'ensure_fullscreen';
use version_utils qw(:VERSION :SCENARIO);
use Utils::Backends 'is_remote_backend';
use Utils::Architectures;

sub switch_keyboard_layout {
    record_info 'keyboard layout', 'Check keyboard layout switching to another language';
    my $keyboard_layout = get_var('INSTALL_KEYBOARD_LAYOUT');
    # for instance, select france and test "querty"
    send_key 'alt-k';    # Keyboard Layout
    send_key_until_needlematch("keyboard-layout-$keyboard_layout", 'down', 61);
    if (check_var('DESKTOP', 'textmode')) {
        send_key 'ret';
        assert_screen "keyboard-layout-$keyboard_layout-selected";
        send_key 'alt-e';    # Keyboard Test in text mode
    }
    else {
        send_key 'alt-y';    # Keyboard Test in graphic mode
    }
    type_string "azerty";
    assert_screen "keyboard-test-$keyboard_layout";
    # Select back default keyboard layout
    send_key 'alt-k';
    send_key_until_needlematch("keyboard-layout", 'up', 61);
    wait_screen_change { send_key 'ret' } if (check_var('DESKTOP', 'textmode'));
}

=head2 get_product_shortcuts

  get_product_shortcuts();

Returns hash which contains shortcuts for the product selection.
=cut
sub get_product_shortcuts {
    # sles4sap does have different shortcuts in different tests at same time
    #               ppc64le x86_64
    # Full              u      i
    # Full (15-SP5)     i      t
    # QR                i      p
    # Online            i      t
    if (check_var('SLE_PRODUCT', 'sles4sap')) {
        return (sles4sap => is_ppc64le() ? 'i' : 't') if get_var('ISO') =~ /Full/ && is_sle('15-SP5+');
        return (sles4sap => is_ppc64le() ? 'u' : 'i') if get_var('ISO') =~ /Full/;
        return (sles4sap => is_ppc64le() ? 'i' : is_quarterly_iso() ? 'p' : 't') unless get_var('ISO') =~ /Full/;
    }
    # We got new products in SLE 15 SP1
    elsif (is_sle '15-SP1+') {
        # sles does have different shortcuts in different tests at same time
        #                x86_64
        # Full              i
        # Full (15-SP4)     s
        return (sles => 's') if (get_var('ISO') =~ /Full/ && is_ppc64le() && get_var('NTLM_AUTH_INSTALL'));
        return (
            sles => (is_ppc64le() || is_s390x()) ? 'u'
            : is_aarch64() ? 's'
            : ((is_sle '=15-SP4') && (get_var('ISO') =~ /Full/)) ? 'i'
            : (is_sle '=15-SP5') ? 's' : 'i',
            sled => 'x',
            hpc => is_x86_64() ? 'g' : 'u',
            rt => is_x86_64() ? 't' : undef
        );
    }
    # Else return old shortcuts
    return (
        sles => 's',
        sled => 'u',
        sles4sap => is_ppc64le() ? 'u' : 'x',
        hpc => is_x86_64() ? 'x' : 'u',
        rt => is_x86_64() ? 'u' : undef
    );
}

sub run {
    my ($self) = @_;
    my $iterations;
    my @welcome_tags = ('inst-welcome-confirm-self-update-server', 'scc-invalid-url');
    push @welcome_tags, 'local-registration-server' if get_var('SLP_RMT_INSTALL');
    my $expect_beta_warn = get_var('BETA');
    if ($expect_beta_warn) {
        push @welcome_tags, 'inst-betawarning';
    }
    else {
        push @welcome_tags, 'inst-welcome';
    }
    # Add tag for untrusted-ca-cert with SMT
    push @welcome_tags, 'untrusted-ca-cert' if (get_var('SMT_URL') || get_var('SLP_RMT_INSTALL'));
    # Add tag for sle15 upgrade mode, where product list should NOT be shown
    push @welcome_tags, 'inst-welcome-no-product-list' if (is_sle('15+') and get_var('UPGRADE') || is_sle_micro);
    # Add tag to check for https://progress.opensuse.org/issues/30823 "test is
    # stuck in linuxrc asking if dhcp should be used"
    push @welcome_tags, 'linuxrc-dhcp-question';
    if (is_sle('=15')) {
        record_info('bsc#1179654', 'Needs at least libzypp-17.4.0 to avoid validation check failed');
        push @welcome_tags, 'expired-gpg-key';
    }

    # Process expected pop-up windows and exit when welcome/beta_war is shown or too many iterations
    while ($iterations++ < scalar(@welcome_tags)) {
        # See poo#19832, sometimes manage to match same tag twice and test fails due to broken sequence
        wait_still_screen 5;
        my $timeout = is_aarch64 ? '1000' : '500';
        assert_screen(\@welcome_tags, $timeout);
        # Normal exit condition
        if (match_has_tag 'local-registration-server') {
            if (is_sle('15+')) {
                send_key 'alt-h';
            } else {
                send_key 'alt-r';
            }
            wait_still_screen 5;
            send_key 'alt-o';
            wait_still_screen 5;
            save_screenshot;
        }
        if ((match_has_tag 'inst-betawarning') || (match_has_tag 'inst-welcome') || (match_has_tag 'inst-welcome-no-product-list')) {
            last;
        }
        if (match_has_tag 'scc-invalid-url') {
            die 'SCC reg URL is invalid' if !get_var('SCC_URL_VALID');
            send_key 'alt-r';    # registration URL field
            send_key_until_needlematch 'scc-invalid-url-deleted', 'backspace';
            type_string get_var('SCC_URL_VALID');
            wait_still_screen 2;
            # Press Ok to confirm scc url
            wait_screen_change { send_key 'alt-o' };
            next;
        }
        if (match_has_tag 'inst-welcome-confirm-self-update-server') {
            wait_screen_change { send_key $cmd{ok} };
            next;
        }
        if (match_has_tag('untrusted-ca-cert')) {
            send_key 'alt-t';
            wait_still_screen 5;
            next;
        }
        if (match_has_tag 'linuxrc-dhcp-question') {
            send_key 'tab' if (match_has_tag 'linuxrc-dhcp-question-no');
            send_key 'ret';
        }
        if (match_has_tag 'expired-gpg-key') {
            send_key 'alt-y';
        }
    }

    # Process beta warning if expected
    if ($expect_beta_warn) {
        assert_screen 'inst-betawarning';
        wait_screen_change { send_key 'ret' };
    }

    ensure_fullscreen;

    if (is_sle('15+') && get_var('UPGRADE')) {
        assert_screen('inst-welcome-no-product-list');
    }
    else {
        assert_screen('inst-welcome');
    }

    my $has_license_on_welcome_screen = (is_sle() || is_sle_micro()) &&
      match_has_tag('license-agreement');
    my $has_product_selection = (is_sle() || is_sle_micro()) &&
      !match_has_tag('inst-welcome-no-product-list');

    mouse_hide;
    wait_still_screen(3);


    # license+lang +product (on sle15)
    # On sle 15 license is on different screen, here select the product
    if ($has_product_selection) {
        assert_screen('select-product');
        my $product = get_required_var('SLE_PRODUCT');
        if (check_var('VIDEOMODE', 'text')) {
            my %hotkey = get_product_shortcuts();
            die "No shortcut for the \"$product\" product specified." unless $hotkey{$product};
            send_key 'alt-' . $hotkey{$product};
        }
        else {
            assert_and_click('before-select-product-' . $product);
        }
        assert_screen('select-product-' . $product);
    }
    # Verify install arguments passed by bootloader
    # Linuxrc writes its settings in /etc/install.inf
    if (!is_remote_backend && get_var('VALIDATE_INST_SRC')) {
        # Ensure to have the focus in some non-selectable control, i.e.: Keyboard Test
        # before switching to console during installation
        wait_screen_change { send_key 'alt-y' };
        wait_screen_change { send_key 'ctrl-alt-shift-x' };
        my $method = uc get_required_var('INSTALL_SOURCE');
        my $mirror_src = get_required_var("MIRROR_$method");
        my $rc = script_run 'grep -o --color=always install=' . $mirror_src . ' /proc/cmdline';
        die "Install source mismatch in boot parameters!\n" unless ($rc == 0);
        $rc = script_run "grep --color=always -e \"^RepoURL: $mirror_src\" -e \"^ZyppRepoURL: $mirror_src\" /etc/install.inf";
        die "Install source mismatch in linuxrc settings!\n" unless ($rc == 0);
        wait_screen_change { send_key 'ctrl-d' };
        save_screenshot;
    }

    switch_keyboard_layout if get_var('INSTALL_KEYBOARD_LAYOUT');
    send_key $cmd{next} unless $has_license_on_welcome_screen;

    if ($has_license_on_welcome_screen || $has_product_selection) {
        assert_screen('license-agreement', 120);

        # optional checks for the extended installation
        if (get_var('INSTALLER_EXTENDED_TEST')) {
            $self->verify_license_has_to_be_accepted;
            $self->verify_license_translations;
        }

        $self->accept_license;
        send_key $cmd{next};
    }
}

1;
