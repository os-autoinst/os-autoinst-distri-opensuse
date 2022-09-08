# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: common parts on SMT and RMT, and other tools related to repositories.
# Maintainer: Lemon Li <leli@suse.com>

=head1 repo_tools

Tools for repositories used by openQA:

=over

=item * add_qa_head_repo

=item * add_qa_web_repo

=item * smt_wizard

=item * smt_mirror_repo

=item * rmt_wizard

=item * rmt_sync

=item * rmt_enable_pro

=item * rmt_list_pro

=item * rmt_mirror_repo

=item * rmt_export_data

=item * rmt_import_data

=item * prepare_source_repo

=item * disable_source_repo

=item * get_repo_var_name

=item * type_password_twice

=item * prepare_oss_repo

=item * disable_oss_repo

=item * generate_version

=item * validate_repo_properties

=item * parse_repo_data

=item * verify_software

=item * validate_install_repo

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
use xml_utils;

our @EXPORT = qw(
  add_qa_head_repo
  add_qa_web_repo
  get_installed_patterns
  smt_wizard
  smt_mirror_repo
  rmt_wizard
  rmt_sync
  rmt_enable_pro
  rmt_list_pro
  rmt_mirror_repo
  rmt_export_data
  rmt_import_data
  prepare_source_repo
  disable_source_repo
  get_repo_var_name
  type_password_twice
  prepare_oss_repo
  disable_oss_repo
  generate_version
  validate_repo_properties
  parse_repo_data
  verify_software
  validate_install_repo
);

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

=head2 get_installed_patterns

 get_installed_patterns();

Here zypper uses XML as output format for more precise parsing (by using '-x' command parameter).
Then the names of patterns are parsed from the XML.

Returns array containing all installed patterns in the system.

=cut

sub get_installed_patterns {
    my $xml = script_output q[zypper -n -q -x se -i -t pattern];
    map { $_->to_literal() } find_nodes(xpc => get_xpc($xml), xpath => '//solvable[@kind="pattern"]/@name');
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
    # add develop version of rmt repo
    if (get_var("DEV_PATH")) {
        my $url = get_var("DEV_PATH");
        zypper_call("ar -f http://download.suse.de/ibs/Devel:/SCC:/RMT/$url/ scc_rmt");
        zypper_call '--gpg-auto-import-keys ref';
    }
    my $setup_console = current_console();

    # install RMT and mariadb
    my $ret = zypper_call('in rmt-server', exitcode => [0, 107], log => 'zypper.log');
    if (($ret == 107) && (script_run('grep -E "rmt-server-config.*scriptlet failed" /tmp/zypper.log') == 0)) {
        record_soft_failure 'bsc#1195759';
        zypper_call 'in rmt-server';
    }
    zypper_call 'in mariadb';

    enter_cmd "yast2 rmt;echo yast2-rmt-wizard-\$? > /dev/$serialdev";
    # On x11, workaround bsc#1191112 by mouse click or drag the dialog.
    if (($setup_console =~ /x11/) && (check_var('RMT_TEST', 'rmt_chinese'))) {
        record_soft_failure('bsc#1191112 - When navigating through YaST module screens the next screen appears, but its content is not loaded');
        mouse_set(100, 100);
    }
    assert_screen 'yast2_rmt_registration';
    send_key 'alt-u';
    wait_still_screen(2, 5);
    type_string(get_required_var('SMT_ORG_NAME'));
    wait_still_screen(2, 5);
    send_key 'alt-p';
    wait_still_screen(2, 5);
    type_string(get_required_var('SMT_ORG_PASSWORD'));
    wait_still_screen(2, 5);
    send_key 'alt-n';
    assert_screen 'yast2_rmt_config_written_successfully', 200;
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
    # On x11, workaround bsc#1191112 by mouse click or drag the dialog.
    if (($setup_console =~ /x11/) && (check_var('RMT_TEST', 'rmt_chinese'))) {
        record_soft_failure('bsc#1191112 - When navigating through YaST module screens the next screen appears, but its content is not loaded');
        wait_still_screen(10, 15);
        mouse_drag(startx => 480, starty => 50, endx => 485, endy => 50, button => 'left');
    }
    assert_screen [qw(yast2_rmt_firewall yast2_rmt_firewall_disable)], 50;
    if (match_has_tag('yast2_rmt_firewall')) {
        if (check_var('RMT_TEST', 'rmt_chinese')) {
            send_key 'alt-t';
        }
        else {
            send_key 'alt-o';
        }
    }
    wait_still_screen;
    send_key 'alt-n';
    assert_screen 'yast2_rmt_service_status', 90;
    send_key_until_needlematch('yast2_rmt_config_summary', 'alt-n', 4, 10);
    send_key 'alt-f';
    wait_serial("yast2-rmt-wizard-0", 800) || die 'rmt wizard failed, it can be connection issue or credential issue';
}

=head2 rmt_sync

 rmt_sync();

Function to sync rmt server

=cut

sub rmt_sync {
    script_retry 'rmt-cli sync', delay => 60, retry => 6, timeout => 1800;
}

=head2 rmt_enable_pro

 rmt_enable_pro();

Function to enable products

=cut

sub rmt_enable_pro {
    my $pro_ls = get_var('RMT_PRO') || 'sle-module-legacy/15/x86_64';
    assert_script_run "rmt-cli products enable $pro_ls", 600;
}

=head2 rmt_mirror_repo

 rmt_mirror_repo();

Function to mirror the enabled repository

=cut

sub rmt_mirror_repo {
    assert_script_run 'rmt-cli mirror', 1800;
}

=head2 rmt_list_pro

 rmt_list_pro();

Function to list products

=cut

sub rmt_list_pro {
    assert_script_run 'rmt-cli product list', 600;
}

=head2 rmt_import_data

 rmt_import_data($datafile);

RMT server import data from one folder which stored RMT export data about
available repositories and the mirrored packages
C<$datafile> is repository source.

=cut

sub rmt_import_data {
    my ($datapath) = @_;
    # Check import data resource exsited
    assert_script_run("ls $datapath");
    # Import RMT data from test path to new RMT server
    assert_script_run("rmt-cli import data $datapath", 600);
    assert_script_run("rmt-cli import repos $datapath", 600);
    assert_script_run("rm -rf $datapath");
}

=head2 rmt_export_data

 rmt_export_data();

RMT server export data about available repositories and the mirrored packages

=cut

sub rmt_export_data {
    my $datapath = "/rmtdata/";
    assert_script_run("mkdir -p $datapath");
    assert_script_run("chown _rmt:nginx $datapath");
    # Export RMT data to one folder
    assert_script_run("rmt-cli export data $datapath", 600);
    assert_script_run("rmt-cli export settings $datapath", 600);
    assert_script_run("rmt-cli export repos $datapath", 600);
    assert_script_run("ls $datapath");
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
    my $dist = get_required_var('DISTRI');
    my $version = get_required_var('VERSION');
    $separator //= '_';
    if (is_leap(">=15.4")) {
        return $version;
    } elsif (is_sle) {
        $dist = 'SLE';
        $version =~ s/-/$separator/;
    } elsif (is_tumbleweed) {
        $dist = 'openSUSE';
    } elsif (is_leap) {
        $dist = 'openSUSE_Leap';
    }
    return $dist . $separator . $version;
}


=head2 validate_repo_properties

 validate_repo_properties($args);

Validates that repo with given search criteria (uri, alias, number)
has other properties mathing the expectations.
If one of the keys is not provided, that field will NOT be validated.
C<$args> should have following keys defined:
- C<Alias>: repository alias, optional
- C<Autorefresh>: repository Autorefresh property, optional
- C<Enabled>: repository Enabled property, optional
- C<Filter>: repository search criteria (alias, uri, number), uri is used if not defined
- C<Name>: repository name, optional
- C<URI>: repository uri, used as a search criteria if no C<Filter> provided.

=cut

sub validate_repo_properties {
    my ($args) = @_;
    my $search_criteria = $args->{Filter} // $args->{URI};
    my $actual_repo_data = parse_repo_data($search_criteria);

    if ($args->{Alias}) {
        assert_true($actual_repo_data->{Alias} =~ /$args->{Alias}/,
            "Repository $args->{Name} has wrong alias, expected: '$args->{Alias}', got: '$actual_repo_data->{Alias}'");
    }

    if ($args->{Name}) {
        assert_true($actual_repo_data->{Name} =~ /$args->{Name}/,
            "Repository '$args->{Name}' has wrong name: '$actual_repo_data->{Name}'");
    }

    if ($args->{URI}) {
        assert_true($actual_repo_data->{URI} =~ /$args->{URI}/,
            "Repository $args->{Name} has wrong URI, expected: '$args->{URI}', got: '$actual_repo_data->{URI}'");
    }

    if ($args->{Enabled}) {
        assert_equals($actual_repo_data->{Enabled}, $args->{Enabled},
            "Repository $args->{Name} has wrong value for the field 'Enabled'");
    }

    if ($args->{Autorefresh}) {
        assert_equals($actual_repo_data->{Autorefresh}, $args->{Autorefresh},
            "Repository $args->{Name} has wrong value for the field 'Autorefresh'");
    }
}

=head2 parse_repo_data

 parse_repo_data($repo_identifier);

Parses the output of 'zypper lr C<$repo_identifier>' command (detailed information about specific repository) and
returns it as Hash reference.

C<$repo_identifier> can be either alias, name, number from simple zypper lr, or URI.
Please, search for 'repos (lr)' on 'https://en.opensuse.org/SDB:Zypper_manual' page for more details of the command
usage and its output.

Returns Hash reference with all the parsed properties and their values, for example:
{Alias => 'repo-oss', Name => 'openSUSE-Tumbleweed-Oss', Enabled => 'Yes', ...}

=cut

sub parse_repo_data {
    my ($repo_identifier) = @_;
    my @lines = split(/\n/, script_output("zypper lr $repo_identifier"));
    my %repo_data = map { split(/\s*:\s*/, $_, 2) } @lines;
    return \%repo_data;
}

=head2 verify_software

 verify_software(%args);

Validates that package or pattern is installed, or not installed and/or if
package is available in the given repo.
returns string with error or empty string in case of matching expectations.
C<%args> should have following keys defined:
- C<name>: package or pattern name
- C<installed>: if set to true, validate that package or pattern is installed
- C<pattern>: set to true if is pattern, otherwise validating package
- C<available>: if set to true, validate that package or pattern is available in
                the list of packages with given search criteria, otherwise
                expect zypper command to fail
- C<repo>: Optional, name of the repo where the package should be available. Check
           is triggered only if C<available> is set to true

=cut

sub verify_software {
    my (%args) = @_;

    my $zypper_args = $args{installed} ? '--installed-only' : '--not-installed-only';
    # define search type
    $zypper_args .= $args{pattern} ? ' -t pattern' : ' -t package';
    # Negate condition if package should not be available
    my $cmd = $args{available} ? '' : '! ';
    $cmd .= "zypper --quiet --non-interactive se -n $zypper_args --match-exact --details @{[ $args{name} ]}";
    # Verify repo only if package expected to be available
    if ($args{repo} && $args{available}) {
        $cmd .= ' | grep ' . $args{repo};
    }
    # Record error in case non-zero return code
    if (script_run($cmd)) {
        my $error = $args{pattern} ? 'Pattern' : 'Package';
        if ($args{available}) {
            $error .= " '$args{name}' not found in @{[ $args{repo} ]} or not preinstalled."
              . " Expected to be installed: @{[ $args{installed} ? 'true' : 'false' ]}\n";
        }
        else {
            $error .= " '$args{name}' found in @{[ $args{repo} ]} repo, this package should not be present.\n";
        }
        return $error;
    }
    return '';
}

=head2

Verify that install repo C<mirror> corresponds to the one expected one.

=cut

sub validate_install_repo {
    my $method = uc get_required_var('INSTALL_SOURCE');
    my $mirror = get_required_var("MIRROR_$method");
    record_info("$method mirror:", "$mirror");
    assert_script_run("grep -Pzo \"install url:(.|\\n)*$mirror\" /var/log/linuxrc.log");
    assert_script_run('grep install=' . $mirror . ' /proc/cmdline');
    assert_script_run("grep --color=always -e \"^RepoURL: $mirror\" -e \"^ZyppRepoURL: $mirror\" /etc/install.inf");
}

1;
