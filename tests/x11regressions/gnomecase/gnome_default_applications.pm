# Gnome tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

# Case 1503753: Gnome - Some types of files should be opened by corresponding applications

sub run() {
    my $self = shift;

    # Prepare test files
    x11_start_program("xterm");
    wait_idle;
    assert_script_run "mkdir gnometest";
    assert_script_run "wget -P /home/$username/gnometest " . autoinst_url . "/data/x11regressions/test.pdf";
    assert_script_run "wget -P /home/$username/gnometest " . autoinst_url . "/data/x11regressions/shotwell_test.jpg";
    assert_script_run "wget -P /home/$username/gnometest " . autoinst_url . "/data/x11regressions/shotwell_test.png";
    assert_script_run "cp /usr/share/w3m/w3mhelp.html /home/$username/gnometest/";
    assert_script_run "tar cjvf /home/$username/gnometest/test.tar.bz2 -C /home/$username/gnometest/ test.pdf";
    assert_script_run "tar czvf /home/$username/gnometest/test.tar.gz -C /home/$username/gnometest/ test.pdf";
    send_key 'alt-f4';

    # Open nautilus
    x11_start_program("nautilus");
    assert_screen 'nautilus-launched', 3;
    send_key "ctrl-l";
    type_string "/home/$username/gnometest\n";
    send_key "ret";
    sleep 5;
    assert_screen 'gnomecase-defaultapps-nautilus';

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
    assert_screen 'evince-open-pdf', 5;
    send_key "ctrl-w";                                     #close evince
    wait_still_screen;
    assert_and_dclick "gnomecase-defaultapps-bz2file";     #open bzip
    assert_screen 'gnomecase-defaultapps-bz2open';
    send_key "ctrl-w";                                     #close fileroller
    wait_still_screen;
    assert_and_dclick "gnomecase-defaultapps-gzfile";      #open gzip
    assert_screen 'gnomecase-defaultapps-gzopen';
    send_key "ctrl-w";                                     #close fileroller
    wait_still_screen;
    assert_and_dclick "gnomecase-defaultapps-htmlfile";    #open html
    assert_screen 'gnomecase-defaultapps-firefoxopen';
    send_key "alt-f4";                                     #close firefox
    wait_still_screen;
    send_key "ctrl-w";                                     #close nautilus

    # Clean the test directory
    x11_start_program("rm -rf /home/$username/gnometest");
}

1;
# vim: set sw=4 et:
