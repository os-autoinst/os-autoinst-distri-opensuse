# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Base module for STIG test cases
# Maintainer: QE Security <none@suse.de>

package oscap_tests;
use testapi;
use strict;
use warnings;
use utils;
use base 'opensusebasetest';
use version_utils qw(is_sle is_opensuse);
use bootloader_setup qw(add_grub_cmdline_settings);
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';
use Utils::Architectures;
use registration qw(add_suseconnect_product get_addon_fullname is_phub_ready);
use List::MoreUtils qw(uniq);
use List::Compare;
use Config::Tiny;
use YAML::PP;

our @EXPORT = qw(
  $profile_ID
  $ansible_profile_ID
  $f_ssg_sle_ds
  $f_ssg_sle_xccdf
  $f_ssg_ds
  $ssg_sle_ds
  $ssg_sle_xccdf
  $ssg_tw_ds
  $ssg_tw_xccdf
  $f_stdout
  $f_stderr
  $f_report
  $remediated
  $ansible_remediation
  $sle_version
  $compliance_as_code_path
  $evaluate_count
  set_ds_file
  set_ds_file_name
  upload_logs_reports
  pattern_count_in_file
  oscap_security_guide_setup
  oscap_remediate
  oscap_evaluate
  oscap_evaluate_remote
);

# The file names of scap logs and reports
our $f_stdout = 'stdout';
our $f_stderr = 'stderr';
our $f_vlevel = 'ERROR';
our $f_report = 'report.html';
our $f_pregex = '\\bpass\\b';
our $f_fregex = '\\bfail\\b';
our $ansible_exclusions;
our $ansible_playbook_modified = 0;
our $compliance_as_code_path;

# Set default value for 'scap-security-guide' ds file
our $f_ssg_sle_ds = '/usr/share/xml/scap/ssg/content/ssg-sle15-ds.xml';
our $f_ssg_tw_ds = '/usr/share/xml/scap/ssg/content/ssg-opensuse-ds.xml';
our $ssg_sle_ds = 'ssg-sle15-ds.xml';
our $ssg_tw_ds = 'ssg-opensuse-ds.xml';

our $f_ssg_sle_xccdf = '/usr/share/xml/scap/ssg/content/ssg-sle15-xccdf.xml';
our $f_ssg_tw_xccdf = '/usr/share/xml/scap/ssg/content/ssg-opensuse-xccdf.xml';
our $ssg_sle_xccdf = 'ssg-sle15-xccdf.xml';
our $ssg_tw_xccdf = 'ssg-opensuse-xccdf.xml';
our $f_ssg_ds;

# Profile IDs
our $profile_ID = "";
our $ansible_profile_ID = "";
# Profile names:
our $profile_ID_sle_stig = 'xccdf_org.ssgproject.content_profile_stig';
our $profile_ID_sle_cis = 'xccdf_org.ssgproject.content_profile_cis';
our $profile_ID_sle_pci_dss_4 = 'xccdf_org.ssgproject.content_profile_pci-dss-4';
our $profile_ID_sle_hipaa = 'xccdf_org.ssgproject.content_profile_hipaa';
our $profile_ID_sle_anssi_bp28_high = 'xccdf_org.ssgproject.content_profile_anssi_bp28_high';

our $profile_ID_tw = 'xccdf_org.ssgproject.content_profile_standard';

# Ansible playbooks
our $ansible_playbook_sle_stig = "playbook-stig.yml";
our $ansible_playbook_sle_cis = "playbook-cis.yml";
our $ansible_playbook_sle_pci_dss_4 = "playbook-pci-dss-4.yml";
# Only sle-15
our $ansible_playbook_sle_hipaa = "playbook-hipaa.yml";
our $ansible_playbook_sle_anssi_bp28_high = "playbook-anssi_bp28_high.yml";

our $ansible_playbook_standart = "opensuse-playbook-standard.yml";

# The OS status of remediation: '0', not remediated; '>=1', remediated
our $remediated = 0;

# Is it ansible remediation: '0', bash remediation; '1' ansible remediation
our $ansible_remediation = 0;

# Directory where ansible playbooks resides on local system
our $ansible_file_path = "/usr/share/scap-security-guide/ansible/";
our $full_ansible_file_path = "";

# Variables $use_content_type and $remove_rules_missing_fixes are fetched from configuration file located in:
#https://gitlab.suse.de/seccert-public/compliance-as-code-compiled/-/blob/main/content/openqa_config.conf
# Configuration for the contenyt type (source of ds, ansible and xccdf files):
# If set to 1 - tests will use files from scap-security-guide package
# If set to 2 - tests will use files from compliance-as-code-compiled repository - https://gitlab.suse.de/seccert-public/compliance-as-code-compiled
# If set to 3 - tests will use files cloned and built from ComplianceAsCode repository master branch - https://github.com/ComplianceAsCode/content.git
our $use_content_type = 1;

# Option configures to use or not functionality to remove from DS and ansible file rules for which do not have remediations
# If set to 1 - rules for which do not have remediations will be removed from DS and ansible file rules for which do not have remediations
# If set to 0 - no changes done.
our $remove_rules_missing_fixes = 1;

# Option configures to use or not functionality to exclude rules for profiles defined in file:
# https://gitlab.suse.de/seccert-public/compliance-as-code-compiled/-/blob/main/content/openqa_tests_exclusions.yaml
# If set to 1 - rules defined in exclusions files are excluded for remediation and evaluation
# If set to 0 - rules defined in exclusions files are not used
our $use_exclusions = 1;

# Keeps count of reboots to control it
our $reboot_count = 0;

# evaluate execution count done by test execution. Set in oscap_security_guide_setup.pm
# and "security/oscap_stig/oscap_xccdf_eval" need to be set in the schedule yaml file accordingly
our $evaluate_count = 2;

# Stores CCE IDs of failed ansible remediation tasks.
# Used in second ansible remediation as exclusions.
our $failed_cce_ids_ref;

# List to collect needed run results
our @test_run_report = ();

# Get sle version "sle12" or "sle15"
our $sle_version = '';

# Stores current SCAP benchmark version
our $benchmark_version = '';

# Upload HTML report by default
set_var('UPLOAD_REPORT_HTML', 1);

sub set_ds_file {
    # Set the ds file for separate product, e.g.,
    # for SLE15 the ds file is "ssg-sle15-ds.xml";
    # for SLE12 the ds file is "ssg-sle12-ds.xml";
    # for Tumbleweed the ds file is "ssg-opensuse-ds.xml"
    my $version = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
    $f_ssg_sle_ds =
      '/usr/share/xml/scap/ssg/content/ssg-sle' . "$version" . '-ds.xml';
    $f_ssg_sle_xccdf =
      '/usr/share/xml/scap/ssg/content/ssg-sle' . "$version" . '-xccdf.xml';
}

sub set_ds_file_name {
    # Set the ds file name for separate product, e.g.,
    # for SLE15 the ds file is "ssg-sle15-ds.xml";
    # for SLE12 the ds file is "ssg-sle12-ds.xml";
    # for Tumbleweed the ds file is "ssg-opensuse-ds.xml"
    my $version = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
    $ssg_sle_ds =
      'ssg-sle' . "$version" . '-ds.xml';
    $ssg_sle_xccdf =
      'ssg-sle' . "$version" . '-xccdf.xml';
}

sub replace_ds_file {
    # Replace original ds file whith built or downloaded from repository
    my ($self) = $_[0];
    my $ds_file_name = $_[1];
    my $url = "https://gitlab.suse.de/seccert-public/compliance-as-code-compiled/-/raw/main/content/";

    # ComplianceAsCode repository master branch
    if ($use_content_type == 3) {
        assert_script_run("rm $f_ssg_sle_ds") if script_run "! [[ -e $f_ssg_sle_ds ]]";
        # Copy built file to correct location
        my $ds_local_full_file_path = "$compliance_as_code_path/build/$ds_file_name";
        assert_script_run("cp $ds_local_full_file_path $f_ssg_sle_ds");
        record_info("Copied ds file", "Copied file $ds_local_full_file_path to $f_ssg_sle_ds");
    }
    # compliance-as-code-compiled
    elsif ($use_content_type == 2) {
        download_file_from_https_repo($url, $ds_file_name);
        # Remove original ds file
        assert_script_run("rm $f_ssg_sle_ds") if script_run "! [[ -e $f_ssg_sle_ds ]]";
        # Copy downloaded file to correct location
        assert_script_run("cp $ds_file_name $f_ssg_sle_ds");
        record_info("Copied ds file", "Copied file $ds_file_name to $f_ssg_sle_ds");
    }
}
sub replace_xccdf_file {
    # Replace original xccdf file whith built or downloaded from repository
    my ($self) = $_[0];
    my $xccdf_file_name = $_[1];
    my $url = "https://gitlab.suse.de/seccert-public/compliance-as-code-compiled/-/raw/main/content/";

    # ComplianceAsCode repository master branch
    if ($use_content_type == 3) {
        assert_script_run("rm $f_ssg_sle_xccdf") if script_run "! [[ -e $f_ssg_sle_xccdf ]]";
        # Copy built file to correct location
        my $xccdf_local_full_file_path = "$compliance_as_code_path/build/$xccdf_file_name";
        assert_script_run("cp $xccdf_local_full_file_path $f_ssg_sle_xccdf");
        record_info("Copied xccdf file", "Copied file $xccdf_local_full_file_path to $f_ssg_sle_xccdf");
    }
    # compliance-as-code-compiled
    elsif ($use_content_type == 2) {
        download_file_from_https_repo($url, $xccdf_file_name);
        # Remove original xccdf file
        assert_script_run("rm $f_ssg_sle_xccdf") if script_run "! [[ -e $f_ssg_sle_xccdf ]]";
        # Copy downloaded file to correct location
        assert_script_run("cp $xccdf_file_name $f_ssg_sle_xccdf");
        record_info("Copied xccdf file", "Copied file $xccdf_file_name to $f_ssg_sle_xccdf");
    }
}

sub replace_ansible_file {
    # Replace original ansible file whith built or downloaded from repository
    my $url = "https://gitlab.suse.de/seccert-public/compliance-as-code-compiled/-/raw/main/ansible/";
    # ComplianceAsCode repository master branch
    if ($use_content_type == 3) {
        # Remove original ansible file
        assert_script_run("rm $full_ansible_file_path");
        my $ansible_local_full_file_path = "$compliance_as_code_path/build/ansible/$ansible_profile_ID";
        # Copy built file to correct location
        assert_script_run("cp $ansible_local_full_file_path $full_ansible_file_path");
        record_info("Copied ansible file", "Copied file $ansible_local_full_file_path to $full_ansible_file_path");
        upload_logs("$full_ansible_file_path") if script_run "! [[ -e $full_ansible_file_path ]]";
    }
    #  compliance-as-code-compiled
    elsif ($use_content_type == 2) {
        download_file_from_https_repo($url, $ansible_profile_ID);
        # Remove original ansible file
        assert_script_run("rm $full_ansible_file_path");
        # Copy downloaded file to correct location
        assert_script_run("cp $ansible_profile_ID $full_ansible_file_path");
        record_info("Copied ansible file", "Copied file $ansible_profile_ID to $full_ansible_file_path");
    }
    # scap-security-guide
    elsif ($use_content_type == 1) {
        # Remove original ansible file
        assert_script_run("rm $full_ansible_file_path");
        # Copy file to correct location
        my $ansible_local_full_file_path = "/root/$ansible_profile_ID";
        assert_script_run("cp $ansible_local_full_file_path $full_ansible_file_path");
        record_info("Copied ansible file", "Copied file $ansible_local_full_file_path to $full_ansible_file_path");
    }
}
sub modify_ansible_playbook {
    # Modify and backup ansible playbok for later reuse in remediation
    if ($ansible_playbook_modified == 0) {
        my $ansible_local_full_file_path = "/root/$ansible_profile_ID";

        # Copy downloaded file to correct location
        assert_script_run("cp $full_ansible_file_path $ansible_local_full_file_path");
        record_info("Backuped ansible file", "Backuped file $full_ansible_file_path to $ansible_local_full_file_path");

        my $insert_cmd = "sed -i \'s/      tags:/      ignore_errors: true\\n      tags:/g\' $full_ansible_file_path";
        assert_script_run("$insert_cmd");
        record_info("Inserted ignore_errors", "Inserted \"ignore_errors: true\" for every tag in playbook. CMD:\n$insert_cmd");
        $ansible_playbook_modified = 1;
    }
}

sub backup_ds_file {
    # Backup ds file for later reuse
    assert_script_run("cp $f_ssg_ds /root/$ssg_sle_ds");
    record_info("Backed up ds file", "Backuped file $f_ssg_ds to /root/$ssg_sle_ds");
}

sub restore_ds_file {
    # Restore ds file
    assert_script_run("rm $f_ssg_ds") if script_run "! [[ -e $f_ssg_ds ]]";
    assert_script_run("cp /root/$ssg_sle_ds $f_ssg_ds");
    record_info("Restored ds file", "Restored file /root/$ssg_sle_ds to $f_ssg_ds");
}

sub ansible_result_analysis {
    #Find count of failed or ignored ansible remediations
    my $data = $_[0];
    my @report = ();
    my $found = 0;
    my $full_report = "";
    my $failed_number = -1;
    my $error_number = -1;
    my $ignored_number = -1;
    my $i;

    my @lines = split /\n|\r/, $data;
    for ($i = $#lines; $i >= 0;) {
        if ($lines[$i] =~ /PLAY RECAP/) {
            $found = 1;
            $full_report = $lines[$i + 1];
            my @report = split /\s+/, $full_report;
            for my $j (0 .. $#report) {
                if ($report[$j] =~ /failed/) {
                    my @failed = split /\=/, $report[$j];
                    $failed_number = $failed[1];
                }
                if ($report[$j] =~ /ignored/) {
                    my @failed = split /\=/, $report[$j];
                    $ignored_number = $failed[1];
                }
            }
            last;
        }
        $i--;
    }
    #Returning results
    $_[1] = $full_report;
    $_[2] = $failed_number;
    $_[3] = $ignored_number;
    return $found;
}

sub ansible_failed_tasks_search_vv {
    #Find count and rules names of matched pattern
    my $data = $_[0];
    my @report = ();
    my $full_report = "";
    my $i;
    my $j = 1;
    my @failed_tasks = ();
    my @tasks_line_numbers = ();
    my $found_task = 0;

    my @lines = split /\n|\r/, $data;
    for ($i = 0; $i <= $#lines;) {
        if (($lines[$i] =~ /^fatal:/) or ($lines[$i] =~ /^failed:/)) {
            # looking for TASK name in upper lines
            unless (($found_task == 1) or ($i - $j == 0)) {
                if ($lines[$i - $j] =~ /task path:/) {
                    # recording task line number in palybook
                    @report = (split /:/, $lines[$i - $j]);
                    $report[2] =~ s/\r|\n//g;
                    push(@tasks_line_numbers, $report[2]);
                }
                if ($lines[$i - $j] =~ /TASK/) {
                    $found_task = 1;
                }
                else { $j++; }
            }
            $full_report = $lines[$i - $j];
            @report = (split /\[/, $full_report, 2);
            $report[1] =~ s/\]\s\*+|\n//g;
            push(@failed_tasks, $report[1]);
            $j = 1;
            $found_task = 0;
        }
        $i++;
    }
    @failed_tasks = uniq @failed_tasks;
    $_[1] = \@failed_tasks;
    $_[2] = \@tasks_line_numbers;
    my $failed_tasks_size = @failed_tasks;

    return $failed_tasks_size;
}

sub find_ansible_cce_by_task_name_vv {
    # Finding CCE IDs for failed or ignored rules in ansible playbook
    my $data = $_[0];
    my $failed_tasks = $_[1];
    my $tasks_line_numbers = $_[2];
    my $j = 1;
    my $i;
    my @cce_ids;
    my @cce_id_and_name;
    my $found_cce = 0;
    my $index;
    my $line;
    my @report = ();

    # Join long task name to one line
    my @lines = split /\n/, $data;
    for ($i = 0; $i <= $#lines;) {
        if ($lines[$i] =~ /- name:/) {
            $index = index($lines[$i], "me: ");
            if ($lines[$i + 1] =~ /^\s{$index}/) {
                $lines[$i] =~ s/\r|\n//g;
                $lines[$i + 1] =~ s/^\s{$index}//g;
                $lines[$i] .= " " . $lines[$i + 1];
            }
        }
        $i++;
    }
    $i = 0;
    for my $task_line_number (@$tasks_line_numbers) {
        if ($lines[$task_line_number - 1] =~ /- name:/) {
            # looking for task CCE ID
            while (($found_cce == 0) or ($task_line_number + $j == $#lines)) {
                if ($lines[$task_line_number + $j] =~ /CCE-/) {
                    $found_cce = 1;
                }
                else { $j++; }
            }
            @report = split /\-\s+/, $lines[$task_line_number + $j];
            $report[1] =~ s/\r|\n//g;
            push(@cce_ids, $report[1]);
            $line = "$report[1], @$failed_tasks[$i], Line number: $task_line_number";
            push(@cce_id_and_name, $line);
            $j = 1;
            $found_cce = 0;
        }
        $i++;
    }
    @cce_ids = uniq @cce_ids;
    @cce_id_and_name = uniq @cce_id_and_name;
    my $cce_ids_size = @cce_ids;
    $_[3] = \@cce_ids;
    $_[4] = \@cce_id_and_name;
    return $cce_ids_size;
}
sub upload_logs_reports {
    # Upload logs & ouputs for reference
=comment No need for xml files
    my $files;
    if (is_sle) {
        $files = script_output('ls | grep "^ssg-sle.*.xml"');
    }
    else {
        $files = script_output('ls | grep "^ssg-opensuse.*.xml"');
    }
    foreach my $file (split("\n", $files)) {
        upload_logs("$file");
    }
=cut

    upload_logs("$f_stdout") if script_run "! [[ -e $f_stdout ]]";
    upload_logs("$f_stderr") if script_run "! [[ -e $f_stderr ]]";

    if (get_var('UPLOAD_REPORT_HTML')) {
        upload_logs("$f_report", timeout => 600)
          if script_run "! [[ -e $f_report ]]";
    }
}
sub download_file_from_https_repo {
    # Downloads file from provided url
    my $url = $_[0];
    my $file_name = $_[1];
    my $full_url = "$url" . "$file_name";
    my $result = -1;

    my $FULL_URL = get_var("FILE", "$full_url");

    if (script_run("wget --no-check-certificate $FULL_URL") != 0) {
        record_info("FAILED to Downloaded file", "FAILED to downloaded file $file_name from $FULL_URL");
        $result = 0;
    }
    else {
        assert_script_run("chmod 774 $file_name");
        record_info("Downloaded file", "Downloaded file $file_name from $FULL_URL");
        $result = 1;
    }
    return $result;
}

sub display_oscap_information {
    #Displays OSCAP packages information
    # Record the pkgs' version for reference
    my $out = script_output("zypper se -s openscap-utils scap-security-guide");
    record_info("Pkg_ver", "openscap security guide packages' version:\n $out");
    # Check the ds file information for reference
    $out = script_output("oscap info $f_ssg_ds", quiet => 1);
    record_info("oscap info", "\"# oscap info $f_ssg_ds\" returns:\n $out");
    # Check the oscap version information for reference
    $out = script_output("oscap -V");
    record_info("oscap version", "\"# oscap -V\" returns:\n $out");
}

sub pattern_count_in_file {
    #Find count and rules names of matched pattern
    my $data = $_[0];
    my $pattern = $_[1];
    my @rules = ();
    my @rules_cce = ();
    my @rules_ids = ();
    my $count = 0;
    my @nlines;
    my $j;
    my $rule_name = "";
    my $cce_id = "";

    my @lines = split /\n|\r/, $data;
    for my $i (0 .. $#lines) {
        if ($lines[$i] =~ /$pattern/) {
            $count++;
            for ($j = 1; $j <= 5;) {    # Looking in upper lines
                if ($lines[$i - $j] =~ /Rule/) {    # Found rule
                    $lines[$i - $j + 1] =~ s/\s+//g;    # Remove whitespace from rule id
                    $rule_name = $lines[$i - $j + 1];
                    push(@rules_ids, $rule_name);    # Push rule id to list
                }
                if ($lines[$i - $j] =~ /Ident/) {    # Found CCE ID
                    $lines[$i - $j + 1] =~ s/\s+//g;    # Remove whitespace from CCE id
                    $cce_id = $lines[$i - $j + 1];
                    push(@rules_cce, $cce_id);    # Push rule id to list
                }
                $j++;
            }
            $rule_name .= ", " . $cce_id;    # Add CCE ID to rule name
            push(@rules, $rule_name);    # Push rule id and rule cce id to list
            $cce_id = "";
        }
    }
    #Returning by reference array of matched rules
    $_[2] = \@rules;    # rule id and rule cce id
    $_[3] = \@rules_cce;    # cce IDs
    $_[4] = \@rules_ids;    # rule IDs
    return $count;
}

sub modify_ds_ansible_files {
    # Removes bash and ansible excluded and not having fixes rules from DS and playbook files
    my $in_file_path = $_[0];
    my $bash_pattern = "missing a bash fix";
    my $ansible_pattern = "missing a ansible fix";
    my $data;
    my @bash_rules = ();
    my @ansible_rules = ();
    my $i = 0;
    my $bash_fix_missing = "bash_fix_missing.txt";
    my $ansible_fix_missing = "ansible_fix_missing.txt";
    my $ds_unselect_rules_script = "ds_unselect_rules.sh";

    $data = script_output("cat $in_file_path", quiet => 1);

    my @lines = split /\n|\r/, $data;
    # Find ansible and bash rules and write them to the list
    for ($i = 0; $i <= $#lines;) {    #(0 .. $#lines)
        if ($lines[$i] =~ /$bash_pattern/) {
            $i++;
            until ($lines[$i] =~ /\*\*\*/) {
                $lines[$i] =~ s/\s+|\r|\n//g;    #remowe unneded symbols
                push(@bash_rules, $lines[$i]);
                $i++;
            }
        }
        if ($lines[$i] =~ /$ansible_pattern/) {
            $i++;
            until ($lines[$i] =~ /\*\*\*/) {
                $lines[$i] =~ s/\s+|\r|\n//g;    #remowe unneded symbols
                push(@ansible_rules, $lines[$i]);
                $i++;
            }
        }
        $i++;
    }
    record_info("Got rules from lists", "Got rules from lists from  $in_file_path\nBash pattern:\n$bash_pattern\nAnsible pattern:\n $ansible_pattern");

    if ($#bash_rules > 0 and $ansible_remediation == 0) {
        record_info("Bash rules missing fix", "Bash rules missing fix:\n" . join "\n",
            @bash_rules
        );
    }
    if ($#ansible_rules > 0 and $ansible_remediation == 1) {
        record_info("Ansible rules missing fix", "Ansible rules missing fix:\n" . join "\n",
            @ansible_rules
        );
    }

    if ($ansible_remediation == 1) {
        my $ansible_f = join "\n", @ansible_rules;
        # Write rules to file
        assert_script_run("printf \"$ansible_f\" > \"$ansible_fix_missing\"");

        my $ret_get_ansible_exclusions = 0;
        my $ansible_exclusions;

        # Get rule exclusions for ansible playbook
        $ret_get_ansible_exclusions
          = get_test_exclusions($ansible_exclusions);
        # Write exclusions to the file
        if ($ret_get_ansible_exclusions == 1) {
            my $exclusions = (join "\n", @$ansible_exclusions);
            assert_script_run("printf \"\n$exclusions\" >> \"$ansible_fix_missing\"");
            record_info("Writing ansible exceptions to file", "Writing ansible exclusions:\n$exclusions\n\nto file: $ansible_fix_missing");
        }

        # Diasble excluded and fix missing rules in ds file
        my $unselect_cmd = "sh $compliance_as_code_path/tests/$ds_unselect_rules_script $f_ssg_sle_ds $ansible_fix_missing";
        assert_script_run("$unselect_cmd", timeout => 600);
        assert_script_run("rm $f_ssg_sle_ds");
        assert_script_run("cp /tmp/$ssg_sle_ds $f_ssg_sle_ds");
        record_info("Diasble excluded and fix missing rules in ds file", "Command $unselect_cmd");
        upload_logs("$ansible_fix_missing") if script_run "! [[ -e $ansible_fix_missing ]]";

        # Generate new playbook without exclusions and fix_missing rules
        my $playbook_gen_cmd = "oscap xccdf generate fix --profile $profile_ID --fix-type ansible $f_ssg_sle_ds > playbook.yml";

        assert_script_run("$playbook_gen_cmd", timeout => 600);
        record_info("Generated playbook", "Command $playbook_gen_cmd");
        # Replace original paybook to generated one
        assert_script_run("rm $full_ansible_file_path");
        assert_script_run("cp playbook.yml $full_ansible_file_path");
        record_info("Replaced playbook", "Replaced playbook $full_ansible_file_path with generated playbook.yml");

        # Modify and backup ansible playbook
        modify_ansible_playbook();
        # Upload generated playbook for evidence
        upload_logs("$full_ansible_file_path") if script_run "! [[ -e $full_ansible_file_path ]]";
    }
    else {
        my $bash_f = join "\n", @bash_rules;
        # Write rules to file
        assert_script_run("printf \"$bash_f\" > \"$bash_fix_missing\"");

        my $ret_get_bash_exclusions = 0;
        my $bash_exclusions;

        # Get rule exclusions for bash playbook
        $ret_get_bash_exclusions
          = get_test_exclusions($bash_exclusions);
        # Write exclusions to the file
        if ($ret_get_bash_exclusions == 1) {
            my $exclusions = (join "\n", @$bash_exclusions);
            assert_script_run("printf \"\n$exclusions\" >> \"$bash_fix_missing\"");
            record_info("Writing bash exceptions to file", "Writing bash exclusions:\n$exclusions\n\nto file: $bash_fix_missing");
        }

        # Diasble excluded and fix missing rules in ds file
        my $unselect_cmd = "sh $compliance_as_code_path/tests/$ds_unselect_rules_script $f_ssg_sle_ds $bash_fix_missing";
        assert_script_run("$unselect_cmd", timeout => 600);
        assert_script_run("rm $f_ssg_sle_ds");
        assert_script_run("cp /tmp/$ssg_sle_ds $f_ssg_sle_ds");
        record_info("Diasble excluded and fix missing rules in ds file", "Command $unselect_cmd");
        upload_logs("$bash_fix_missing") if script_run "! [[ -e $bash_fix_missing ]]";
    }
    upload_logs("$f_ssg_sle_ds") if script_run "! [[ -e $f_ssg_sle_ds ]]";

    my $output_full_path = script_output("pwd", quiet => 1);
    $output_full_path =~ s/\r|\n//g;
    my $bash_file_full_path = "$output_full_path/$bash_fix_missing";
    my $ansible_file_full_path = "$output_full_path/$ansible_fix_missing";
    record_info("Files paths for missing rules ", "Bash file path:\n$bash_file_full_path\nAnsible file path:\n $ansible_file_full_path");
    # Return bash and ansible rules missing fix
    $_[1] = \@bash_rules;
    $_[2] = \@ansible_rules;
}
sub install_python311 {
    # Install python 3.11 needed for script execution
    # Ansible playbook still executed by python 3.6 because 3.11 breaks many rules
    zypper_call("in python311 python311-rpm");
    # Set alias persistent
    my $alias_cmd = "alias python='/usr/bin/python3.11'";
    my $bashrc_path = "/root/.bashrc";
    assert_script_run("rm /usr/bin/python3");
    assert_script_run("ln -s python3.11 /usr/bin/python3");
    assert_script_run("printf \"" . $alias_cmd . "\" >> \"$bashrc_path\"");
    assert_script_run("alias python=python3.11");
}
sub generate_missing_rules {
    # Generate text file that contains rules that missing implimentation for profile
    my $output_file = "missing_rules.txt";

    # Installing python libs to be able to run profile_tool.py
    my $py_libs = "jinja2 PyYAML pytest pytest-cov Jinja2 setuptools ninja";
    assert_script_run('pip3 --quiet install --upgrade pip', timeout => 600);
    assert_script_run("pip3 --quiet install $py_libs", timeout => 600);

    assert_script_run("cd $compliance_as_code_path");
    assert_script_run("source .pyenv.sh");
    # Running script that generates file containing rules missing fixes
    my $cmd = "python build-scripts/profile_tool.py stats --missing --skip-stats --profile $profile_ID --benchmark $f_ssg_sle_xccdf --format plain > $output_file";

    assert_script_run("$cmd");
    record_info("Generated file $output_file", "generate_missing_rules Input file $f_ssg_sle_xccdf\n Command:\n$cmd");
    assert_script_run("cp $output_file /root");

    # Getting and showing profile statistics
    my $data = script_output("cat $output_file", quiet => 1);
    record_info("Profile missing stat", "Profile missing stat:\n $data");

    #Uplaod file to logs
    upload_logs("$output_file") if script_run "! [[ -e $output_file ]]";

    assert_script_run("cd /root");
    my $output_full_path = script_output("pwd", quiet => 1);
    $output_full_path =~ s/\r|\n//g;
    $output_full_path .= "/$output_file";

    return $output_full_path;
}

sub get_cac_code {
    # Get the code for the ComplianceAsCode by cloning its repository
    my $cac_dir = "src/content";
    my $git_repo = "https://github.com/ComplianceAsCode/content.git";
    my $git_clone_cmd = "git clone " . $git_repo . " $cac_dir";

    zypper_call("in git-core");
    assert_script_run("mkdir src");
    assert_script_run("rm -r $cac_dir", quiet => 1) if (-e "$cac_dir");
    assert_script_run('git config --global http.sslVerify false', quiet => 1);
    assert_script_run("set -o pipefail ; $git_clone_cmd", timeout => 600, quiet => 1);

    $compliance_as_code_path = script_output("pwd", quiet => 1);
    $compliance_as_code_path =~ s/\r|\n//g;
    $compliance_as_code_path .= "/$cac_dir";

    record_info("Cloned ComplianceAsCode", "Cloned repo $git_repo to folder: $compliance_as_code_path");
    # In case of use CaC master as source - building content
    if ($use_content_type == 3) {
        zypper_call('in cmake libxslt-tools', timeout => 180);
        my $py_libs = "lxml pytest pytest_cov json2html sphinxcontrib-jinjadomain autojinja sphinx_rtd_theme myst_parser prometheus_client mypy openpyxl pandas pcre2 cmakelint sphinx";
        # On s390x pip requires packages to build modules
        if (is_s390x) {
            zypper_call('in ninja clang15 libxslt-devel libxml2-devel python311-devel', timeout => 180);
            $py_libs = "lxml pytest pytest_cov json2html sphinxcontrib-jinjadomain autojinja sphinx_rtd_theme myst_parser prometheus_client mypy openpyxl pcre2 cmakelint sphinx";
            assert_script_run("pip3 --quiet install $py_libs", timeout => 600);
        }
        else {
            assert_script_run("pip3 --quiet install $py_libs", timeout => 600);
        }
        # Building CaC content
        assert_script_run("cd $compliance_as_code_path");
        assert_script_run("sh build_product $sle_version", timeout => 9000);
        record_info("build_product", "sh build_product $sle_version");
        assert_script_run("cd /root");
    }
    return $compliance_as_code_path;
}
=comment
    OSCAP exit codes from https://github.com/OpenSCAP/openscap/blob/maint-1.3/utils/oscap-tool.h
    // standard oscap CLI exit statuses
    enum oscap_exitcode {
        OSCAP_OK             =   0, // successful exit
        OSCAP_ERROR          =   1, // an error occurred
        OSCAP_FAIL           =   2, // a process (e.g. scan or validation) failed
        OSCAP_ERR_FETCH      =   1, // cold not fetch input file (same as error for now)
        OSCAP_BADARGS        = 100, // bad commandline arguments
        OSCAP_BADMODULE      = 101, // unrecognized module
        OSCAP_UNIMPL_MOD     = 110, // module functionality not implemented
        OSCAP_UNIMPL         = 111, // functionality not implemented
        // end of list
        OSCAP_EXITCODES_END_ = 120  // any code returned shall not be higher than this
    };
=cut

sub get_tests_config {
    # Get the tests configuration file from repository
    my $config_file_name = "openqa_config.conf";
    my $url = "https://gitlab.suse.de/seccert-public/compliance-as-code-compiled/-/raw/main/content/";

    download_file_from_https_repo($url, $config_file_name);

    my $config_file_path = script_output("pwd", quiet => 1);
    $config_file_path =~ s/\r|\n//g;
    $config_file_path .= "/$config_file_name";

    my $data = script_output("cat $config_file_path", quiet => 1);
    my $config = Config::Tiny->new;
    $config = Config::Tiny->read_string("$data");
    my $err = Config::Tiny::errstr;
    if ($err eq "") {
        # Configuration can be overridden by OpenQA variables
        $use_content_type = (get_var('OSCAP_USE_CONTENT_TYPE', '') eq '' ? $config->{tests_config}->{use_content_type} : get_required_var('OSCAP_USE_CONTENT_TYPE'));
        $remove_rules_missing_fixes = (get_var('OSCAP_REMOVE_RULES_MISSING_FIXES', '') eq '' ? $config->{tests_config}->{remove_rules_missing_fixes} : get_required_var('OSCAP_REMOVE_RULES_MISSING_FIXES'));
        $use_exclusions = (get_var('OSCAP_USE_EXCLUSIONS', '') eq '' ? $config->{tests_config}->{use_content_type} : get_required_var('OSCAP_USE_EXCLUSIONS'));
        record_info("Set test configuration", "Set test configuration from file $config_file_path\n use_content_type = $use_content_type\n  remove_rules_missing_fixes = $remove_rules_missing_fixes\n use_exclusions = $use_exclusions");
    }
    else {
        record_info("Tiny->read error", "Config::Tiny->read( $config_file_path )returned error:\n$err");
    }
    return $config_file_path;
}

sub get_test_expected_results {
    # Get expected results from remote file
    my $eval_match = ();
    my $type = "";
    my $arch = "";

    if ($ansible_remediation == 1) {
        $type = 'ansible';
    }
    else {
        $type = 'bash';
    }
    if (is_s390x) { $arch = "s390x"; }
    if (is_aarch64 or is_arm) { $arch = "aarch64"; }
    if (is_ppc64le) { $arch = "ppc"; }
    if (is_x86_64) { $arch = "x86_64"; }
    my $version = get_var('VERSION');
    my $sles_sp = (split('-', $version))[1];

    my $exp_fail_list_name = $sle_version . "-exp_fail_list";
    my $expected_results_file_name = "openqa_tests_expected_results_" . $benchmark_version . ".yaml";
    my $url = "https://gitlab.suse.de/seccert-public/compliance-as-code-compiled/-/raw/main/content/";
    my @eval_match = ();

    my $return = download_file_from_https_repo($url, $expected_results_file_name);
    if ($return == 1) {
        record_info("Downloded results", "Downloded expected results for benchmark version $benchmark_version");
    }
    # In case if expected_results are not defined for specific benchmark_version
    else {
        $expected_results_file_name = "openqa_tests_expected_results.yaml";
        $return = download_file_from_https_repo($url, $expected_results_file_name);
    }
    if ($return == 1) {
        upload_logs("$expected_results_file_name") if script_run "! [[ -e $expected_results_file_name ]]";
        my $data = script_output("cat $expected_results_file_name", quiet => 1);

        # Phrase the expected results
        my $expected_results = YAML::PP::Load($data);
        record_info("Looking expected results", "Looking expected results for \nprofile_ID: $profile_ID\ntype: $type\narch: $arch\nname: $exp_fail_list_name\nService Pack: $sles_sp");

        $eval_match = $expected_results->{$profile_ID}->{$type}->{$arch}->{$exp_fail_list_name}->{$sles_sp};
        if (defined $eval_match) {
            @eval_match = @$eval_match;
            record_info("Got expected results", "Got expected results for \nprofile_ID: $profile_ID\ntype: $type\narch: $arch\nname: $exp_fail_list_name\nService Pack: $sles_sp\nBenchmark: $benchmark_version\nList of expected to fail rules:\n" . (join "\n", @eval_match));
        }
        else {
            record_info("No expected results", "Expected results are not defined.");
        }
    }
    else {
        record_info("No file for expected results", "Not able to download file with expected results.\nExpected results are not defined.");
    }

    $_[0] = \@eval_match;
    return 1;
}

sub get_test_exclusions {
    # Get exclusions from remote file
    my $exclusions = ();
    my $found = -1;
    my $type = "";
    my $arch = "";
    my $return = -1;

    # If set in configuration to not use excusions
    if ($use_exclusions == 0) {
        return $found;
    }
    else {
        if ($ansible_remediation == 1) {
            $type = 'ansible';
        }
        else {
            $type = 'bash';
        }
        if (is_s390x) { $arch = "s390x"; }
        if (is_aarch64 or is_arm) { $arch = "aarch64"; }
        if (is_ppc64le) { $arch = "ppc"; }
        if (is_x86_64) { $arch = "x86_64"; }
        my $version = get_var('VERSION');
        my $sles_sp = (split('-', $version))[1];

        my $exclusions_list_name = $sle_version . "-exclusions_list";
        my $exclusions_file_name = "openqa_tests_exclusions_" . $benchmark_version . ".yaml";
        my $url = "https://gitlab.suse.de/seccert-public/compliance-as-code-compiled/-/raw/main/content/";
        my @exclusions = ();

        $return = download_file_from_https_repo($url, $exclusions_file_name);
        if ($return == 1) {
            record_info("Downloded exclusions", "Downloded exclusions for benchmark version $benchmark_version");
        }
        # In case if exclusions are not defined for specific benchmark_version
        else {
            $exclusions_file_name = "openqa_tests_exclusions.yaml";
            $return = download_file_from_https_repo($url, $exclusions_file_name);
        }
        if ($return == 1) {
            upload_logs("$exclusions_file_name") if script_run "! [[ -e $exclusions_file_name ]]";
            my $data = script_output("cat $exclusions_file_name", quiet => 1);

            # Phrase the expected results
            my $exclusions_data = YAML::PP::Load($data);
            record_info("Looking exclusions", "Looking exclusions for \nprofile_ID: $profile_ID\ntype: $type\narch: $arch\nname: $exclusions_list_name\nService Pack: $sles_sp");

            $exclusions = $exclusions_data->{$profile_ID}->{$type}->{$arch}->{$exclusions_list_name}->{$sles_sp};
            # If results defined
            if (defined $exclusions) {
                @exclusions = @$exclusions;
                $found = 1;
                record_info("Got exclusions", "Got exclusions for \nprofile_ID: $profile_ID\ntype: $type\narch: $arch\nname: $exclusions_list_name\nService Pack: $sles_sp\nBenchmark: $benchmark_version\nList of excluded rules:\n" . (join "\n", @exclusions));
            }
            else {
                record_info("No exclusions", "Exclusions are not defined.");
            }
        }
        else {
            record_info("No file for exclusions", "Not able to download file with exclusions.\nExclusions are not defined.");
        }

        $_[0] = \@exclusions;
        return $found;
    }
}

sub oscap_security_guide_setup {
    # Main test setup function
    $full_ansible_file_path = $ansible_file_path . $ansible_profile_ID;

    record_info("$profile_ID", "Profile $profile_ID");
    if ($ansible_remediation == 0) {
        record_info("BASH", "BASH remediation used");
    }
    else {
        record_info("Ansible", "Ansible remediation used");
    }

    zypper_call('ref -s', timeout => 180);
    zypper_call('in openscap-utils scap-security-guide', timeout => 180);
    set_ds_file();

    $f_ssg_ds = is_sle ? $f_ssg_sle_ds : $f_ssg_tw_ds;
    display_oscap_information();

    # Get the tests configuration file from repository and set global configuration variables
    get_tests_config();
    push(@test_run_report, "[configuration]");
    my $out = script_output("date", quiet => 1);
    push(@test_run_report, "date = $out");
    $out = "";
    push(@test_run_report, "profile_ID = $profile_ID");
    push(@test_run_report, "ansible_profile_file_name = $ansible_profile_ID");
    push(@test_run_report, "use_content_type = $use_content_type");
    push(@test_run_report, "remove_rules_missing_fixes = $remove_rules_missing_fixes");
    push(@test_run_report, "use_exclusions = $use_exclusions");
    push(@test_run_report, "evaluate_count = $evaluate_count");

    # Replace original ds and xccdf files whith downloaded from local repository
    set_ds_file_name();
    push(@test_run_report, "sle_version = $sle_version");
    push(@test_run_report, "ssg_sle_ds = $ssg_sle_ds");
    push(@test_run_report, "ssg_sle_xccdf = $ssg_sle_xccdf");
    my $arch = get_var 'ARCH';
    push(@test_run_report, "os_arch = $arch");
    my $type;
    if ($ansible_remediation == 1) {
        $type = 'ansible';
    }
    else {
        $type = 'bash';
    }
    push(@test_run_report, "remediation_type = $type");
    my $build_url = get_var 'CASEDIR';
    push(@test_run_report, "build_url = $build_url");
    my $iso_name = get_var 'ISO';
    push(@test_run_report, "iso_name = $iso_name");
    my $full_name = get_var 'NAME';
    push(@test_run_report, "full_name = $full_name");
    my $schedule = get_var 'YAML_SCHEDULE';
    push(@test_run_report, "schedule = $schedule");

    unless (is_opensuse) {
        # Some packages require PackageHub repo is available
        return unless is_phub_ready();
        add_suseconnect_product(get_addon_fullname('phub'));
        # Need to use pyython3.1x
        add_suseconnect_product(get_addon_fullname('python3'));
        # On SLES 12 ansible packages require dependencies located in sle-module-public-cloud
        add_suseconnect_product(get_addon_fullname('pcm'), (is_sle('<15') ? '12' : undef)) if is_sle;
        install_python311();
    }

    # If required ansible remediation
    if ($ansible_remediation == 1) {
        my $pkg = 'ansible python311-pyOpenSSL';
        zypper_call "in $pkg sudo";
        # Record the pkg' version for reference
        my $out = script_output("zypper se -s $pkg", quiet => 1);
        record_info("$pkg Pkg_ver", "$pkg packages' version:\n $out");
        $out = "";
        #install ansible.posix
        assert_script_run("pip3 install ansible");
        assert_script_run("ansible-galaxy collection install ansible.posix");
    }
    if (($remove_rules_missing_fixes == 1) or ($use_content_type == 3)) {
        # Get the code for the ComplianceAsCode by cloning its repository
        get_cac_code();
    }
    # compliance-as-code-compiled or ComplianceAsCode repository master branch
    if (($use_content_type == 2) or ($use_content_type == 3)) {
        my $ds_file_name = is_sle ? $ssg_sle_ds : $ssg_tw_ds;
        replace_ds_file(1, $ds_file_name);

        my $xccdf_file_name = is_sle ? $ssg_sle_xccdf : $ssg_tw_xccdf;
        replace_xccdf_file(1, $xccdf_file_name);

        if ($ansible_remediation == 1) {
            replace_ansible_file();
        }
    }

    # Adding benchmark version to report
    my $ver_grep_cmd = 'grep "version update=" ' . "$f_ssg_sle_xccdf";
    $out = script_output("$ver_grep_cmd", quiet => 1);
    my @lines = split /\<|\>/, $out;
    $benchmark_version = $lines[2];
    push(@test_run_report, "benchmark_version = $benchmark_version");

    if ($remove_rules_missing_fixes == 1) {
        # Generate text file that contains rules that missing implimentation for profile
        my $missing_rules_full_path = generate_missing_rules();

        # Get bash and ansible rules lists from data based on provided
        my $ansible_rules_missing_fixes_ref;
        my $bash_rules_missing_fixes_ref;
        modify_ds_ansible_files($missing_rules_full_path, $bash_rules_missing_fixes_ref, $ansible_rules_missing_fixes_ref);
    }
    else {
        record_info("Do not modify DS or Ansible files", "Do not modify DS or Ansible files because remove_rules_missing_fixes = $remove_rules_missing_fixes");
    }
    backup_ds_file();

    # Record the source pkgs' versions for reference
    my $si_out = script_output("zypper se -si");
    record_info("Installed Pkgs", "List of installed packages:\n $si_out");
    # Record python modules versions for reference
    my $pip_out = script_output("pip freeze --local");
    record_info("python modules", "List of installed python modules:\n $pip_out");
    # Record Ansible version for reference
    if ($ansible_remediation == 1) {
        my $ansible_version = script_output("ansible --version");
        record_info("ansible version", "Ansible version:\n $ansible_version");
    }
    # Record python3 version for reference
    my $python3_version = script_output("python3 -VV");
    record_info("python3 version", "python3 version:\n $python3_version");
    # Record pip version for reference
    my $pip_version = script_output("pip -V");
    record_info("pip version", "pip version:\n $pip_version");
}

=ansible return codes
0 = The command ran successfully, without any task failures or internal errors.
1 = There was a fatal error or exception during execution.
2 = Can mean any of:

    Task failures were encountered on some or all hosts during a play (partial failure / partial success).
    The user aborted the playbook by hitting Ctrl+C, A during a pause task with prompt.
    Invalid or unexpected arguments, i.e. ansible-playbook --this-arg-doesnt-exist some_playbook.yml.
    A syntax or YAML parsing error was encountered during a dynamic include, i.e. include_role or include_task.

3 = This used to mean “Hosts unreachable” per TQM, but that seems to have been redefined to 4. I’m not sure if this means anything different now.
4 = Can mean any of:

    Some hosts were unreachable during the run (login errors, host unavailable, etc). This will NOT end the run early.
    All of the hosts within a single batch were unreachable- i.e. if you set serial: 3 at the play level, and three hosts in a batch were unreachable. This WILL end the run early.
    A synax or parsing error was encountered- either in command arguments, within a playbook, or within a static include (import_role or import_task). This is a fatal error. 

5 = Error with the options provided to the command
6 = Command line args are not UTF-8 encoded
8 = A condition called RUN_FAILED_BREAK_PLAY occurred within Task Queue Manager.
99 = Ansible received a keyboard interrupt (SIGINT) while running the playbook- i.e. the user hits Ctrl+c during the playbook run.
143 = Ansible received a kill signal (SIGKILL) during the playbook run- i.e. an outside process kills the ansible-playbook command.
250 = Unexpected exception- often due to a bug in a module, jinja templating errors, etc.
255 = Unknown error, per TQM.
=cut

sub oscap_remediate {
    my ($self) = @_;
    my $out_ansible_playbook;
    # Verify mitigation mode
    if ($remediated == 0) {
        push(@test_run_report, "[tests_results]");
    }
    # If doing ansible playbook remediation
    if ($ansible_remediation == 1) {
        my $ret;
        my $script_cmd;
        my $ansible_local_full_file_path = "/root/$ansible_profile_ID";
        # Modify playbook to ignore possible errors
        # and collect CCE IDs for exclusion from second remediation.
        modify_ansible_playbook();
        if ($remediated == 0) {
            $out_ansible_playbook = script_output("cat $full_ansible_file_path", quiet => 1, timeout => 1200);
            $script_cmd = "ansible-playbook -vv -i \"localhost,\" -c local $full_ansible_file_path > $f_stdout 2> $f_stderr";
        }
        else {
            # Restore original playbook to verify exclusions
            # Remove original ansible file
            assert_script_run("rm $full_ansible_file_path");
            # Copy file to correct location
            assert_script_run("cp $ansible_local_full_file_path $full_ansible_file_path");
            record_info("Restored ansible file", "Copied file $ansible_local_full_file_path to $full_ansible_file_path");

            $out_ansible_playbook = script_output("cat $full_ansible_file_path", quiet => 1, timeout => 1200);
            $script_cmd = "ansible-playbook -vv -i \"localhost,\" -c local $full_ansible_file_path";
            # If found faled tasks for current profile will add tem to command line
            if (defined $failed_cce_ids_ref) {
                my $cce_count = @$failed_cce_ids_ref;
                if ($cce_count > 0) {
                    $script_cmd .= " --skip-tags " . (join ",", @$failed_cce_ids_ref);
                }
            }
            $script_cmd .= " > $f_stdout 2> $f_stderr";
        }
        $ret
          = script_run($script_cmd, timeout => 3200);
        # In case if STIG rules switches console to GUI need to switch it back
        if ($profile_ID =~ /stig/) {
            select_console 'root-console';
        }

        record_info("Return=$ret", "$script_cmd  returned: $ret");
        if ($ret != 0 and $ret != 2 and $ret != 4) {
            record_info("Returened $ret", 'remediation should be succeeded', result => 'fail');
            $self->result('fail');
        }
        # Analysis of ansible playbok execution.
        # If found failed tasks - setting test failed.
        my $res_ret = -1;
        my $full_report;
        my $failed_number;
        my $ignored_number;

        my $out_f_stdout = script_output("tail -n 10 $f_stdout", quiet => 1);
        $res_ret = ansible_result_analysis($out_f_stdout, $full_report, $failed_number, $ignored_number);
        record_info('Got analysis results', "Ansible playbook.\nPLAY RECAP:\n$full_report");

        # If found failed or ignored tesks in ansible execution output
        if (($failed_number > 0) or ($ignored_number > 0)) {
            record_info('Found failed tasks', "Found:\nFailed tasks: $failed_number\nIgnored tasks: $ignored_number\nin ansible playbook remediations $f_stdout file");
            $self->result('fail');

            my $grep_cmd = 'grep "TASK\|task path:\|fatal:\|failed:" ' . "$f_stdout";
            $out_f_stdout = script_output("$grep_cmd", quiet => 1, timeout => 1200);
            record_info('Collected output', "grep cmd: $grep_cmd");

            my $failed_tasks_ref;
            my $cce_id_and_name_ref;
            my $tasks_line_numbers_ref;
            my $sesrch_ret = ansible_failed_tasks_search_vv($out_f_stdout, $failed_tasks_ref, $tasks_line_numbers_ref);
            if ($sesrch_ret > 0) {
                record_info(
                    "Found failed tasks names",
                    "Failed tasks unique names ($sesrch_ret):\n" . (join "\n",
                        @$failed_tasks_ref) .
                      "\n\nFailed tasks line numbers ($sesrch_ret):\n" . (join "\n",
                        @$tasks_line_numbers_ref)
                );
                my $find_ret = find_ansible_cce_by_task_name_vv($out_ansible_playbook, $failed_tasks_ref, $tasks_line_numbers_ref, $failed_cce_ids_ref, $cce_id_and_name_ref);
                if ($find_ret > 0) {
                    record_info(
                        "Found CCE IDs for failed tasks",
                        "CCE IDs and tasks names ($find_ret):\n" . (join "\n",
                            @$cce_id_and_name_ref) . "\n\nCCE IDs ($find_ret):\n" . (join "\n",
                            @$failed_cce_ids_ref)
                    );
                    push(@test_run_report, "failed_cce_ansible_remediation_$remediated = \"" . (join ",",
                            @$failed_cce_ids_ref) . "\"");
                }
                else {
                    record_info('No failed CCE', "Did not find failed CCE IDs");
                }
            }
            else {
                record_info('No failed tasks', "Did not find failed tasks");
            }
        }

        # Upload only stdout logs
        upload_logs("$f_stdout") if script_run "! [[ -e $f_stdout ]]";
        upload_logs("$f_stderr") if script_run "! [[ -e $f_stderr ]]";
    }
    # If doing bash remediation
    else {
        restore_ds_file();
        my $remediate_cmd = "oscap xccdf eval --profile $profile_ID --remediate --oval-results --report $f_report $f_ssg_ds > $f_stdout 2> $f_stderr";
        my $ret
          = script_run("$remediate_cmd", timeout => 3200);
        record_info("Return=$ret", "$remediate_cmd returns: $ret");
        if ($ret != 0 and $ret != 2) {
            record_info('bsc#1194676', 'remediation should be succeeded', result => 'fail');
            $self->result('fail');
        }
        # Upload logs & ouputs for reference
        upload_logs_reports();
    }
    $remediated++;
    record_info("Remediated $remediated", "Setting status remediated. Count $remediated");
}

sub oscap_evaluate {
    # Does evaluation and result analysis
    my ($self) = @_;
    select_console 'root-console';

    my $n_failed_rules = 0;
    my $eval_match;
    my ($failed_rules_ref, $passed_rules_ref);
    my ($failed_cce_rules_ref, $failed_id_rules_ref);
    my $lc;
    my ($fail_count, $pass_count);
    my $expected_eval_match;
    my $ret_expected_results;

    # Verify detection mode
    restore_ds_file();
    my $eval_cmd = "oscap xccdf eval --profile $profile_ID --oval-results --report $f_report $f_ssg_ds > $f_stdout 2> $f_stderr";
    my $ret = script_run("$eval_cmd", timeout => 600);
    if ($ret == 0 || $ret == 2) {
        record_info("Returned $ret", "$eval_cmd");
        # Note: the system cannot be fully remediated in this test and some rules are verified failing
        my $data = script_output("cat $f_stdout", quiet => 1);
        # For a new installed OS the first time remediate can permit fail
        # There are 2 cases:
        # $evaluate_count == 3 - 2 remediations and 3 evaluations
        # $evaluate_count == 2 - 1 remediation and 2 evaluations
        # $evaluate_count is configured fore every test on setup
        if (($remediated <= 1 and $evaluate_count == 3) or ($remediated == 0 and $evaluate_count == 2)) {
            record_info('non remediated', 'before remediation more rules fails are expected');
            $pass_count = pattern_count_in_file($data, $f_pregex, $passed_rules_ref);
            record_info(
                "Passed rules count=$pass_count",
                "Pattern $f_pregex count in file $f_stdout is $pass_count. Matched rules:\n " . join "\n",
                @$passed_rules_ref
            );
            $fail_count = pattern_count_in_file($data, $f_fregex, $failed_rules_ref);
            record_info(
                "Failed rules count=$fail_count",
                "Pattern $f_fregex count in file $f_stdout is $fail_count. Matched rules:\n" . join "\n",
                @$failed_rules_ref
            );
            # Upload logs & ouputs for reference
            upload_logs_reports();
        }
        else {
            #Verify remediated rules
            $ret_expected_results = get_test_expected_results($expected_eval_match);
            # Found expected results in yaml file
            if ($ret_expected_results == 1) {
                $n_failed_rules = @$expected_eval_match;
                $eval_match = $expected_eval_match;
            }
            record_info('remediated', 'after remediation less rules are failing');
            #Verify failed rules
            $fail_count = pattern_count_in_file($data, $f_fregex, $failed_rules_ref, $failed_cce_rules_ref, $failed_id_rules_ref);

            $lc = List::Compare->new('-u', \@$failed_id_rules_ref, \@$eval_match);
            my @intersection = $lc->get_intersection;    # list of rules found in both lists
            my @lonly = $lc->get_Lonly;    # list of rules found in expected results
            my @ronly = $lc->get_Ronly;    # list of rules NOT found in expected results
            if (@lonly == 0) {    # Not found unexpected failed rules
                if (@ronly == 0) {    # All failed rules found in expected results
                    record_info(
                        "Passed fail rules check",
                        "Pattern $f_fregex count in file $f_stdout is $fail_count, expected $n_failed_rules or LESS. Failed rules:\n" . (join "\n",
                            @intersection) . "\n\nExpected rules to fail:\n" . (join "\n",
                            @$eval_match)
                    );
                }
                else {    # some expected to fail rules are passing
                    record_info(
                        "Passed fail rules check",
                        "Pattern $f_fregex count in file $f_stdout is $fail_count, expected $n_failed_rules or LESS. Failed rules:\n" . (join "\n",
                            @intersection) . "\n\nExpected rules to fail:\n" . (join "\n",
                            @$eval_match) . "\n\nRULES PASSED, but are in expected to fail list:\n" . (join "\n",
                            @ronly)
                    );
                    push(@test_run_report, "passing_but_expected_to_fail_rules = \"" . (join ",",
                            @ronly) . "\"");
                }
                push(@test_run_report, "final_evaluation_result = pass");
            }
            else {    # found rules NOT in expected results
                record_info(
                    "Failed fail rules check",
                    "#Pattern $f_fregex count in file $f_stdout is $fail_count, expected $n_failed_rules. Failed rules:\n" . (join "\n",
                        @$failed_rules_ref) . "\n\n#Expected $n_failed_rules rules to fail:\n" . (join "\n",
                        @$eval_match) . "\n\n#Rules failed (not in expected list):\n" . (join "\n",
                        @lonly) . "\n\nRULES PASSED, but are in expected to fail list:\n" . (join "\n",
                        @ronly),
                    result => 'fail'
                );
                $self->result('fail');
                push(@test_run_report, "final_evaluation_result = fail");
                push(@test_run_report, "failed_rules_evaluation = \"" . (join ",",
                        @$failed_id_rules_ref) . "\"");
                push(@test_run_report, "failed_cce_evaluation = \"" . (join ",",
                        @$failed_cce_rules_ref) . "\"");
            }

            #record number of passed rules
            $pass_count = pattern_count_in_file($data, $f_pregex, $passed_rules_ref);
            record_info(
                "Passed check of passed rules count",
                "Pattern $f_pregex count in file $f_stdout is $pass_count. Matched rules:\n" . join "\n",
                @$passed_rules_ref
            );
            # Write collected report to file
            my $test_run_report_name = "test_run_report.txt";
            record_info('Writing report', "Writing test report to file: $test_run_report_name");
            assert_script_run("printf \"" . (join "\n", @test_run_report) . "\" >> \"$test_run_report_name\"");
            # Upload logs & ouputs for reference
            upload_logs("$test_run_report_name") if script_run "! [[ -e $test_run_report_name ]]";
            upload_logs_reports();
        }
        # Record the source pkgs' versions for reference
        my $si_out = script_output("zypper se -si");
        record_info("Installed Pkgs", "List of installed packages:\n $si_out");
    }
    else {
        record_info("errno=$ret", "# oscap xccdf eval --profile \"$profile_ID\" returns: $ret", result => 'fail');
        ($self)->result('fail');
    }
}

sub oscap_evaluate_remote {
    my ($self) = @_;

    select_console 'root-console';

    add_grub_cmdline_settings('ignore_loglevel', update_grub => 1);
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1);

    select_console 'root-console';

    # Verify detection mode with remote
    my $cmd = "oscap xccdf eval --profile $profile_ID --oval-results --fetch-remote-resources --report $f_report $f_ssg_ds > $f_stdout 2> $f_stderr";
    my $ret = script_run("$cmd", timeout => 3000);
    record_info("Return=$ret", "$cmd");
    if ($ret == 137) {
        record_info('bsc#1194724', "eval returned $ret", result => 'fail');
    }
    # Upload logs & ouputs for reference
    upload_logs_reports();
}
1;
