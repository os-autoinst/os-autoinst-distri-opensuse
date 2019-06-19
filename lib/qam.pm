# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package qam;

use strict;
use warnings;

use base "Exporter";
use Exporter;

use testapi;
use utils;

our @EXPORT
  = qw(capture_state check_automounter is_patch_needed add_test_repositories ssh_add_test_repositories remove_test_repositories advance_installer_window get_patches check_patch_variables);

sub capture_state {
    my ($state, $y2logs) = @_;
    if ($y2logs) {    #save y2logs if needed
        assert_script_run "save_y2logs /tmp/y2logs_$state.tar.bz2";
        upload_logs "/tmp/y2logs_$state.tar.bz2";
        save_screenshot();
    }
    #upload ip status
    script_run("ip a | tee /tmp/ip_a_$state.log");
    upload_logs("/tmp/ip_a_$state.log");
    save_screenshot();
    script_run("ip r | tee /tmp/ip_r_$state.log");
    upload_logs("/tmp/ip_r_$state.log");
    save_screenshot();
    #upload dmesg
    script_run("dmesg > /tmp/dmesg_$state.log");
    upload_logs("/tmp/dmesg_$state.log");
    #upload journal
    script_run("journalctl -b > /tmp/journal_$state.log");
    upload_logs("/tmp/journal_$state.log");
}

sub check_automounter {
    my $ret = 1;
    while ($ret) {
        script_run(qq{[ \$(ls -ld /mounts | cut -d" " -f2) -gt 20 ]; echo automount-\$?- > /dev/$serialdev}, 0);
        $ret = wait_serial(qr/automount-\d-/);
        ($ret) = $ret =~ /automount-(\d)/;
        if ($ret) {
            script_run("rcypbind restart");
            script_run("rcautofs restart");
            sleep 5;
        }
    }
}

sub is_patch_needed {
    my $patch   = shift;
    my $install = shift // 0;

    return '' if !($patch);

    my $patch_status = script_output("zypper -n info -t patch $patch");
    if ($patch_status =~ /Status\s*:\s+[nN]ot\s[nN]eeded/) {
        return $install ? $patch_status : 1;
    }
}

# Function that will add all test repos
sub add_test_repositories {
    my $counter = 0;

    my $oldrepo = get_var('PATCH_TEST_REPO');
    my @repos   = split(/,/, get_var('MAINT_TEST_REPO', ''));
    # Be carefull. If you have defined both variables, the PATCH_TEST_REPO variable will always
    # have precedence over MAINT_TEST_REPO. So if MAINT_TEST_REPO is required to be installed
    # please be sure that the PATCH_TEST_REPO is empty.
    @repos = split(',', $oldrepo) if ($oldrepo);

    for my $var (@repos) {
        zypper_call("--no-gpg-check ar -f -n 'TEST_$counter' $var 'TEST_$counter'");
        $counter++;
    }
    # refresh repositories, inf 106 is accepted because repositories with test
    # can be removed before test start
    zypper_call('ref', exitcode => [0, 106]);
}

# Function that will add all test repos to SSH guest
sub ssh_add_test_repositories {
    my $host    = shift;
    my $counter = 0;

    my $oldrepo = get_var('PATCH_TEST_REPO');
    my @repos   = split(/,/, get_var('MAINT_TEST_REPO', ''));
    # Be carefull. If you have defined both variables, the PATCH_TEST_REPO variable will always
    # have precedence over MAINT_TEST_REPO. So if MAINT_TEST_REPO is required to be installed
    # please be sure that the PATCH_TEST_REPO is empty.
    @repos = split(',', $oldrepo) if ($oldrepo);

    for my $var (@repos) {
        assert_script_run("ssh root\@$host 'zypper -n --no-gpg-check ar -f -n TEST_$counter $var TEST_$counter'");
        $counter++;
    }
    # refresh repositories, inf 106 is accepted because repositories with test
    # can be removed before test start
    my $ret = script_run("ssh root\@$host 'zypper -n ref'", 240);
    die "Zypper failed with $ret" if ($ret != 0 && $ret != 106);
}

# Function that will remove all test repos
sub remove_test_repositories {

    type_string 'repos=($(zypper lr -e - | grep "name=TEST|baseurl=ftp" | cut -d= -f2)); if [ ${#repos[@]} -ne 0 ]; then zypper rr ${repos[@]}; fi';
    type_string "\n";
}

sub advance_installer_window {
    my ($screenName) = @_;

    send_key $cmd{next};
    unless (check_screen "$screenName", 90) {
        send_key_until_needlematch $screenName, $cmd{next}, 3, 90;
        record_soft_failure 'Retry most probably due to network problems poo#52319 or failed next click';
    }
}

# Get list of patches
sub get_patches {
    my ($incident_id, $repo) = @_;

    # Replace comma by space, repositories must be divided by space
    $repo =~ tr/,/ /;

    # Search for patches by incident, exclude not needed
    my $patches = script_output("zypper patches -r $repo | awk -F '|' '/[Nn]eeded/ && !/[Nn]ot [Nn]eeded/ && /$incident_id/ { printf \$2 }'");
    # Remove carriage returns and make patch list on one line
    $patches =~ s/\r//g;
    return $patches;
}

# Check variables for patch definition
sub check_patch_variables {
    my ($patch, $incident_id) = @_;

    if ($patch && $incident_id) {
        die('It is not possible to have defined INCIDENT_PATCH and INCIDENT_ID at the same time');
    }
    elsif (!$patch && !$incident_id) {
        die("Missing INCIDENT_PATCH or INCIDENT_ID");
    }
}

1;
