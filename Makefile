PERL5LIB_:=../..:os-autoinst:lib:tests/installation:tests/x11:tests/qa_automation:tests/virt_autotest:$$PERL5LIB

.PHONY: all
all:

.PHONY: help
help:
	echo "Call 'make test' to call tests"

.PHONY: prepare
prepare:
	git clone git://github.com/os-autoinst/os-autoinst
	$(MAKE) check-links
	cd os-autoinst && cpanm -nq --installdeps .
	cpanm -nq --installdeps .

os-autoinst/:
	@test -d os-autoinst || (echo "Missing test requirements, \
link a local working copy of 'os-autoinst' into this \
folder or call 'make prepare' to install download a copy necessary for \
testing" && exit 2)

tools/tidy: os-autoinst/
	@test -e tools/tidy || ln -s ../os-autoinst/tools/tidy tools/
	@test -e tools/absolutize || ln -s ../os-autoinst/tools/absolutize tools/
	@test -e .perltidyrc || ln -s os-autoinst/.perltidyrc ./

tools/lib/: os-autoinst/
	@test -e tools/lib || ln -s ../os-autoinst/tools/lib tools/

.PHONY: check-links
check-links: tools/tidy tools/lib/ os-autoinst/

.PHONY: check-links
tidy-check: check-links
	tools/tidy --check

.PHONY: tidy
tidy: tools/tidy
	$<

.PHONY: unit-test
unit-test:
	prove -Ios-autoinst/ t/

.PHONY: test-compile
test-compile: check-links
	export PERL5LIB=${PERL5LIB_} ; ( git ls-files "*.pm" || find . -name \*.pm|grep -v /os-autoinst/ ) | parallel perl -c 2>&1 | grep -v " OK$$" && exit 2; true

.PHONY: test-compile-changed
test-compile-changed: os-autoinst/
	export PERL5LIB=${PERL5LIB_} ; for f in `git diff --name-only | grep '.pm'` ; do perl -c $$f 2>&1 | grep -v " OK$$" && exit 2; done ; true

.PHONY: test-yaml-valid
test-yaml-valid:
	export PERL5LIB=${PERL5LIB_} ; tools/test_yaml_valid `git --no-pager diff --diff-filter=d --name-only master | grep 'schedule.*\.yaml'`

.PHONY: test-metadata
test-metadata:
	tools/check_metadata $$(git ls-files "tests/**.pm")

.PHONY: test-metadata-changed
test-metadata-changed:
	tools/check_metadata $$(git diff --name-only | grep 'tests.*pm')

.PHONY: test-merge
test-merge:
	@REV=$$(git merge-base FETCH_HEAD master 2>/dev/null) ;\
	if test -n "$$REV"; then \
	  FILES=$$(git diff --name-only FETCH_HEAD `git merge-base FETCH_HEAD master 2>/dev/null` | grep 'tests.*pm') ;\
	  for file in $$FILES; do if test -f $$file; then \
	    tools/check_metadata $$file || touch failed; \
	    git grep -q wait_idle $$file && touch failed; \
	    ${PERLCRITIC} $$file || (echo $$file ; touch failed) ;\
	  fi ; done; \
	fi
	@test ! -f failed

.PHONY: test-dry
test-dry:
	export PERL5LIB=${PERL5LIB_} ; tools/detect_code_dups

.PHONY: test-no-wait_idle
test-no-wait_idle:
	@! git --no-pager grep wait_idle lib/ tests/

.PHONY: test-spec
test-spec:
	tools/update_spec --check

.PHONY: test-static
test-static: tidy-check test-yaml-valid test-merge test-dry test-no-wait_idle test-unused-modules test-soft_failure-no-reference test-spec test-invalid-syntax
.PHONY: test
ifeq ($(TESTS),compile)
test: test-compile
else ifeq ($(TESTS),static)
test: test-static
else ifeq ($(TESTS),unit)
test: unit-test perlcritic
else
test: unit-test test-static test-compile perlcritic
endif

PERLCRITIC=PERL5LIB=tools/lib/perlcritic:$$PERL5LIB perlcritic --quiet --stern --include "strict" --include Perl::Critic::Policy::HashKeyQuote --include Perl::Critic::Policy::ConsistentQuoteLikeWords

.PHONY: perlcritic
perlcritic: tools/lib/
	${PERLCRITIC} $$(git ls-files -- '*.p[ml]' ':!:data/')

.PHONY: test-unused-modules
test-unused-modules:
	tools/detect_unused_modules

.PHONY: test-soft_failure-no-reference
test-soft_failure-no-reference:
	@! git --no-pager grep -E -e 'soft_failure\>.*\;' --and --not -e '([$$0-9a-z]+#[$$0-9]+|fate.suse.com/[0-9]|\$$[a-z]+)' lib/ tests/

.PHONY: test-invalid-syntax
test-invalid-syntax:
	tools/check_invalid_syntax
