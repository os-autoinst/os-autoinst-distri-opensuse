# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: gather info about installed/removed packages during the test
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

use Utils::Logging;
use Mojo::JSON qw(to_json);

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    my $zypper_packages = {};
    $zypper_packages->{commands} = $testapi::distri->{zypper_packages} // [];
    my $individual_pkgs = script_output('grep "|\(Installing:\|Removing\) .*} END" /var/log/zypper.log', proceed_on_failure => 1);
    # this looks like this:
    # 2022-08-05 12:18:55 <1> athene(13626) [Progress++] progressdata.cc(report):89 {#24|Installing: xosview-1.22-1.10.x86_64} END
    # 2022-08-05 12:19:48 <1> athene(13993) [Progress++] progressdata.cc(report):89 {#21|Removing xosview-1.22-1.10.x86_64} END
    $zypper_packages->{individual_pkgs} = [];
    while ($individual_pkgs =~ m/\|([A-Z][a-z]*):? ([^}]*)}/g) {
        my $action;
        if ($1 eq "Installing") { $action = "install"; }
        elsif ($1 eq "Removing") { $action = "remove"; }
        $2 =~ m/(.+)-([^-]+)-([^-]+)\.([^.]+)/;
        push(@{$zypper_packages->{individual_pkgs}}, {
                action => $action,
                package => $1,
                version => $2,
                release => $3,
                arch => $4,
        });
    }

    save_ulog(to_json($zypper_packages), "zypper_packages.json");
    record_info('zypper_packages.json', "zypper_packages.json was saved via worker", result => 'ok');
}

1;
