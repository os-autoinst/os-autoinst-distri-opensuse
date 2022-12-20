#!/bin/bash
# Copyright 2019-2020 SUSE LLC
#
# Support library for OpenQA console tests.
#
# Note: This library automatically sets the following Bash options:
# set -xo pipefail
#
# Recommended usage
# =================
#
# OPENQA_TEST_FILES="<files to be copied to temp directory>"
# source openqa_lib.sh
# trap qa_fail ERR
# <write your test cases as regular shell script here>
#
#
# Note: If you do not use `trap qa_fail ERR`, you should explicitly call
# qa_pass at the end of your script. Otherwise qa_shutdown may incorrectly
# mark the last test case as failed if the return code of the last command
# was non-zero.
#
#
# OpenQA test settings
# ====================
#
# pod_package_deps
#   Comma-separated list of packages which need to be installed before running
#   the test. Example:
#   pod_package_deps: sed, awk
#
# pod_timeout
#   Script timeout in seconds. OpenQA will roll back to the last snapshot
#   if the test script exceeds this time limit. Default value: 60. Example:
#   pod_timeout: 180
#
# Test settings must be written in the script header as a comment. See
# bzip2.sh for example usage.
#
#
# API functions
# =============
#
# qa_start_test $subtest_name
#   Start a new subtest. Each subtest will be shown as a single result box
#   on the job details page. $subtest_name is an arbitrary string that will be
#   used as the result box title. All commands executed between
#   `source openqa_lib.sh` and the first `qa_start_test` will be grouped
#   under the "INIT" box.
#
#   Each subtest should end with a call to one of qa_pass, qa_fail,
#   qa_softfail or qa_skip. If you call more than one of them, only the first
#   call will set the subtest result (but side effects like script termination
#   by qa_fail will happen either way). If you don't set the result
#   explicitly, the subtest will automatically pass when the whole script ends
#   or a new subtest gets started by qa_start_test.
#
# qa_assert $command $arguments
#   Executes $command with the supplied arguments and checks the return value.
#   If the command succeeded, does nothing. If the command failed, calls
#   qa_fail.
#
#   This function is the more verbose alternative to using `trap qa_fail ERR`.
#
# qa_pass
#   Mark the current subtest as successful.
#
# qa_fail
#   Mark the current subtest as failed and terminate the test script. If you
#   use the `trap qa_fail ERR` convention, you can use `command || true`
#   to avoid triggering the error trap when it doesn't matter whether
#   the command failed.
#
# qa_softfail
#   Mark the current subtest as softfailed. If the subtest is wrapped
#   in a function, automatically exits the function with non-zero return
#   value.
#
#   WARNING: If you use the `trap qa_fail ERR` convention, you must call any
#   subtest function with softfails as `subtest_func || true` to avoid
#   triggering the error trap.
#
# qa_skip
#   Mark the current subtest as skipped. If the subtest is wrapped
#   in a function, automatically exits the function with zero return value.
#
# qa_shutdown
#   Cleanup at the end of the test script. This function is responsible
#   for collecting all test results into the JSON log. You do not need to call
#   it yourself unless you override the exit trap.
#
#
# Version utils
# =============
#
# qa_check_version $cmp $version [$regex]
#   Compares $_OPENQA_ENV_VERSION to $version. $cmp is the Bash-style integer
#   comparison operator. $regex is a Perl-compatible regular expression that
#   splits the version string into an array of integers (version tokens). If
#   $regex is not provided, version strings will be compared as simple
#   integers.
#   Example: qa_check_version -gt 1.2.3 '^(\d+)\.(\d+)(?:\.(\d+))?'
#
# qa_is_microos [$filter | $cmp $version]
#   Checks for microos distribution. Optionally, you can also check for specific
#   flavor or version of MicroOS. $filter can be an arbitrary flavor string
#   or one of the predefined keywords: DVD VMX staging
#   If you pass a string containing (lowercase) "microos" as
#   $filter, then $_OPENQA_ENV_DISTRI will be checked for that exact string.
#   Checking for a specific version is done by passing the first two arguments
#   for qa_check_version. Examples:
#   qa_is_microos VMX
#   qa_is_microos random_flavor
#   qa_is_microos -gt 3.1
#
# qa_is_jeos
#   Checks for JeOS flavor
#
# qa_is_tumbleweed
#   Check for OpenSUSE Tumbleweed flavor
#
# qa_is_leap [$cmp $version]
#   Checks for OpenSUSE Leap flavor. Optionally, you can also check for
#   specific version of Leap by passing the first two arguments for
#   qa_check_version.
#   Example: qa_is_leap -ge 15.1
#
# qa_is_opensuse
#   Checks for OpenSUSE distribution
#
# qa_is_sle [$cmp $version]
#   Checks for SLE distribution. Optionally, you can also check for specific
#   version of SLE by passing the first two arguments for qa_check_version.
#   Example: qa_is_sle -gt 12-SP3

_qa_print () {
	echo "QA $$:" "$@" >&3
}

_qa_escape_json () {
	sed -e ':a;N;$!ba;s/\([\\"]\)/\\\1/g;s/\n/\\n/g' | tr -d '\n'
}

_qa_collect_logs () {
	local outfile="$_OPENQA_LOG_DIRECTORY/testlog.json"
	echo "[" >"$outfile"

	for (( i=0; $i < ${#_OPENQA_TEST_LIST[@]}; i++ )); do
		if [ $i -gt 0 ]; then
			echo "," >>"$outfile"
		fi

		echo -n '{"test":"' >>"$outfile"
		echo -n "${_OPENQA_TEST_LIST[$i]}" | _qa_escape_json >>"$outfile"
		echo -n '","result":"' >>"$outfile"
		echo -n "${_OPENQA_TEST_STATUS[$i]}" | _qa_escape_json >>"$outfile"
		echo -n '","stdout":"' >>"$outfile"
		_qa_escape_json <"$_OPENQA_LOG_DIRECTORY/stdout-$i.log" >>"$outfile"
		echo -n '","stderr":"' >>"$outfile"
		_qa_escape_json <"$_OPENQA_LOG_DIRECTORY/stderr-$i.log" >>"$outfile"
		echo -n '"}' >>"$outfile"
	done

	echo "]" >>"$outfile"
}

_qa_test_result () {
	if [ "x$_OPENQA_CURRENT_TEST" = "x" ]; then
		return
	fi

	_qa_print "$2 $_OPENQA_CURRENT_TEST"
	_OPENQA_TEST_STATUS[$(( ${#_OPENQA_TEST_LIST[@]} - 1 ))]="$1"
	_OPENQA_CURRENT_TEST=""
}

_qa_pass () {
	_qa_test_result ok PASS
}

_qa_fail () {
	_qa_test_result fail FAIL
}

_qa_error () {
	echo $@ 1>&2
	qa_fail
}

qa_init () {
	_OPENQA_START_DIRECTORY=`pwd`
	: ${_OPENQA_TEST_DIRECTORY:=/tmp/openqa_test-$$}
	: ${_OPENQA_LOG_DIRECTORY:=/tmp/openqa_log-$$}
	: ${_OPENQA_ENV_BACKEND:=unknown}
	: ${_OPENQA_ENV_DISTRI:=unknown}
	: ${_OPENQA_ENV_FLAVOR:=unknown}
	: ${_OPENQA_ENV_VERSION:=unknown}
	_OPENQA_CURRENT_TEST=""
	_OPENQA_TEST_LIST[0]="INIT"
	_OPENQA_TEST_STATUS[0]="ok"
	rm -rf "$_OPENQA_TEST_DIRECTORY" "$_OPENQA_LOG_DIRECTORY"
	mkdir "$_OPENQA_TEST_DIRECTORY" "$_OPENQA_LOG_DIRECTORY"

	if [ "x$OPENQA_TEST_FILES" != "x" ]; then
		cp -r $OPENQA_TEST_FILES "$_OPENQA_TEST_DIRECTORY/"
	fi

	cd "$_OPENQA_TEST_DIRECTORY"
	exec 3>&1 >"$_OPENQA_LOG_DIRECTORY/stdout-0.log" 2>"$_OPENQA_LOG_DIRECTORY/stderr-0.log"
	_qa_print "INIT"
}

qa_shutdown () {
	ret=$?
	set +x
	if [ "x$_OPENQA_CURRENT_TEST" != "x" ]; then
		if [ $ret -eq 0 ]; then
			_qa_pass
		else
			_qa_fail
		fi
	fi

	_OPENQA_CURRENT_TEST=""
	cd "$_OPENQA_START_DIRECTORY"
	rm -rf "$_OPENQA_TEST_DIRECTORY"
	_qa_collect_logs
}

qa_start_test () {
	set +x
	if [ "x$_OPENQA_CURRENT_TEST" != "x" ]; then
		_qa_pass
	fi

	local run="${#_OPENQA_TEST_LIST[@]}"
	exec >"$_OPENQA_LOG_DIRECTORY/stdout-$run.log" 2>"$_OPENQA_LOG_DIRECTORY/stderr-$run.log"
	_OPENQA_CURRENT_TEST="$1"
	_OPENQA_TEST_LIST[${#_OPENQA_TEST_LIST[@]}]="$1"
	set -x
}

qa_pass () {
	set +x
	_qa_pass
	set -x
}

qa_fail () {
	set +x
	_qa_fail
	exit 1
}

_qa_softfail () {
	set +x
	_qa_test_result softfail SOFTFAIL
	set -x
}

_qa_skip () {
	set +x
	_qa_test_result na SKIP
	set -x
}

qa_assert () {
	set +x
	eval "$@"
	ret=$?

	if [ $ret -ne 0 ] && [ "x$_OPENQA_CURRENT_TEST" != "x" ]; then
		_qa_fail
		_qa_print "Test failed on line" `caller`
		_qa_print "Command:" "$@"
		_qa_print "Return value:" $ret
		exit $ret
	fi

	set -x
}

_qa_wrap_function () {
	eval "$@"
	ret=$?
	set -x
	return $ret
}

_qa_check_version () {
	case "$1" in
	"-eq" | "-ne" | "-gt" | "-ge" | "-lt" | "-le")
		;;
	*)
		_qa_error "qa_check_version(): Invalid comparison operator $1"
		;;
	esac

	if [ -z "$_OPENQA_ENV_VERSION" ]; then
		_qa_error "qa_check_version(): \$_OPENQA_ENV_VERSION is empty"
	elif [ -z "$3" ]; then
		[ "$_OPENQA_ENV_VERSION" "$1" "$2" ]
		return
	fi

	read -r perl_script <<-EOF
		my (\$ver, \$query, \$regex) = @ARGV; \
		\$, = ', '; \
		sub max { \
		    my (\$a, \$b) = @_; \
		    return \$a > \$b ? \$a : \$b; \
		} \
		my \$i; \
		if (\$ver !~ /\$regex/) { \
		    print STDERR "Cannot parse version argument\\n"; \
		    exit 1; \
		} \
		my @ver_tokens = @{^CAPTURE}; \
		if (\$query !~ /\$regex/) { \
		    print STDERR "Cannot parse query argument\\n"; \
		    exit 1; \
		} \
		my @query_tokens = @{^CAPTURE}; \
		for (\$i = 0; \$i < max(\$#ver_tokens, \$#query_tokens); \$i++) { \
		    last if (\$ver_tokens[\$i] != \$query_tokens[\$i]); \
		} \
		print \$ver_tokens[\$i] - \$query_tokens[\$i];
	EOF

	diff=`perl -e "$perl_script" "$_OPENQA_ENV_VERSION" "$2" "$3"`

	if [ $? -ne 0 ]; then
		qa_fail
	fi

	echo "Version diff: $diff"
	[ "$diff" $1 0 ]
}

qa_check_version () {
	set +x
	_qa_wrap_function _qa_check_version "$@"
}

_qa_is_microos () {
	if ! [[ "x$_OPENQA_ENV_DISTRI" =~ microos ]]; then
		return 1
	elif [ $# -le 0 ]; then
		return 0
	fi

	case "$1" in
	"-gt" | "-ge")
		[ "x$_OPENQA_ENV_VERSION" = xTumbleweed ] || \
			_qa_check_version "$@" '^([0-9]+)(?:\.([0-9]+))?'
		return
		;;
	"-eq" | "-ne" | "-lt" | "-le")
		[ "x$_OPENQA_ENV_VERSION" != xTumbleweed ] && \
			_qa_check_version "$@" '^([0-9]+)(?:\.([0-9]+))?'
		return
		;;
	DVD)
		[[ "x$_OPENQA_ENV_FLAVOR" =~ DVD ]]
		return
		;;
	VMX)
		! [[ "x$_OPENQA_ENV_FLAVOR" =~ DVD ]]
		return
		;;
	esac

	if [[ "x$1" =~ microos ]]; then
		[ "x$_OPENQA_ENV_DISTRI" = "x$1" ]
		return
	elif [[ "x$1" =~ staging ]]; then
		[[ "x$_OPENQA_ENV_FLAVOR" =~ Staging-.-DVD ]]
		return
	fi

	[ "x$_OPENQA_ENV_FLAVOR" = "x$1" ]
}

qa_is_microos () {
	set +x
	_qa_wrap_function _qa_is_microos "$@"
}

qa_is_jeos () {
	set +x
	_qa_wrap_function [[ "x$_OPENQA_ENV_FLAVOR" =~ ^xJeOS ]]
}

qa_is_tumbleweed () {
	set +x
	_qa_wrap_function [ "x$_OPENQA_ENV_DISTRI" = xopensuse ] && \
		[[ "x$_OPENQA_ENV_VERSION" =~ Tumbleweed|^xStaging: ]]
}

_qa_is_leap () {
	if [ "x$_OPENQA_ENV_DISTRI" != xopensuse ] ||
		! [[ "x$_OPENQA_ENV_VERSION" =~ ^x[0-9]+ ]]; then
		return 1
	fi

	[ $# -le 0 ] || _qa_check_version "$@" '^([0-9]+)(?:\.([0-9]+))?$'
}

qa_is_leap () {
	set +x
	_qa_wrap_function _qa_is_leap "$@"
}

qa_is_opensuse () {
	set +x
	_qa_wrap_function [ "x$_OPENQA_ENV_DISTRI" = xopensuse ] || \
		[ "x$_OPENQA_ENV_DISTRI" = xmicroos ]
}

_qa_is_sle () {
	if [ "x$_OPENQA_ENV_DISTRI" != xsle ]; then
		return 1
	fi

	[ $# -le 0 ] || _qa_check_version "$@" '^([0-9]+)(?:-SP([0-9]+))?$'
}

qa_is_sle () {
	set +x
	_qa_wrap_function _qa_is_sle "$@"
}

qa_init
trap qa_shutdown EXIT
alias qa_softfail='_qa_softfail; if [ "x$FUNCNAME" != "x" ]; then return 1; fi'
alias qa_skip='_qa_skip; if [ "x$FUNCNAME" != "x" ]; then return 0; fi'
shopt -s expand_aliases
set -xo pipefail
