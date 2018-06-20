# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: common parts on SMT and RMT
# Maintainer: Dehai Kong <dhkong@suse.com> Jaiwei Sun <jwsun@suse.com>

package repo_tools;

use base Exporter;
use Exporter;
use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

our @EXPORT = qw (smt_wizard smt_mirror_repo rmt_wizard rmt_mirror_repo prepare_source_repo);

sub smt_wizard {
    type_string "yast2 smt-wizard;echo yast2-smt-wizard-\$? > /dev/$serialdev\n";
    assert_screen 'smt-wizard-1';
    send_key 'alt-u';
    wait_still_screen;
    type_string(get_required_var('SMT_ORG_NAME'));
    send_key 'alt-p';
    wait_still_screen;
    type_string(get_required_var('SMT_ORG_PASSWORD'));
    send_key 'alt-n';
    assert_screen 'smt-wizard-2';
    send_key 'alt-d';
    wait_still_screen;
    type_password;
    send_key 'tab';
    type_password;
    send_key 'alt-n';
    assert_screen 'smt-mariadb-password', 60;
    type_password;
    send_key 'tab';
    type_password;
    send_key 'alt-o';
    assert_screen 'smt-server-cert';
    send_key 'alt-r';
    assert_screen 'smt-CA-password';
    send_key 'alt-p';
    wait_still_screen;
    type_password;
    send_key 'tab';
    type_password;
    send_key 'alt-o';
    assert_screen 'smt-installation-overview';
    send_key 'alt-n';
    if (check_var("SMT", "internal")) {
        assert_screen 'smt-sync-failed', 100;    # expect fail because there is no network
        send_key 'alt-o';
    }
    wait_serial("yast2-smt-wizard-0", 800) || die 'smt wizard failed, it can be connection issue or credential issue';
}

sub smt_mirror_repo {
    # Verify smt mirror function and mirror a tiny released repo from SCC. Hardcode it as SLES12-SP3-Installer-Updates
    assert_script_run 'smt-repos --enable-mirror SLES12-SP3-Installer-Updates sle-12-x86_64';
    save_screenshot;
    assert_script_run 'smt-mirror', 600;
    save_screenshot;
}

sub rmt_wizard {
    my $SCC_Password = get_var('SCC_PWD');
    my $SCC_User     = get_var('SCC_USER');

    # install RMT and mariadb
    zypper_call 'in rmt-server';
    zypper_call 'in mariadb';

    # check mysql status and config mysql for RMT
    systemctl 'start mysql.service';
    systemctl 'status mysql.service';
    my $cmd = 'mysql -u root -p <<EOFF
GRANT ALL PRIVILEGES ON \`rmt\`.* TO rmt@localhost IDENTIFIED BY \'rmt\';
FLUSH PRIVILEGES;
EOFF';
    type_string "$cmd\n";
    assert_screen('rmt-sqladmin-password', 40);
    send_key 'ret';

    # Modify rmt config file
    assert_script_run "sed -i '/^[][ ]*username:[][ ]*\$/d' /etc/rmt.conf";
    assert_script_run "sed -i '/^[][ ]*password/d' /etc/rmt.conf";
    assert_script_run "sed -i '/adapter/i\ \\ \\ password: rmt' /etc/rmt.conf";
    assert_script_run "sed -i '/scc/a\ \\ \\ password: $SCC_Password' /etc/rmt.conf";
    assert_script_run "sed -i '/scc/a\ \\ \\ username: $SCC_User' /etc/rmt.conf";

    # Start rmt server
    systemctl 'start rmt';
    systemctl 'status rmt';
}

sub rmt_mirror_repo {
    my $repo_list = get_var('RMT_REPO') || 'sle-module-legacy/15/x86_64';
    assert_script_run 'rmt-cli sync', 1800;
    for my $repo (split(/,/, $repo_list)) {
        assert_script_run "rmt-cli products enable $repo", 600;
    }
    assert_script_run 'rmt-cli mirror', 1800;
    assert_script_run 'rmt-cli repo list';
}

sub prepare_source_repo {
    my $cmd;
    if (is_sle) {
        if (is_sle('>=15') and get_var('REPO_SLE15_MODULE_BASESYSTEM_SOURCE')) {
            $cmd = "ar -f " . "$utils::OPENQA_FTP_URL/" . get_var('REPO_SLE15_MODULE_BASESYSTEM_SOURCE') . " repo-source";
        }
        elsif (is_sle('>=12-SP4') and get_var('REPO_SLES_SOURCE')) {
            $cmd = "ar -f " . "$utils::OPENQA_FTP_URL/" . get_var('REPO_SLES_SOURCE') . " repo-source";
        }
        # SLE maintenance tests are assumed to be SCC registered
        # and source repositories disabled by default
        elsif (get_var('FLAVOR') =~ /-Updates$|-Incidents$/) {
            $cmd = q{mr -e $(zypper -n lr | awk '/-Source/ {print $1}')};
        }
        # use dvd2 as the src-repository
        # Xen PV has different device for 2nd CDROM
        elsif (check_var('VIRSH_VMM_TYPE', 'linux')) {
            $cmd = 'ar --type plaindir hd:///?device=/dev/xvda repo-source';
        }
        else {
            $cmd = "ar --type plaindir cd:///?devices=/dev/sr1 repo-source";
        }
    }
    # source repository is disabled by default
    else {
        $cmd = "mr -e repo-source";
    }

    zypper_call($cmd);
    zypper_call("ref");
}


sub test_flags {
    return {fatal => 1};
}

1;
