# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: prepare migration from Leap to SLE
#   Documentation for 15:
#   https://www.suse.com/de-de/documentation/sles-15/book_sle_upgrade/data/sec_upgrade-online_opensuse_to_sle.html
#   12 is not supported and inoffical
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "console_yasttest";
use strict;
use testapi;
use utils qw(zypper_call);

sub run {
    my $reg_code   = get_required_var('SCC_REGCODE');
    my $scc_url    = get_required_var('SCC_URL');
    my $scc_addons = get_var('SCC_ADDONS', '');

    # so if we are migrating from Leap to SLE we just make SUSEConnect believe
    # we are on SLE
    my $hddversion = get_var('HDDVERSION', '');
    my $version = get_var('VERSION');
    $version =~ s/-SP/./;    # 12-SP3 -> 12.3
    my $product .= "SLES/$version/" . get_var('ARCH');

    select_console 'root-console';

    # make sure we have SUSEConnect and the right build key
    zypper_call "in SUSEConnect";
    # suse build key conflicts with openSUSE-build-key. We can't uninstall
    # openSUSE-build-key though as patterns need it :(
    # should be only needed on 12
    {
        zypper_call "download suse-build-key";
        assert_script_run "rpm -Uvh --force --nodeps /var/cache/zypp/packages/*/noarch/suse-build-key-*.rpm";
        assert_script_run "rpm --import /usr/lib/rpm/gnupg/keys/*";

        # just for openQA. it expects the firewall to be enabled in the
        # application tests later.
        zypper_call "in SuSEfirewall2";
        assert_script_run "SuSEfirewall2 on";
    }
    # disable the openSUSE repos
    zypper_call('mr -d -a');
    # register!
    script_run "SUSEConnect --url $scc_url -r $reg_code -p $product";
    # forcibly install the product. SUSEConnect cannot do that for us due to conflicts
    zypper_call('in --force-resolution -y -l -t product SLES -openSUSE');

    # restore product, bug in 42
    {
        script_run("ln -s SLES.prod /etc/products.d/baseproduct");
    }

    # just for the fun of it here
    script_run("SUSEConnect --list-extensions");

    # remove some known file conflicts in 12 to avoid dup complaining later
    {
        script_run("rpm -e --nodeps libmtp-udev libmtp9 libtheoradec1 libtheoraenc1");
        # in 42 gawk comes from Factory and uses update-alternatives.
        # Downgrading to the one from SLE breaks the awk link which in turn
        # breaks rpm %post scripts, like grub. So we have to forcibly fix
        # gawk here.
        zypper_call("in -y -f gawk");
        zypper_call("in -y -f gawk");

        # SLE12 failed to use a better console font
        script_run("sed -i -e 's/eurlatgr/lat9w-16/' /etc/sysconfig/console");
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
