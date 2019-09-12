# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Check package version only for sles12sp5 migration scenarios
# Maintainer: Yutao Wang <yuwang@suse.com>

use base "basetest";
use strict;
use warnings;
use version;
use testapi;
use utils qw(systemctl zypper_call);

my %package = (
    autofs              => ['5.1.5',   'jsc#5754'],
    openscap            => ['1.3.0',   'jsc#5699'],
    augeas              => ['1.0.0',   'jsc#5739'],
    'freeradius-server' => ['3.0.18',  'jsc#5892'],
    gpgme               => ['1.9.0',   'jsc#5953'],
    'libgpg-error'      => ['1.17',    'jsc#5953'],
    rsync               => ['3.1.3',   'jsc#5584'],
    dpdk                => ['18.11.2', 'jsc#6820'],
    python36            => ['3.6.0',   'jsc#7100'],
    'python-daemon'     => ['1.6',     'jsc#5708']
);

my %package_s390x = (
    'libnuma-devel' => ['2.0.12', 'jsc#6508'],
);

sub cmp_version {
    my ($old, $new) = @_;
    my @newv = split(/-/, $new);
    my $v1   = version->parse($old);
    my $v2   = version->parse($newv[0]);
    return $v1 <= $v2;
}

sub cmp_packages {
    my ($pcks, $pckv, $jsc) = @_;
    record_info($pcks, "$pcks version check after migration");
    my $output = script_output("zypper se -s $pcks | grep -w $pcks | head -1 | awk -F '|' '{print \$4}'", proceed_on_failure => 1, 100);
    record_soft_failure("$jsc, The $pcks is not existed") if ($output eq '');
    record_soft_failure("$jsc, The $pcks version is $output, but request is $pckv") if ($output ne '' and !cmp_version($pckv, $output));
}

sub run {

    select_console 'root-console';

    foreach my $key (keys %package) {
        my $pcks = cmp_packages($key, $package{$key}[0], $package{$key}[1]);
    }

    # Those modules only can be installed at s390x
    if (get_var('ARCH') =~ /s390x/) {
        foreach my $key (keys %package_s390x) {
            my $pcks = cmp_packages($key, $package_s390x{$key}[0], $package_s390x{$key}[1]);
        }
    }

    # jsc#5668:Replace init script of ebtables with systemd service file
    zypper_call('in ebtables');
    systemctl 'start ebtables';
    systemctl 'is-active ebtables';
}

sub test_flags {
    return {fatal => 0};
}

1;
