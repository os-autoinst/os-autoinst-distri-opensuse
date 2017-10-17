# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
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
use utils qw(ensure_fullscreen sle_version_at_least);
use main_common 'is_staging';

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
    ensure_fullscreen;

    # Process expected pop-up windows and exit when welcome/beta_war is shown or too many iterations
    while ($iterations++ < scalar(@welcome_tags)) {
        # See poo#19832, sometimes manage to match same tag twice and test fails due to broken sequence
        wait_still_screen 5;
        assert_screen(\@welcome_tags, 500);
        # Normal exit condition
        if (match_has_tag 'inst-betawarning' || match_has_tag 'inst-welcome') {
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
    }

    # Process beta warning if expected
    if ($expect_beta_warn) {
        assert_screen 'inst-betawarning';
        wait_screen_change { send_key 'ret' };
    }
    assert_screen 'inst-welcome';
    mouse_hide;
    wait_still_screen(3);

    # license+lang +product (on sle15)
    # On sle 15 license is on different screen, here select the product
    if (sle_version_at_least('15') && check_var('DISTRI', 'sle')) {
        # On s390x there will be only one product which means there is no product selection
        return if check_var('ARCH', 's390x');
        # Missing HPC module on ARM, should be there according to the PRD
        if (check_var('ARCH', 'aarch64')) {
            record_soft_failure 'bsc#1063858';
            return;
        }
        assert_screen('select-product');
        my %hotkey = (
            sles     => 's',
            sled     => 'u',
            sles4sap => 'i',
            hpc      => 'x'
        );
        my $product = get_required_var('SLE_PRODUCT');
        send_key 'alt-' . $hotkey{$product};
        assert_screen('select-product-' . $product);
    }
    else {
        $self->verify_license_has_to_be_accepted;
    }

    assert_screen 'languagepicked';
    send_key $cmd{next};
    if (!check_var('INSTLANG', 'en_US') && check_screen 'langincomplete', 1) {
        send_key 'alt-f';
    }
}

sub post_fail_hook {
    my ($self) = @_;
    # system might be stuck on bootup showing only splash screen so we press
    # esc to show console logs
    send_key 'esc';
    select_console('install-shell');
    # in case we could not even reach the installer welcome screen and logs
    # could not be collected on the serial output:
    $self->save_upload_y2logs;
    $self->get_ip_address;
    upload_logs '/var/log/linuxrc.log';
}

1;
# vim: set sw=4 et:
