# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check if release notes are available from URL during installation
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    my ($self) = @_;
    assert_screen('release-notes-button');
    select_console 'install-shell';

    my $arch = get_required_var('ARCH');
    my $version = get_required_var('VERSION');
    my $url = "https://www.suse.com/releasenotes/${arch}/SUSE-SLES/${version}/index.html";
    my $curl_cmd = qq|curl -I -L --silent --output /dev/null --write-out "%{http_code}" $url|;
    validate_script_output($curl_cmd, qr/200/, title => 'URL check', fail_message => "URL '$url' not found") if $self->is_sles_in_rc_or_gm_phase();

    enter_cmd "zgrep -oh \"Got release notes.*\" /var/log/YaST2/y2log*";
    assert_screen [qw(got-releasenotes-RPM got-releasenotes-URL)];
    unless (match_has_tag 'got-releasenotes-URL') {
        my $error_msg = 'Release notes source does NOT match expectations or not found in YaST logs, expected source: URL';
        die $error_msg if $self->is_sles_in_rc_or_gm_phase();
        record_info('bsc#1190711', $error_msg);
    }
    reset_consoles;
    select_console 'installation';
}

1;
