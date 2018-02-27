# Copyright (C) 2017-2018 SUSE LLC
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
use qam qw/remove_test_repositories/;
use version_utils qw(sle_version_at_least is_sle);

our @EXPORT = qw(
  setup_migration
  register_system_in_textmode
  remove_ltss
  disable_installation_repos
  record_disk_info
);

sub setup_migration {
    my ($self) = @_;
    select_console 'root-console';

    # stop packagekit service
    # Systemd is not available on SLE11
    # skip this part if the version below SLE12
    if (is_sle && sle_version_at_least('12')) {
        systemctl 'mask packagekit.service';
        systemctl 'stop packagekit.service';
    }
    else {
        assert_script_run "chmod 444 /usr/sbin/packagekitd";
    }

    ensure_serialdev_permissions;

    # enable Y2DEBUG all time
    type_string "echo 'export Y2DEBUG=1' >> /etc/bash.bashrc.local\n";
    script_run "source /etc/bash.bashrc.local";

    # remove the PATCH test_repos
    remove_test_repositories();
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

# Record disk info to help debug diskspace exhausted
# issue during upgrade
sub record_disk_info {
    if (get_var('FILESYSTEM', 'btrfs') =~ /btrfs/) {
        assert_script_run 'btrfs filesystem df / | tee /tmp/btrfs-filesystem-df.txt';
        assert_script_run 'btrfs filesystem usage / | tee /tmp/btrfs-filesystem-usage.txt';
        assert_script_run 'snapper list | tee /tmp/snapper-list.txt';
        upload_logs '/tmp/btrfs-filesystem-df.txt';
        upload_logs '/tmp/btrfs-filesystem-usage.txt';
        upload_logs '/tmp/snapper-list.txt';
    }
    assert_script_run 'df -h > /tmp/df.txt';
    upload_logs '/tmp/df.txt';
}
1;
# vim: sw=4 et
