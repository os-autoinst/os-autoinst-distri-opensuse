# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
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
use utils 'ensure_fullscreen';
use version_utils qw(is_sle sle_version_at_least is_staging);

sub run {
    my ($self) = @_;
    my $iterations;

    my @welcome_tags = ('inst-welcome-confirm-self-update-server', 'scc-invalid-url');
    my $expect_beta_warn = get_var('BETA');
    if ($expect_beta_warn) {
        push @welcome_tags, 'inst-betawarning';
    }
    else {
        push @welcome_tags, 'inst-welcome';
    }
    # Add tag for soft-failure on SLE 15
    push @welcome_tags, 'no-product-found-on-scc' if sle_version_at_least('15');
    # Add tag for untrusted-ca-cert with SMT
    push @welcome_tags, 'untrusted-ca-cert' if get_var('SMT_URL');
    # Add tag for sle15 upgrade mode, where product list should NOT be shown
    push @welcome_tags, 'inst-welcome-no-product-list' if sle_version_at_least('15') and get_var('UPGRADE');
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
        if (match_has_tag 'inst-betawarning' || match_has_tag 'inst-welcome' || match_has_tag 'inst-welcome-no-product-list') {
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
        if (match_has_tag 'no-product-found-on-scc') {
            record_soft_failure 'bsc#1056413';
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
    if (is_sle('15+')) {
        # On s390x there will be only one product which means there is no product selection
        # In upgrade mode, there is no product list shown in welcome screen
        unless (check_var('ARCH', 's390x') || get_var('UPGRADE')) {
            assert_screen('select-product');
            my $product = get_required_var('SLE_PRODUCT');
            if (check_var('VIDEOMODE', 'text')) {
                my %hotkey = (
                    sles     => 's',
                    sled     => 'u',
                    sles4sap => get_var('OFW') ? 'u' : 'i',
                    hpc      => check_var('ARCH', 'x86_64') ? 'x' : 'u'
                );
                send_key 'alt-' . $hotkey{$product};
            }
            else {
                assert_and_click('before-select-product-' . $product);
            }
            assert_screen('select-product-' . $product);
        }
    }
    else {
        $self->verify_license_has_to_be_accepted;
    }

    assert_screen 'languagepicked';
    $self->verify_license_translations unless is_sle('15+');
}

1;
