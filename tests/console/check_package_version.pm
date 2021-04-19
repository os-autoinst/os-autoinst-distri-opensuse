# Copyright (C)2019-2020 SUSE LLC
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
# Summary: Compare package version with its expected version for SLE15SP3.
# Maintainer: Yutao Wang <yuwang@suse.com>

use base "basetest";
use strict;
use warnings;
use version;
use testapi;
use utils qw(systemctl zypper_call);
use Mojo::Util 'trim';

my %package = (
    postgresql13 => '13.0.0',
    python39     => '3.9.0',
    python3      => '3.6.0',
    mariadb      => '10.0.0'
);

my %locpak = (
    postgresql12 => "SLE-Module-Legacy"
);

sub cmp_version {
    my ($old, $new) = @_;
    my @newv = split(qr/-|\+/, $new);
    $newv[0] =~ s/[a-zA-Z]//g;
    my $v1 = version->parse($old);
    my $v2 = version->parse($newv[0]);
    return $v1 <= $v2;
}

sub cmp_packages {
    my ($pcks, $pckv) = @_;
    record_info($pcks, "$pcks version check after migration");
    my $output = script_output("zypper se -xs $pcks | grep -w $pcks | head -1 | awk -F '|' '{print \$4}'", 100, proceed_on_failure => 1);
    my $out    = '';
    for my $line (split(/\r?\n/, $output)) {
        if (trim($line) =~ m/^\d+\.\d+(\.\d+)?/) {
            $out = $line;
            record_info("Package version", "The $pcks version is $out, but request is $pckv", result => 'fail') if (!cmp_version($pckv, $out));
        }
    }
    if ($out eq '') {
        record_info("Package version", "The $pcks is not existed", result => 'fail');
    }
}

sub loc_packages {
    my ($pac, $loc) = @_;
    record_info($pac, "$pac check package location");
    my $output = script_output("zypper se -xs $pac | grep -w $pac | head -1 | awk -F '|' '{print \$6}'", 100, proceed_on_failure => 1);
    diag "location:" . $output;
    record_info("Location", "$loc doesn't have package $pac", result => 'fail') if ($output !~ /$loc/);
}

sub run {

    select_console 'root-console';

    foreach my $key (keys %package) {
        my $pcks = cmp_packages($key, $package{$key});
    }

    foreach my $key (keys %locpak) {
        loc_packages($key, $locpak{$key});
    }

}

sub test_flags {
    return {fatal => 0};
}

1;
