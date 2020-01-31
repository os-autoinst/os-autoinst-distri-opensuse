package rstudio;
use testapi;
use strict;
use warnings;
use utils;

our @ISA    = qw(Exporter);
our @EXPORT = qw(rstudio_help_menu rstudio_sin_x_plot rstudio_create_and_test_new_project rstudio_cleanup_project);

sub rstudio_help_menu {
    my %args         = @_;
    my $rstudio_mode = $args{rstudio_mode} || "server";
    my $prefix       = "rstudio_$rstudio_mode";

    # open the About RStudio menu
    assert_and_click("$prefix-help-menu");
    assert_and_click("$prefix-about-rstudio");
    # and close it again
    assert_and_click("$prefix-about-rstudio-close");
}

sub rstudio_sin_x_plot {
    my %args         = @_;
    my $rstudio_mode = $args{rstudio_mode} || "server";
    my $prefix       = "rstudio_$rstudio_mode";

    # enter a space after both commands, so that the cursor is no longer in the
    # needle match area
    assert_and_click("$prefix-prompt");
    type_string('x = 2.*pi*seq(1, 100)/(100.) ');

    assert_screen("$prefix-x-data-entered");
    wait_screen_change { send_key('ret'); };

    type_string('plot(x, sin(x)) ');
    assert_screen("$prefix-plot-cmd-entered");

    wait_screen_change { send_key('ret'); };

    assert_screen("$prefix-sin-x-plot");
}

sub rstudio_create_and_test_new_project {
    my %args         = @_;
    my $rstudio_mode = $args{rstudio_mode} || "server";
    my $prefix       = "rstudio_$rstudio_mode";

    # open the "New Project" dialog
    assert_and_click("$prefix-file-menu");
    assert_and_click("$prefix-file-menu_new-project");
    assert_and_click("$prefix-don-t-save-current-workspace");

    # create a "New Directory" -> "New Project"
    assert_and_click("$prefix-new-project_new-directory");
    assert_and_click("$prefix-new-project_project-type");

    # enter project name and select "Create a git repository"
    assert_screen("$prefix-create-new-project");
    type_string("test_project");
    assert_and_click("$prefix-create-new-project_create-git-repository");
    assert_and_click("$prefix-create-new-project_create-project");

    # open the .gitignore file, enter *~ at the top and save it
    assert_and_click("$prefix-files-tab_select-gitignore");
    assert_screen("$prefix-gitignore-file");
    type_string("*~");
    wait_still_screen(1);
    send_key('ret');
    assert_screen("$prefix-gitignore-file-unsaved");
    send_key('ctrl-s');
    assert_screen("$prefix-gitignore-file-saved");

    # open the Git tab, stage the .gitignore file and commit it
    assert_and_click("$prefix-project_git-tab");
    assert_and_click("$prefix-project_git-tab_stage-gitignore");
    assert_and_click("$prefix-project_git-tab_commit");
    assert_and_click("$prefix-project_git-commit-window_commit-message");
    type_string("Add .gitignore");
    assert_and_click("$prefix-project_git-commit-window_commit-button");
    assert_and_click("$prefix-project_git-commit-window_commit-close");
    send_key('alt-f4');

    # open commit log and close it again
    assert_and_click("$prefix-project_commit-log-button");
    assert_screen("$prefix-project_commit-history");
    send_key('alt-f4');

    # close the project
    assert_and_click("$prefix-project_current-project-menu");
    assert_and_click("$prefix-project_current-project-menu_close-project");
    check_screen("$prefix-project_close-project_save-window", timeout => 10) && assert_and_click("$prefix-project_close-project_save-window", timeout => 1);
    assert_screen("$prefix-project_no-project-open");
}

sub rstudio_cleanup_project {
    x11_start_program('xterm');
    assert_script_run("rm -rf ~/test_project");
    wait_still_screen(1);
    send_key("alt-f4");

    # try to close all open windows:
    # => hammer alt+F4 and check if we match the generic desktop needle
    send_key_until_needlematch('generic-desktop', "alt-f4");
}
