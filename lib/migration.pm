# Copyright (C) 2017 SUSE Linux GmbH
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

package migration;

use base Exporter;
use Exporter;

use strict;

use testapi;
use utils;
use registration;

our @EXPORT = qw(
  setup_online_migration
  register_system_in_textmode
  de_register
  remove_ltss
  disable_installation_repos
);

sub setup_online_migration {
    my ($self) = @_;
    # if source system is minimal installation then boot to textmode
    # we don't care about source system start time because our SUT is upgraded one
    $self->wait_boot(textmode => !is_desktop_installed, ready_time => 600);
    select_console 'root-console';

    # stop packagekit service
    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";

    type_string "chown $username /dev/$serialdev\n";

    # enable Y2DEBUG all time
    type_string "echo 'export Y2DEBUG=1' >> /etc/bash.bashrc.local\n";
    script_run "source /etc/bash.bashrc.local";

    save_screenshot;
}

sub register_system_in_textmode {
    # SCC_URL was placed to medium types
    # so set SMT_URL here if register system via smt server
    # otherwise must register system via real SCC before online migration
    if (my $u = get_var('SMT_URL')) {
        type_string "echo 'url: $u' > /etc/SUSEConnect\n";
    }

    # register system and addons in textmode for all archs
    set_var("VIDEOMODE", 'text');
    if (sle_version_at_least('12-SP2', version_variable => 'HDDVERSION')) {
        set_var('HDD_SP2ORLATER', 1);
    }
    yast_scc_registration;
}

sub de_register {
    my (%args) = @_;
    $args{version_variable} //= 'VERSION';
    if (sle_version_at_least('12-SP1', version_variable => $args{version_variable})) {
        assert_script_run('SUSEConnect -d --cleanup');
        my $output = script_output 'SUSEConnect -s';
        die "System is still registered" unless $output =~ /Not Registered/;
        save_screenshot;
    }
    else {
        assert_script_run("zypper removeservice `zypper services --show-enabled-only --sort-by-name | awk {'print\$5'} | sed -n '1,2!p'`");
        assert_script_run('rm /etc/zypp/credentials.d/* /etc/SUSEConnect');
        my $output = script_output 'SUSEConnect -s';
        die "System is still registered" unless $output =~ /Not Registered/;
        save_screenshot;
    }
}

# Remove LTSS product and manually remove its relevant package before migration
sub remove_ltss {
    if (get_var('SCC_ADDONS', '') =~ /ltss/) {
        zypper_call 'rm -t product SLES-LTSS';
        zypper_call 'rm sles-ltss-release-POOL';
    }
}

# Disable installation repos before online migration
# s390x: use ftp remote repos as installation repos
# Other archs: use local DVDs as installation repos
sub disable_installation_repos {
    if (check_var('ARCH', 's390x')) {
        zypper_call "mr -d `zypper lr -u | awk '/ftp:.*?openqa.suse.de/ {print \$1}'`";
    }
    else {
        zypper_call "mr -d -l";
    }
}

1;
# vim: sw=4 et
