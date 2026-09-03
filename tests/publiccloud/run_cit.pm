# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-image-tests
# Summary: Use google provided image test framework to test public cloud SUSE images
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils qw(zypper_call);
use serial_terminal 'select_serial_terminal';
use publiccloud::utils;
use publiccloud::gce;
use Mojo::DOM;

my $cred_path = '/tmp/gce_creds.json';
my $out_path = '/tmp/cit_results.xml';

sub build_xunit_report {
    my $report = shift;

    if (script_run("test -s $report") != 0) {
        die "$report file is either missing or empty";
    }

    parse_extra_log('XUnit', $report);
}

# In case of the local build is necessary (container is not available)
# remove the mandatory MS build process that cannot be skipped
sub patch_build_script {
    my $patch_file = '/root/cit/cloud-image-tests/build.patch';
    my $build_patch = <<'EOF';
54,55d53
< GOOS=windows GOARCH=amd64 go build -o $outpath/wrapp64.exe ./cmd/wrapper/main.go || exit 1
< GOOS=windows GOARCH=386 go build -o $outpath/wrapp32.exe ./cmd/wrapper/main.go || exit 1
72,75d69
<   GOOS=windows GOARCH=amd64 go test -c -tags cit || return 1
<   if [ -f "${suite}.test.exe" ]; then mv "${suite}.test.exe" "$outpath/${suite}64.exe" || return 1; fi
<   GOOS=windows GOARCH=386 go test -c -tags cit || return 1
<   if [ -f "${suite}.test.exe" ]; then mv "${suite}.test.exe" "$outpath/${suite}32.exe" || return 1; fi
EOF

    save_tmp_file('build.patch', $build_patch);
    my $dwnld = sprintf('curl %s%s -o %s', autoinst_url(), "/files/build.patch", $patch_file);
    assert_script_run($dwnld);
    assert_script_run("patch /root/cit/cloud-image-tests/local_build.sh $patch_file");
}

sub build_cit {
    if (my $cont = get_var('PUBLIC_CLOUD_CIT_CONTAINER')) {
        return $cont;
    }

    zypper_call('in -C go patch');
    assert_script_run('mkdir -p ./cit && cd $_');
    assert_script_run('git clone --depth 1 https://github.com/GoogleCloudPlatform/cloud-image-tests.git');
    script_run('cd cloud-image-tests');

    my $outspath = "./testsbin";
    assert_script_run("mkdir -p $outspath");
    patch_build_script;

    foreach (@_) {
        script_run("bash -x ./local_build.sh -o $outspath -s $_", timeout => 3000);
    }

    my $cit_path = script_output("realpath $outspath");
    return $cit_path;
}

sub run_cit_tests {
    my $self = shift;
    my $sut_image = shift;
    my $cit_dir = shift;
    my $project = shift;

    # create a regex from the list of testsuites
    my $filter = join('|', @_);
    my $zone = sprintf('%s-%s', get_var('PUBLIC_CLOUD_REGION', ''), get_var('PUBLIC_CLOUD_AVAILABILITY_ZONE', ''));
    my $gce_store = get_var('PUBLIC_CLOUD_IMAGE_STORE', 'projects/suse-gce-qa/global/images/');
    my $image = sprintf('%s%s', $gce_store, $sut_image);

    my @cmd = (
        "podman run --rm -td",
        "-v /tmp:/creds",
        "-e GOOGLE_APPLICATION_CREDENTIALS=/creds/gce_creds.json",
        "$cit_dir",
        "-project '$project'",
        "-zone '$zone'",
        "-images '$image'",
        "-filter '$filter'",
        "-out_path /creds/cit_results.xml"
    );

    # cit_dir can point to a container
    # otherwise there are already built binaries from git
    if (script_run("test -d $cit_dir") == 0) {
        @cmd = (
            "GOOGLE_APPLICATION_CREDENTIALS=$cred_path",
            "$cit_dir/manager",
            "-project '$project'",
            "-zone '$zone'",
            "-images '$image'",
            "-filter '$filter'",
            "-local_path '$cit_dir'",
            "-out_path '$out_path'"
        );

        # permissions are required to get the container from google's registry
        assert_script_run("gcloud auth activate-service-account --key-file=$cred_path --project=$project");
        assert_script_run('gcloud auth configure-docker --quiet gcr.io');
        assert_script_run('gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin gcr.io');
    }

    my %suite_timeouts = (
        'guestagent' => 300,
        'hostnamevalidation' => 270,
        'compatmanager' => 360,
        'oslogin' => 240,
        'pluginmanager' => 600
    );

    # base timeout for VM provisioning
    my $dynamic_timeout = 300;
    # add timeout for each testsuite
    $dynamic_timeout += $suite_timeouts{$_} // 600 for @_;

    record_info('CIT Run', "Running tests: @_");
    if (script_run(join(' ', @cmd), timeout => $dynamic_timeout) != 0) {
        $self->result('fail');
    }

    return $out_path;
}

sub run {
    my ($self, $run_args) = @_;
    select_serial_terminal;

    # build the cloud-image-tests from source
    my @ts = get_var('PUBLIC_CLOUD_CIT_TESTS', '') =~ /[^\s,]+/g;
    my $cit = build_cit(@ts);

    # login to gce, find the SUT image name
    my $creds = get_credentials(url_suffix => 'gce.json', output_json => $cred_path);
    my $provider = $self->provider_factory();
    my $img_regex = lc(sprintf("%s.*%s-x8664", get_var('DISTRI'), get_var('VERSION')));
    my $sut = script_output(qq[gcloud compute images list --project="suse-gce-qa" --filter="name ~ '(?i)^$img_regex' AND name \!~ '(chost|byos)'" --format="value(name)" --no-standard-images]);
    unless (!!$sut) {
        die "Missing SUT image";
    }

    # run cloud-image-tests
    my $out = run_cit_tests($self, $sut, $cit, $creds->{project_id}, @ts);

    # parse external results
    build_xunit_report($out);
}

1;
