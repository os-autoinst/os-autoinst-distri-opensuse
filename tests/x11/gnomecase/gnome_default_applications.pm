# Gnome tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case 1503753: Gnome - Some types of files should
#  be opened by corresponding applications
# Maintainer: Chingkai <qkzhu@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    # Prepare test files
    x11_start_program('xterm');

    my @applications = (
        ['image/jpg',           'eog.desktop'],
        ['image/png',           'eog.desktop'],
        ['application/pdf',     'evince.desktop'],
        ['application/x-bzip2', 'org.gnome.FileRoller.desktop'],
        ['application/gzip',    'org.gnome.FileRoller.desktop']);
    my $defaultApps = check_default_apps(@applications);
    if ($defaultApps) {
        prepare_application_environment();
        open_default_apps();
        clear_application_environment();
    }

    # clear the xterm
    send_key 'alt-f4';

}

sub clear_application_environment {
    x11_start_program("rm -rf /home/$username/gnometest", valid => 0);    # Clean the test directory
}

sub prepare_application_environment {
    assert_script_run "mkdir gnometest";
    assert_script_run "wget -P /home/$username/gnometest " . autoinst_url . "/data/x11/test.pdf";
    assert_script_run "wget -P /home/$username/gnometest " . autoinst_url . "/data/x11/shotwell_test.jpg";
    assert_script_run "wget -P /home/$username/gnometest " . autoinst_url . "/data/x11/shotwell_test.png";
    assert_script_run "cp /usr/share/w3m/w3mhelp.html /home/$username/gnometest/";
    assert_script_run "tar cjvf /home/$username/gnometest/test.tar.bz2 -C /home/$username/gnometest/ test.pdf";
    assert_script_run "tar czvf /home/$username/gnometest/test.tar.gz -C /home/$username/gnometest/ test.pdf";

    # Open nautilus
    x11_start_program('nautilus');
    send_key "ctrl-l";
    type_string "/home/$username/gnometest\n";
    send_key "ret";
    assert_screen 'gnomecase-defaultapps-nautilus';
}

sub open_default_apps {
    # Open test files with default applications
    assert_and_dclick "gnomecase-defaultapps-jpgfile";    #open jpg
    assert_screen 'gnomecase-defaultapps-jpgopen';
    send_key "ctrl-w";                                    #close eog
    wait_still_screen;
    assert_and_dclick "gnomecase-defaultapps-pngfile";    #open png
    assert_screen 'gnomecase-defaultapps-pngopen';
    send_key "ctrl-w";                                    #close eog
    wait_still_screen;
    assert_and_dclick "gnomecase-defaultapps-pdffile";    #open pdf
    wait_still_screen;
    send_key "super-up";
    assert_screen 'evince-open-pdf';
    send_key "ctrl-w";                                    #close evince
    wait_still_screen;
    assert_and_dclick "gnomecase-defaultapps-bz2file";    #open bzip
    assert_screen 'gnomecase-defaultapps-bz2open';
    send_key "ctrl-w" unless is_sle('15+');               #close fileroller
    wait_still_screen;
    assert_and_dclick "gnomecase-defaultapps-gzfile";     #open gzip
    assert_screen 'gnomecase-defaultapps-gzopen';
    send_key "ctrl-w" unless is_sle('15+');               #close fileroller
    wait_still_screen;
    assert_and_dclick "gnomecase-defaultapps-htmlfile";    #open html
    assert_screen 'gnomecase-defaultapps-firefoxopen';
    send_key "alt-f4";                                     #close firefox
    wait_still_screen;
    send_key "ctrl-w";                                     #close nautilus
}

# For each element, will check if the mimetype will open with the correct application
sub check_default_apps {
    my @apps = @_;

    my $default    = 1;
    my $returnCode = 1;
    my @message    = ();
    for my $app (@apps) {
        if (is_sle('15+')) {
            $returnCode = script_run("[ '$app->[1]' == \$(gio mime '$app->[0]' |  awk 'NR==1{print \$NF}' | sed 's/[[:space:]]//' ) ]");
        }
        else {
            $returnCode = script_run("[ '$app->[1]' == \$(gvfs-mime --query '$app->[0]' |  awk 'NR==1{print \$NF}' | sed 's/[[:space:]]//' ) ]");
        }
        if ($returnCode) {
            push @message, "The mimetype $app->[0] should open with $app->[1]";
            $default = 0;
        }
    }
    record_soft_failure(join("\n", @message, "Please check bsc#1051183")) if !$default;

    return $default;
}

1;
