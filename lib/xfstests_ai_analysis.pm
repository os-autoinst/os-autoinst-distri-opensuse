# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Knowledge base failure analysis for xfstests
# Merges two knowledge base sources:
#   - AI-generated:  XFSTESTS_AI_KB URL  (broad coverage, auto-generated)
#   - QE-maintained: XFSTESTS_QE_KB URL  (expert knowledge, higher priority)
# QE entries override AI entries for scalar fields (description, bug_probability, etc.)
# and prepend to list fields (common_causes, output_patterns, investigation_steps).
# Knowledge base files are hosted in the metadata project and downloaded at runtime.
# Maintainer: Yong Sun <yosun@suse.com>, kernel-qa <kernel-qa@suse.de>
package xfstests_ai_analysis;

use base Exporter;
use Exporter;
use 5.018;
use strict;
use warnings;
use testapi;
use YAML::PP;
use Mojo::UserAgent;
use Encode qw(decode_utf8);

our @EXPORT = qw(
  init_kb
  analyze_by_knowledgebase
  format_analysis_result);

my $_kb_cache;
my %_download_cache;

# ==================== Knowledge Base Suggestions ====================

=head2 analyze_by_knowledgebase

Analyze a failed test using the pre-generated knowledge base.
Must call init_kb() first to load the knowledge base.
Returns a hash ref with analysis results, or undef if test not found.

Features:
  - Matches output patterns (from both test output and full log) with per-pattern classification
  - Applies platform-specific factors (s390x, ppc64le, aarch64) from test context
  - Priority resolution: tool_version_mismatch overrides kernel_bug when patterns match

Arguments:
  test   - test name (e.g. "xfs/001")
  fstype - filesystem type
  output - test output content (for pattern and context matching)
  fullog - .full log content (for tool version mismatch detection)

=cut

sub analyze_by_knowledgebase {
    my ($test, $fstype, $output, $fullog) = @_;
    return unless $_kb_cache && $_kb_cache->{tests} && $_kb_cache->{tests}{$test};

    my $entry = $_kb_cache->{tests}{$test};
    my $result = {
        source => 'knowledge_base',
        test => $test,
        description => $entry->{description} // 'N/A',
        subsystem => $entry->{subsystem} // 'N/A',
        test_type => $entry->{test_type} // 'N/A',
    };

    if (my $fa = $entry->{failure_analysis}) {
        $result->{bug_probability} = $fa->{bug_probability} // 'unknown';
        $result->{classification} = $fa->{classification} // 'unknown';
        $result->{common_causes} = $fa->{common_causes} // [];
        $result->{investigation_steps} = $fa->{investigation_steps} // [];
    }

    # Match output patterns against actual test output and fullog
    my $combined_text = ($output // '') . "\n" . ($fullog // '');
    if ($entry->{output_patterns}) {
        my @matched = _match_output_patterns($combined_text, $entry->{output_patterns});
        if (@matched) {
            $result->{matched_patterns} = \@matched;
            # Apply per-pattern overrides: highest-priority match wins
            _apply_pattern_overrides($result, \@matched);
        }
    }

    # Apply platform-specific factors from test context
    my $ctx = _parse_test_context($output);
    if ($ctx->{arch} && $entry->{failure_analysis} && $entry->{failure_analysis}{platform_factors}) {
        _apply_platform_factors($result, $entry->{failure_analysis}{platform_factors}, $ctx);
    }
    $result->{context} = $ctx if $ctx->{arch};

    return $result;
}

=head2 _download_kb

Download a knowledge base YAML file from URL.
Uses Mojo::UserAgent with caching to avoid re-downloading.
Returns parsed YAML data structure, or undef on failure.

=cut

sub _download_kb {
    my ($url) = @_;
    return unless $url;

    return $_download_cache{$url} if exists $_download_cache{$url};

    my $res = Mojo::UserAgent->new(max_redirects => 5)->get($url)->result;
    unless ($res->is_success) {
        bmwqemu::fctinfo("KB download failed ($url): " . $res->message);
        $_download_cache{$url} = undef;
        return;
    }

    my $content = decode_utf8($res->body);
    if ($content =~ /^\s*</) {
        bmwqemu::fctinfo("KB download returned HTML instead of YAML ($url), check URL and access permissions");
        $_download_cache{$url} = undef;
        return;
    }
    $content =~ s/^\x{FEFF}//;
    my $data = eval { YAML::PP->new->load_string($content) };
    if ($@) {
        bmwqemu::fctinfo("KB YAML parse failed ($url): $@");
        $_download_cache{$url} = undef;
        return;
    }
    unless (ref($data) eq 'HASH' && $data->{tests}) {
        bmwqemu::fctinfo("KB YAML has unexpected structure ($url), expected hash with 'tests' key");
        $_download_cache{$url} = undef;
        return;
    }

    $_download_cache{$url} = $data;
    return $data;
}

=head2 init_kb

Load knowledge bases from URLs specified by XFSTESTS_AI_KB and XFSTESTS_QE_KB variables.
Downloads via HTTP (following the LTP::WhiteList pattern), parses YAML,
then merges QE-maintained KB on top (higher priority).
QE entries override scalar fields and prepend to list fields.
Returns true if at least one knowledge base was loaded successfully.

=cut

sub init_kb {
    return 1 if $_kb_cache;

    my $ai_url = get_var('XFSTESTS_AI_KB');
    my $qe_url = get_var('XFSTESTS_QE_KB');

    # Load AI-generated knowledge base (broad coverage)
    if ($ai_url) {
        eval { $_kb_cache = _download_kb($ai_url) };
        bmwqemu::fctinfo("Failed to load AI knowledge base: $@") if $@;
    }

    # Load QE-maintained knowledge base (expert knowledge, higher priority)
    if ($qe_url) {
        eval {
            my $qe_kb = _download_kb($qe_url);
            if ($qe_kb && $qe_kb->{tests}) {
                $_kb_cache //= {tests => {}};
                _merge_knowledge_bases($_kb_cache, $qe_kb);
            }
        };
        bmwqemu::fctinfo("Failed to load QE knowledge base: $@") if $@;
    }

    return defined $_kb_cache ? 1 : 0;
}

=head2 _merge_knowledge_bases

Merge QE knowledge base into the main cache. For each test entry:
  - Scalar fields (description, subsystem, bug_probability, classification):
    QE value overrides AI value
  - List fields (common_causes, investigation_steps, output_patterns):
    QE entries are prepended (shown first = higher priority)
  - platform_factors: merged per-architecture, QE overrides AI per-arch

=cut

sub _merge_knowledge_bases {
    my ($base, $override) = @_;
    for my $test (keys %{$override->{tests}}) {
        my $qe = $override->{tests}{$test};
        unless ($base->{tests}{$test}) {
            # Test only in QE KB — use as-is
            $base->{tests}{$test} = $qe;
            next;
        }
        my $ai = $base->{tests}{$test};

        # Scalar fields: QE overrides AI
        for my $key (qw(description subsystem test_type)) {
            $ai->{$key} = $qe->{$key} if defined $qe->{$key};
        }

        # failure_analysis sub-fields
        if ($qe->{failure_analysis}) {
            $ai->{failure_analysis} //= {};
            my $ai_fa = $ai->{failure_analysis};
            my $qe_fa = $qe->{failure_analysis};

            # Scalar overrides
            for my $key (qw(bug_probability classification)) {
                $ai_fa->{$key} = $qe_fa->{$key} if defined $qe_fa->{$key};
            }

            # List fields: QE prepended to AI
            for my $key (qw(common_causes investigation_steps)) {
                if ($qe_fa->{$key} && @{$qe_fa->{$key}}) {
                    $ai_fa->{$key} = [@{$qe_fa->{$key}}, @{$ai_fa->{$key} // []}];
                }
            }

            # platform_factors: merge per-architecture, QE overrides AI
            $ai_fa->{platform_factors} = {%{$ai_fa->{platform_factors} // {}}, %{$qe_fa->{platform_factors} // {}}};
        }

        # output_patterns: QE prepended to AI
        if ($qe->{output_patterns} && @{$qe->{output_patterns}}) {
            $ai->{output_patterns} = [@{$qe->{output_patterns}}, @{$ai->{output_patterns} // []}];
        }
    }
}

=head2 _match_output_patterns

Match test output against known patterns from the knowledge base.
Returns list of matched pattern hashes with bug_probability and classification.

=cut

sub _match_output_patterns {
    my ($output, $patterns) = @_;
    my @matched;
    for my $p (@$patterns) {
        next unless $p->{pattern};
        my $pat = $p->{pattern};
        # Try as regex first, fall back to literal match
        my $match = eval { $output =~ /$pat/i };
        $match = (index(lc($output), lc($pat)) >= 0) if $@;
        if ($match) {
            push @matched, {
                pattern => $pat,
                meaning => $p->{meaning} // '',
                bug_probability => $p->{bug_probability},
                classification => $p->{classification},
            };
        }
    }
    return @matched;
}

=head2 _apply_pattern_overrides

Apply per-pattern bug_probability and classification overrides.
Priority: tool_version_mismatch > test_bug > config_problem > kernel_bug.
If multiple patterns match, the highest-priority classification wins.

=cut

my %_classification_priority = (
    tool_version_mismatch => 1,
    test_bug => 2,
    config_problem => 3,
    test_environment_issue => 4,
    race_condition => 5,
    kernel_bug => 6,
);

sub _apply_pattern_overrides {
    my ($result, $matched) = @_;
    my $best_priority = 999;
    my ($best_prob, $best_class);

    for my $m (@$matched) {
        next unless $m->{classification};
        my $pri = $_classification_priority{$m->{classification}} // 500;
        if ($pri < $best_priority) {
            $best_priority = $pri;
            $best_prob = $m->{bug_probability};
            $best_class = $m->{classification};
        }
    }

    if ($best_class) {
        $result->{classification} = $best_class;
        $result->{bug_probability} = $best_prob if $best_prob;
    }
}

=head2 _parse_test_context

Parse test output header to extract platform context (arch, kernel, mount options, mkfs options).
xfstests output typically starts with lines like:
  PLATFORM      -- Linux/x86_64 hostname 6.x.y-default #1 SMP ...
  MOUNT_OPTIONS -- rw,relatime,attr2,inode64,...
  MKFS_OPTIONS  -- -f /dev/vdb1

=cut

sub _parse_test_context {
    my ($output) = @_;
    my %ctx;
    return \%ctx unless $output;

    if ($output =~ /PLATFORM\s+--\s+Linux\/(\S+)/) {
        my $platform = $1;
        if ($platform =~ /x86_64/) { $ctx{arch} = 'x86_64'; }
        elsif ($platform =~ /s390x/) { $ctx{arch} = 's390x'; }
        elsif ($platform =~ /ppc64le/) { $ctx{arch} = 'ppc64le'; }
        elsif ($platform =~ /aarch64/) { $ctx{arch} = 'aarch64'; }
        else { $ctx{arch} = $platform; }
    }

    if ($output =~ /MOUNT_OPTIONS\s+--\s+(.+)/) {
        $ctx{mount_options} = $1;
        $ctx{mount_options} =~ s/\s+$//;
    }

    if ($output =~ /MKFS_OPTIONS\s+--\s+(.+)/) {
        $ctx{mkfs_options} = $1;
        $ctx{mkfs_options} =~ s/\s+$//;
    }

    return \%ctx;
}

=head2 _apply_platform_factors

Apply platform-specific adjustments from knowledge base.
Merges extra_causes, extra_steps, and overrides bug_probability if defined.

=cut

sub _apply_platform_factors {
    my ($result, $platform_factors, $ctx) = @_;
    my $arch = $ctx->{arch};
    return unless $arch && $platform_factors->{$arch};

    my $pf = $platform_factors->{$arch};
    $result->{bug_probability} = $pf->{bug_probability} if $pf->{bug_probability};
    $result->{platform_note} = $pf->{note} if $pf->{note};

    if ($pf->{extra_causes} && @{$pf->{extra_causes}}) {
        $result->{common_causes} = [@{$result->{common_causes} // []}, @{$pf->{extra_causes}}];
    }
    if ($pf->{extra_steps} && @{$pf->{extra_steps}}) {
        $result->{investigation_steps} = [@{$result->{investigation_steps} // []}, @{$pf->{extra_steps}}];
    }
}

# ==================== Formatting ====================

=head2 format_analysis_result

Format knowledge base analysis result into readable text for record_info.

Arguments:
  kb_result  - hash ref from analyze_by_knowledgebase

=cut

sub format_analysis_result {
    my ($kb_result) = @_;
    return '' unless $kb_result;
    my $output = "=== AI Analysis (Knowledge Base) ===\n";

    $output .= "Test: $kb_result->{test} - $kb_result->{description}\n";
    $output .= "Subsystem: $kb_result->{subsystem}\n";
    $output .= "Test Type: $kb_result->{test_type}\n" if $kb_result->{test_type} ne 'N/A';
    $output .= "\n";

    $output .= "Bug Probability: " . uc($kb_result->{bug_probability} // 'unknown') . "\n";
    $output .= "Classification: $kb_result->{classification}\n" if $kb_result->{classification} && $kb_result->{classification} ne 'unknown';
    $output .= "Platform: $kb_result->{context}{arch}\n" if $kb_result->{context} && $kb_result->{context}{arch};
    $output .= "Note: $kb_result->{platform_note}\n" if $kb_result->{platform_note};
    $output .= "\n";

    if ($kb_result->{common_causes} && @{$kb_result->{common_causes}}) {
        $output .= "Common Causes:\n";
        for my $cause (@{$kb_result->{common_causes}}) {
            $output .= "- $cause\n";
        }
        $output .= "\n";
    }

    if ($kb_result->{matched_patterns} && @{$kb_result->{matched_patterns}}) {
        $output .= "Matched Patterns:\n";
        for my $m (@{$kb_result->{matched_patterns}}) {
            $output .= "- \"$m->{pattern}\"";
            $output .= " -> $m->{meaning}" if $m->{meaning};
            if ($m->{classification}) {
                $output .= " [$m->{classification}]";
            }
            $output .= "\n";
        }
        $output .= "\n";
    }

    if ($kb_result->{investigation_steps} && @{$kb_result->{investigation_steps}}) {
        $output .= "Investigation Steps:\n";
        my $n = 1;
        for my $step (@{$kb_result->{investigation_steps}}) {
            $output .= "$n. $step\n";
            $n++;
        }
    }

    return $output;
}

1;
