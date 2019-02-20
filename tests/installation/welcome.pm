# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wait for installer welcome screen. Covers loading linuxrc
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use x11utils 'ensure_fullscreen';
use version_utils qw(:VERSION :SCENARIO);
use Utils::Backends 'is_remote_backend';

sub switch_keyboard_layout {
    record_info 'keyboard layout', 'Check keyboard layout switching to another language';
    my $keyboard_layout = get_var('INSTALL_KEYBOARD_LAYOUT');
    # for instance, select france and test "querty"
    send_key 'alt-k';    # Keyboard Layout
    send_key_until_needlematch("keyboard-layout-$keyboard_layout", 'down', 60);
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
    send_key_until_needlematch("keyboard-layout", 'up', 60);
    wait_screen_change { send_key 'ret' } if (check_var('DESKTOP', 'textmode'));
}

=head2 get_product_shortcuts

  get_product_shortcuts();

Returns hash which contains shortcuts for the product selection.
=cut
sub get_product_shortcuts {
    # We got new products in SLE 15 SP1
    if (is_sle '15-SP1+') {
        return (
            sles     => (get_var('OFW') || is_s390x) ? 'u' : 'i',
            sled     => 'x',
            sles4sap => get_var('OFW') ? 'i' : 'p',
            hpc      => is_x86_64() ? 'g' : 'u',
            rt       => is_x86_64() ? 't' : undef
        );
    }
    # Else return old shortcuts
    return (
        sles     => 's',
        sled     => 'u',
        sles4sap => get_var('OFW') ? 'u' : 'x',
        hpc      => is_x86_64() ? 'x' : 'u',
        rt       => is_x86_64() ? 'u' : undef
    );
}

sub run {
    my ($self) = @_;
    my $iterations;

    my @welcome_tags     = ('inst-welcome-confirm-self-update-server', 'scc-invalid-url');
    my $expect_beta_warn = get_var('BETA');
    if ($expect_beta_warn) {
        push @welcome_tags, 'inst-betawarning';
    }
    else {
        push @welcome_tags, 'inst-welcome';
    }
    # Add tag for untrusted-ca-cert with SMT
    push @welcome_tags, 'untrusted-ca-cert' if get_var('SMT_URL');
    # Add tag for sle15 upgrade mode, where product list should NOT be shown
    push @welcome_tags, 'inst-welcome-no-product-list' if is_sle('15+') and get_var('UPGRADE');
    # Add tag to check for https://progress.opensuse.org/issues/30823 "test is
    # stuck in linuxrc asking if dhcp should be used"
    push @welcome_tags, 'linuxrc-dhcp-question';
    ensure_fullscreen;

    # Process expected pop-up windows and exit when welcome/beta_war is shown or too many iterations
    while ($iterations++ < scalar(@welcome_tags)) {
        # See poo#19832, sometimes manage to match same tag twice and test fails due to broken sequence
        wait_still_screen 5;
        assert_screen(\@welcome_tags, 500);
        # Normal exit condition
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
            send_key 'ret';
        }
    }

    # Process beta warning if expected
    if ($expect_beta_warn) {
        assert_screen 'inst-betawarning';
        wait_screen_change { send_key 'ret' };
    }
    assert_screen((is_sle('15+') && get_var('UPGRADE')) ? 'inst-welcome-no-product-list' : 'inst-welcome');
    mouse_hide;
    wait_still_screen(3);

    # license+lang +product (on sle15)
    # On sle 15 license is on different screen, here select the product
    if (has_product_selection) {
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
    # Accept the License on installations where License Agreement is shown on Welcome screen.
    elsif (has_license_on_welcome_screen) {
        if (get_var('INSTALLER_EXTENDED_TEST')) {
            $self->verify_license_has_to_be_accepted;
            $self->verify_license_translations unless is_sle('15+');
        }
        $self->accept_license;
    }

    # Verify install arguments passed by bootloader
    # Linuxrc writes its settings in /etc/install.inf
    if (!is_remote_backend && get_var('VALIDATE_INST_SRC')) {
        wait_screen_change { send_key 'ctrl-alt-shift-x' };
        my $method     = uc get_required_var('INSTALL_SOURCE');
        my $mirror_src = get_required_var("MIRROR_$method");
        my $rc         = script_run 'grep -o --color=always install=' . $mirror_src . ' /proc/cmdline';
        die "Install source mismatch in boot parameters!\n" unless ($rc == 0);
        $rc = script_run "grep --color=always -e \"^RepoURL: $mirror_src\" -e \"^ZyppRepoURL: $mirror_src\" /etc/install.inf";
        die "Install source mismatch in linuxrc settings!\n" unless ($rc == 0);
        wait_screen_change { send_key 'ctrl-d' };
        save_screenshot;
    }

    switch_keyboard_layout if get_var('INSTALL_KEYBOARD_LAYOUT');
    send_key $cmd{next};
}

1;
