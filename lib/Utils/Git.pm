# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Utils::Git;

use base 'Exporter';
use Exporter;
use Carp 'croak';
use strict;
use warnings;
use testapi qw(record_info assert_script_run upload_logs);

our @EXPORT = qw(
  git_clone
);

=head1 Utils::Git

C<Utils::Git> - Library for various git related functions

=cut


=head2 git_clone

    git_clone('https://github.com/myrepo/tree/main'
        [, branch=>'development',
        depth=>1,
        single_branch=>1,
        skip_ssl_verification=>'true',
        output_log_file=>'git_clone.log',
        target_dir => '/path/to/repo/dir']);

B<repository>: Git repository url. Mandatory argument.

B<branch>: Clone and checkout specific branch (or tag). Default: not defined

B<single_branch>:  Enable cloning of branch (or tag) only. Branch is the one specified in `branch` argument.
    This can speed up cloning process by omitting unnecessary branches. Default: not defined

B<depth>: Shallow clone with truncated history to the specified number of commits.
    This speeds up cloning process by not cloning whole commit history. Default: not defined

B<skip_ssl_verification>: Disable SSL verification. Can be useful in case of self signed certificates.
    Define this parameter B<ONLY> if you want to skip verification. Default: undef

B<output_log_file>: Log output into a file.

B<target_dir>: Clone into specific directory. Directory will be created, must be empty.

Generic wrapper around C<git clone> command. Supports basic set of switches and output logging.

=cut

sub git_clone {
    my ($repository, %args) = @_;
    croak 'Missing mandatory argument "repository"' unless $repository;

    # Base command
    my @git_cmd = ('git');
    # Skip SSL verification - must be between  'git' and 'clone'
    push @git_cmd, '-c http.sslVerify=false' if $args{skip_ssl_verification};
    push @git_cmd, 'clone';
    # Checkout branch
    push @git_cmd, "--branch $args{branch}" if $args{branch};
    # Pro tip: cloning with --single-branch and --depth=1 gives you infinite cloning speed boost.
    # Clone single branch
    push @git_cmd, '--single-branch' if $args{single_branch};
    # Shallow clone
    push @git_cmd, "--depth $args{depth}" if $args{depth};
    push @git_cmd, $repository;

    # Append target directory - must be last argument
    if ($args{target_dir}) {
        assert_script_run("mkdir -p $args{target_dir}");
        push @git_cmd, $args{target_dir};
    }

    my $git_cmd = join(' ', @git_cmd);
    # Enable logging
    $git_cmd = "set -o pipefail; $git_cmd 2>&1 | tee $args{output_log_file}" if $args{output_log_file};

    record_info('git clone', "Cloning repository: $repository\nCMD: $git_cmd");
    assert_script_run($git_cmd);
    upload_logs($args{output_log_file}) if $args{output_log_file};
}
