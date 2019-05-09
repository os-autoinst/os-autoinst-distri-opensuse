# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: prepare migration from Leap to SLE
#   Documentation for 15:
#   https://www.suse.com/de-de/documentation/sles-15/book_sle_upgrade/data/sec_upgrade-online_opensuse_to_sle.html
#   12 is not supported and inoffical
# Maintainer: lemon.li <leli@suse.com>

use base "installbasetest";
use registration qw(scc_version add_suseconnect_product);
use testapi;
use utils 'zypper_call';
use strict;
use warnings;

=head2 is_leap_base

Check for a specific base version of openSUSE Leap
parameters: 
    version : expected leap version, should with prefix of 'opensuse-'.
return 1 if true

=cut
sub is_leap_base {
    my $version = shift;
    return (get_var('HDDVERSION', '') =~ /opensuse-$version/);
}

sub run {
    my $reg_code   = get_required_var('SCC_REGCODE');
    my $scc_url    = get_required_var('SCC_URL');
    my $scc_addons = get_var('SCC_ADDONS', '');
    my $arch       = get_required_var("ARCH");
    my $version    = scc_version(get_var('VERSION', ''));

    # so if we are migrating from Leap to SLE we just make SUSEConnect believe
    # we are on SLE
    my $hddversion = get_var('HDDVERSION', '');

    select_console 'root-console';

    # make sure we have SUSEConnect and the right build key
    zypper_call "in SUSEConnect";
    # Remove packages that produce file conflicts during the migration.
    script_run "rpm -e --nodeps yast2-qt-branding-openSUSE";
    # suse build key conflicts with openSUSE-build-key. We can't uninstall
    # openSUSE-build-key though as patterns need it :(
    # should be only needed on 42.*
    if (is_leap_base('42')) {
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
    add_suseconnect_product("SLES", $version, $arch, "--regcode $reg_code");

    # restore product, bug in 42
    if (is_leap_base('42')) {
        assert_script_run("ln -s SLES.prod /etc/products.d/baseproduct");
    }

    # just for the fun of it here
    script_run("SUSEConnect --list-extensions");
    # add the modules needed for installation
    if (is_leap_base('15')) {
        my @need_modules = ('sle-module-basesystem', 'sle-module-server-applications', 'sle-module-desktop-applications', 'sle-module-legacy', 'PackageHub');
        for my $module (@need_modules) {
            add_suseconnect_product($module);
        }
    }

    # remove some known file conflicts in 42.* to avoid dup complaining later
    if (is_leap_base('42')) {
        assert_script_run("rpm -e --nodeps libmtp-udev libmtp9 libtheoradec1 libtheoraenc1");
        # in 42 gawk comes from Factory and uses update-alternatives.
        # Downgrading to the one from SLE breaks the awk link which in turn
        # breaks rpm %post scripts, like grub. So we have to forcibly fix
        # gawk here.
        zypper_call("in -f gawk");

        # SLE12 failed to use a better console font
        assert_script_run("sed -i -e 's/eurlatgr/lat9w-16/' /etc/sysconfig/console");
    }
}

1;
