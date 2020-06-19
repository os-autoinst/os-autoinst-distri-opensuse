# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: common parts on SMT and RMT
# Maintainer: Lemon Li <leli@suse.com>

=head1 repo_tools

Tools for repositories used by openQA:

=over

=item * add_qa_head_repo

=item * add_qa_web_repo

=item * smt_wizard

=item * smt_mirror_repo

=item * rmt_wizard

=item * rmt_mirror_repo

=item * prepare_source_repo

=item * disable_source_repo

=item * get_repo_var_name

=item * type_password_twice

=item * prepare_oss_repo

=item * disable_oss_repo

=item * generate_version

=back

=cut
package repo_tools;

use base Exporter;
use Exporter;
use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_leap is_sle is_tumbleweed);
use y2_module_consoletest;
use Test::Assert ':all';

our @EXPORT = qw(
  add_qa_head_repo
  add_qa_web_repo
  smt_wizard
  smt_mirror_repo
  rmt_wizard
  rmt_mirror_repo
  prepare_source_repo
  disable_source_repo
  get_repo_var_name
  type_password_twice
  prepare_oss_repo
  disable_oss_repo
  generate_version
  validate_repo_enablement);

=head2 add_qa_head_repo

 add_qa_head_repo();

Helper to add QA:HEAD repository repository (usually from IBS).
This repository *is* mandatory.

=cut
sub add_qa_head_repo {
    my (%args) = @_;
    my $priority = $args{priority} // 0;

    zypper_ar(get_required_var('QA_HEAD_REPO'), name => 'qa-head', priority => $priority, no_gpg_check => is_sle("<12") ? 0 : 1);
}

=head2 add_qa_web_repo

 add_qa_web_repo();

Helper to add QA web repository repository.
This repository is *not* mandatory.

=cut
sub add_qa_web_repo {
    my $repo = get_var('QA_WEB_REPO');
    zypper_ar($repo, name => 'qa-web', no_gpg_check => is_sle("<12") ? 0 : 1) if ($repo);
}

=head2 get_repo_var_name

 get_repo_var_name($repo_name);

This takes something like "MODULE_BASESYSTEM_SOURCE" as parameter C<$repo_name>
and returns "REPO_SLE15_SP1_MODULE_BASESYSTEM_SOURCE" when being called on SLE15-SP1.

=cut
sub get_repo_var_name {
    my ($repo_name) = @_;
    my $distri = uc get_required_var("DISTRI");
    return "REPO_${distri}_${repo_name}";
}

=head2 smt_wizard

 smt_wizard();

Run smt wizard workflow and to get repository synced with smt server

=cut
sub smt_wizard {
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'smt-wizard');
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
    wait_serial("$module_name-0", 800) || die 'smt wizard failed, it can be connection issue or credential issue';
}

=head2 get_repo_var_name

 get_repo_var_name();

Verify smt mirror function and mirror a tiny released repo from SCC. Hardcode it as SLES12-SP3-Installer-Updates.

=cut

sub smt_mirror_repo {
    # Verify smt mirror function and mirror a tiny released repo from SCC. Hardcode it as SLES12-SP3-Installer-Updates
    assert_script_run 'smt-repos --enable-mirror SLES12-SP3-Installer-Updates sle-12-x86_64';
    save_screenshot;
    assert_script_run 'smt-mirror', 600;
    save_screenshot;
}

=head2 type_password_twice

 type_password_twice();

Type password, TAB, password, ALT+o. This is for use within YaST.

=cut
sub type_password_twice {
    type_password;
    send_key "tab";
    type_password;
    send_key "alt-o";
}


=head2 rmt_wazard

rmt_wizard();

Install Repository Mirroring Tool and mariadb database

=cut
sub rmt_wizard {
    # install RMT and mariadb
    zypper_call 'in rmt-server';
    zypper_call 'in mariadb';

    type_string "yast2 rmt;echo yast2-rmt-wizard-\$? > /dev/$serialdev\n";
    assert_screen 'yast2_rmt_registration';
    send_key 'alt-u';
    wait_still_screen;
    type_string(get_required_var('SMT_ORG_NAME'));
    send_key 'alt-p';
    wait_still_screen;
    type_string(get_required_var('SMT_ORG_PASSWORD'));
    send_key 'alt-n';
    assert_screen 'yast2_rmt_config_written_successfully';
    send_key 'alt-o';
    assert_screen 'yast2_rmt_db_password';
    send_key 'alt-p';
    type_string "rmt";
    send_key 'alt-n';
    assert_screen 'yast2_rmt_db_root_password';
    type_password_twice;
    assert_screen 'yast2_rmt_config_written_successfully';
    send_key 'alt-o';
    assert_screen 'yast2_rmt_ssl';
    send_key 'alt-n';
    assert_screen 'yast2_rmt_ssl_CA_password';
    type_password_twice;
    assert_screen 'yast2_rmt_firewall';
    send_key 'alt-o';
    wait_still_screen;
    send_key 'alt-n';
    assert_screen 'yast2_rmt_service_status';
    send_key 'alt-n';
    assert_screen 'yast2_rmt_config_summary';
    send_key 'alt-f';
    wait_serial("yast2-rmt-wizard-0", 800) || die 'rmt wizard failed, it can be connection issue or credential issue';
}

=head2 rmt_mirror_repo

 rmt_mirror_repo();

Function to verify and enable repository mirror

=cut
sub rmt_mirror_repo {
    my $repo_list = get_var('RMT_REPO') || 'sle-module-legacy/15/x86_64';
    assert_script_run 'rmt-cli sync', 1800;
    for my $repo (split(/,/, $repo_list)) {
        assert_script_run "rmt-cli products enable $repo", 600;
    }
    assert_script_run 'rmt-cli mirror', 1800;
    assert_script_run 'rmt-cli repo list';
}

=head2 rmt_import_data

 rmt_import_data($datafile);

RMT server import data about available repositories and the mirrored packages
from disconnected RMT server, then verify imported repositories on new RMT server.
C<$datafile> is repository source.

=cut
sub rmt_import_data {
    my ($datafile) = @_;
    my $datapath = "/mnt/external/";
    # Decompress the RMT data file to test path
    assert_script_run("mkdir -p $datapath");
    assert_script_run("wget -q " . data_url("rmt/$datafile"));
    assert_script_run("tar -xzvf $datafile -C $datapath");
    assert_script_run("rm -rf $datafile");
    # Import RMT data from test path to new RMT server
    assert_script_run("rmt-cli import data $datapath",  600);
    assert_script_run("rmt-cli import repos $datapath", 600);
    # Show repo list on new RMT server for later debugging
    assert_script_run("rmt-cli repos list");
    # Enable repositories as required on new RMT server
    assert_script_run("rmt-cli repos list | grep Web-Scripting");
    assert_script_run("rm -rf $datapath");
}

=head2 prepare_source_repo

 prepare_source_repo($repo_name);

Prepare SLES or OSS souce repositories

=cut
sub prepare_source_repo {
    my $cmd;
    if (is_sle) {
        if (is_sle('>=15') and get_var(get_repo_var_name("MODULE_BASESYSTEM_SOURCE"))) {
            zypper_call("ar -f " . "$utils::OPENQA_FTP_URL/" . get_var(get_repo_var_name("MODULE_BASESYSTEM_SOURCE")) . " repo-source");
        }
        elsif (is_sle('>=12-SP4') and get_var('REPO_SLES_SOURCE')) {
            zypper_call("ar -f " . "$utils::OPENQA_FTP_URL/" . get_var('REPO_SLES_SOURCE') . " repo-source");
        }
        elsif (is_sle('>=12-SP4') and get_var('REPO_SLES_POOL_SOURCE')) {
            zypper_call("ar -f " . "$utils::OPENQA_FTP_URL/" . get_var('REPO_SLES_POOL_SOURCE') . " repo-source");
        }
        # SLE maintenance tests are assumed to be SCC registered
        # and source repositories disabled by default
        elsif (get_var('FLAVOR') =~ /-Updates$|-Incidents$/) {
            zypper_call(q{mr -e $(zypper -n lr | awk '/-Source/ {print $1}')});
        }
        else {
            record_info('No repo', 'Missing source repository');
            die('Missing source repository');
        }
    }
    # source repository is disabled by default
    else {
        # OSS_SOURCE is expected to be added
        if (script_run('zypper lr repo-source') != 0) {
            # re-add the source repo
            my $version = lc get_required_var('VERSION');
            my $repourl;
            # if REPO_OSS_SOURCE is defined - use it, if not fallback to download.opensuse.org
            if (my $repo_basename = get_var("REPO_OSS_SOURCE")) {
                $repourl = get_required_var('MIRROR_PREFIX') . "/" . $repo_basename;
            } else {
                my $source_name = is_tumbleweed() ? $version : 'distribution/leap/' . $version;
                $repourl = "http://download.opensuse.org/source/$source_name/repo/oss";
            }
            zypper_call("ar -f $repourl repo-source");
        }
        else {
            zypper_call("mr -e repo-source");
        }
    }

    zypper_call("ref");
}

=head2 disable_source_repo

 disable_source_repo();

Disable source repositories

=cut
sub disable_source_repo {
    if (is_sle && get_var('FLAVOR') =~ /-Updates$|-Incidents$/) {
        zypper_call(q{mr -d $(zypper -n lr | awk '/-Source/ {print $1}')});
    }
    elsif (script_run('zypper lr repo-source') == 0) {
        zypper_call("mr -d repo-source");
    }
}


=head2 generate_version

 generate_version($separator);

Generate SLE or openSUSE versions. C<$separator> is separator used for version number, it will be default to _ if omitted. Example: SLES-12-4, openSUSE_Leap

=cut
sub generate_version {
    my ($separator) = @_;
    my $dist        = get_required_var('DISTRI');
    my $version     = get_required_var('VERSION');
    $separator //= '_';
    if (is_sle) {
        $dist = 'SLE';
        $version =~ s/-/$separator/;
    } elsif (is_tumbleweed) {
        $dist = 'openSUSE';
    } elsif (is_leap) {
        $dist = 'openSUSE_Leap';
    }
    return $dist . $separator . $version;
}


=head2 validate_repo_enablement

 validate_repo_enablement(%args);

Validates that repo with given name and alias has correct uri and is enabled.
C<%args> should have following keys defined:
- C<alias>: repository alias
- C<name>: repository name
- C<uri>: repository uri

=cut
sub validate_repo_enablement {
    my (%args) = @_;

    my $output = script_output('zypper lr --uri');

    assert_true($output =~ /
        \d\s+\|                 # #
        \s+$args{alias}.*\s+\|  # Alias
        \s+$args{name}.*\s+\|   # Name
        \s+Yes\s+\|             # Enabled
        \s+\(r\s+\)\s+Yes\s+\|  # GPG Check
        \s+Yes\s+\|             # Refresh
        \s+(?<uri>.*)           # URI
    /ix, "Repository $args{name} is not found in the installed system:\n$output");

    assert_equals($args{uri}, $+{uri},
        "Repository $args{name} has system wrong url or repo is not added to the system:\n$output");
}

1;
