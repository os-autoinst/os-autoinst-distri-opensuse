# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: openSUSE specific part of upgrade_select
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use strict;
use base "y2logsstep";
use testapi;

# Check that installer does not freeze when pressing next
sub check_bsc997635 {
    my $ret = wait_screen_change(sub { send_key $cmd{next}; }, 10);
    if (!$ret) {
        record_soft_failure 'bsc#997635';
        sleep 30;
    }
}

sub handle_beta_warning {
    if (!get_var("BETA")) {
        die "Beta warning in non beta product";
    }
    send_key 'alt-o';
}

sub run {
    # offline DVD upgrade may not have network (boo#995771)
    if (!check_var("FLAVOR", "NET") && check_screen('network-not-configured', 30)) {
        send_key $cmd{next};
        assert_screen('ERROR-cannot-download-repositories');
        send_key 'alt-o';
    }
    else {
        assert_screen('list-of-online-repositories', 10);
        send_key $cmd{next};

        if (check_screen('inst-betawarning', 30)) {
            handle_beta_warning;
        }
        elsif (get_var("BETA")) {
            die 'missing beta warning even though BETA is set';
        }
        # Bug 881107 - there is 2nd license agreement screen in openSUSE upgrade
        # http://bugzilla.opensuse.org/show_bug.cgi?id=881107
        if (check_screen('upgrade-license-agreement', 30)) {
            check_bsc997635;
        }
    }

    if (check_screen(["installed-product-incompatible", "inst-betawarning"], 10)) {
        if (match_has_tag 'installed-product-incompatible') {
            record_info 'installed product incompatible', result => 'fail';
            send_key 'alt-o';
        }
        else {
            handle_beta_warning;
        }
    }

    assert_screen "update-installation-overview", 60;
}

1;
