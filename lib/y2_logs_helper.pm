package y2_logs_helper;
use testapi;
use strict;
use warnings;
use version_utils qw(is_sle);
use ipmi_backend_utils;
use network_utils;
use utils 'zypper_call';
use Exporter 'import';
use Utils::Architectures;
use Utils::Logging 'tar_and_upload_log';


our @EXPORT_OK = qw(
  select_conflict_resolution
  workaround_dependency_issues
  break_dependency
  verify_license_has_to_be_accepted
  accept_license
  verify_license_translations
  get_available_compression
  upload_autoyast_profile
  upload_autoyast_schema
);


# select the conflict resolution for dependency issues
sub select_conflict_resolution {
    # higher similarity level as this should only select a single
    # entry, not close the dialog or something
    wait_screen_change(sub { send_key 'spc' }, undef, similarity_level => 55);
    # lower similarity level to not confuse the button press for
    # screen change
    wait_screen_change(sub { send_key 'alt-o' }, undef, similarity_level => 48);
}

# to workaround dependency issues
sub workaround_dependency_issues {
    return unless check_screen 'dependency-issue', 10;

    if (check_var('VIDEOMODE', 'text')) {
        while (check_screen('dependency-issue', 5)) {
            wait_screen_change { send_key 'alt-s' };
            wait_screen_change { send_key 'ret' };
            wait_screen_change { send_key 'alt-o' };
        }
    }
    else {
        while (check_screen('dependency-issue', 5)) {
            wait_screen_change { send_key 'alt-1' };
            select_conflict_resolution;
            # Refer ticket https://progress.opensuse.org/issues/48266
            wait_still_screen(2);
        }
    }
    return 1;
}

# to break dependency issues
sub break_dependency {
    return unless check_screen 'dependency-issue', 10;

    if (check_var('VIDEOMODE', 'text')) {
        while (check_screen('dependency-issue-text', 5)) {    # repeat it untill all dependency issues are resolved
            wait_screen_change { send_key 'alt-s' };    # Solution
            send_key 'down';    # down to option break dependency
            send_key 'ret';    # select option break dependency
            wait_screen_change { send_key 'alt-o' };    # OK - Try Again
        }
    }
    else {
        while (check_screen('dependency-issue', 5)) {
            # 2 is the option to break dependency
            send_key 'alt-2';
            select_conflict_resolution;
            # Refer ticket https://progress.opensuse.org/issues/48266
            wait_still_screen(2);
        }
    }
}


=head2 verify_license_has_to_be_accepted

    verify_license_has_to_be_accepted;

Explicitly check that the license has to be accepted.

Press 'Next' button to trigger a popup saying that the License has to be accepted then close the popup.

=cut

sub verify_license_has_to_be_accepted {
    send_key $cmd{next};
    assert_screen 'license-not-accepted';
    send_key $cmd{ok};
    wait_still_screen 1;
}

=head2 accept_license

    accept_license;

Select checkbox accepting the License agreement and check if it is actually selected.

Mark the test as failed if the checkbox is not selected after sending an appropriate command, otherwise proceed further.

=cut

sub accept_license {
    send_key $cmd{accept};
    assert_screen('license-agreement-accepted');
}

sub verify_license_translations {
    return if (is_sle && get_var("BETA"));
    my $current_lang = 'english-us';
    for my $lang (split(/,/, get_var('EULA_LANGUAGES')), 'english-us') {
        wait_screen_change { send_key 'alt-l' };
        # in textmode only arrow navigation is possible
        if (get_var('VIDEOMODE') =~ 'text') {
            send_key_until_needlematch("license-language-selected-english-us", 'up', 61);
            send_key 'ret';
        }
        else {
            assert_and_click "license-language-selected-$current_lang";
        }
        wait_screen_change { type_string(substr($lang, 0, 1)) } unless (check_var('VIDEOMODE', 'text'));
        send_key_until_needlematch("license-language-selected-dropbox-$lang", 'down', 61);
        if (is_s390x()) {
            record_soft_failure('bsc#1172738 - "Next" button is triggered, even though it is not in focus while selecting language on License Agreement screen on s390x');
            assert_and_click("license-language-selected-dropbox-$lang");
        }
        else {
            send_key 'ret';
        }
        assert_screen "license-content-$lang";
        $current_lang = $lang;
    }
}

sub get_available_compression {
    my %extensions = (bzip2 => '.bz2', gzip => '.gz', xz => '.xz');
    foreach my $binary (sort keys %extensions) {
        return $extensions{$binary} unless script_run("type $binary");
    }
    return "";
}

=head2 upload_autoyast_profile

    upload_autoyast_profile($self);

Uploads autoyast profile used for the installation, as well as modified profile,
in case feature to modify the profile dynamically was used.
Non existing files will be ignored.
=cut

sub upload_autoyast_profile {
    # Upload autoyast profile if file exists
    if (script_run('test -e /tmp/profile/autoinst.xml') == 0) {
        upload_logs '/tmp/profile/autoinst.xml';
    }
    # Upload cloned system profile if file exists
    if (script_run('test -e /root/autoinst.xml') == 0) {
        upload_logs '/root/autoinst.xml';
    }
    # Upload modified profile if pre-install script uses this feature
    if (script_run('test -e /tmp/profile/modified.xml') == 0) {
        upload_logs '/tmp/profile/modified.xml';
    }
    save_screenshot;
}

=head2 upload_autoyast_schema

    upload_autoyast_schema($self);

Uploads autoyast schema files shipped in the distribution as a tarball.
If expected directory doesn't exist, no attempt to upload logs occurs.
=cut

sub upload_autoyast_schema {
    my ($self) = @_;
    my $xml_schema_path = "/usr/share/YaST2/schema/autoyast/rng";
    # Upload schema files if directory exists
    if (script_run("test -e $xml_schema_path") == 0) {
        tar_and_upload_log("$xml_schema_path/*.rng", '/tmp/autoyast_schema.tar.bz2');
    }
}

1;
