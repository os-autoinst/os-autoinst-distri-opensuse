PERL5LIB_:=../..:os-autoinst:lib:tests/installation:tests/x11:tests/qa_automation:tests/virt_autotest:tests/cpu_bugs:tests/sles4sap/saptune:$$PERL5LIB

.PHONY: all
all:

.PHONY: help
help:
	echo "Call 'make test' to call tests"

.PHONY: prepare
prepare:
	git clone https://github.com/os-autoinst/os-autoinst.git
	./tools/wheel --fetch
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
	$< --only-changed
	@echo "[make] Tidy called over modified/new files only. For a full run use make tidy-full"

.PHONY: tidy-full
tidy-full: tools/tidy
	$<

.PHONY: unit-test
unit-test:
	prove -l -Ios-autoinst/ t/

.PHONY: test-compile
test-compile: check-links
	export PERL5LIB=${PERL5LIB_}:$(shell ./tools/wheel --verify) ; ( git ls-files "*.pm" || find . -name \*.pm|grep -v /os-autoinst/ ) | parallel perl -c 2>&1 | grep -v " OK$$" && exit 2; true

.PHONY: test-compile-changed
test-compile-changed: os-autoinst/
	export PERL5LIB=${PERL5LIB_}:$(shell ./tools/wheel --verify) ; for f in `git diff --name-only | grep '.pm'` ; do perl -c $$f 2>&1 | grep -v " OK$$" && exit 2; done ; true

.PHONY: test_pod_whitespace_rule
test_pod_whitespace_rule:
	tools/check_pod_whitespace_rule

.PHONY: test-yaml-valid
test-yaml-valid:
	$(eval YAMLS=$(shell sh -c "git ls-files schedule/ test_data/ | grep '\\.ya\?ml$$'"))
	if test -n "$(YAMLS)"; then \
		export PERL5LIB=${PERL5LIB_} ; echo "$(YAMLS)" | xargs tools/test_yaml_valid ;\
		else \
		echo "No yamls modified.";\
	fi
	if test -n "$(YAMLS)"; then \
		which yamllint >/dev/null 2>&1 || echo "Command 'yamllint' not found, can not execute YAML syntax checks";\
		echo "$(YAMLS)" | xargs yamllint -c .yamllint;\
	fi

.PHONY: test-modules-in-yaml-schedule
test-modules-in-yaml-schedule:
	export PERL5LIB=${PERL5LIB_} ; tools/detect_nonexistent_modules_in_yaml_schedule `git diff --diff-filter=d --name-only --exit-code origin/master | grep '^schedule/*'`

.PHONY: test-metadata
test-metadata:
	tools/check_metadata $$(git ls-files "tests/**.pm")

.PHONY: test-metadata-changed
test-metadata-changed:
	tools/check_metadata $$(git diff --name-only | grep 'tests.*pm')

.PHONY: test-merge
test-merge:
	@REV=$$(git merge-base origin/master 2>/dev/null) ;\
	if test -n "$$REV"; then \
	  FILES=$$(git diff --name-only origin/master | grep 'tests.*pm') ;\
	  for file in $$FILES; do if test -f $$file; then \
	    tools/check_metadata $$file || touch failed; \
	    git --no-pager grep wait_idle $$file && touch failed; \
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
test-static: tidy-check test-yaml-valid test-modules-in-yaml-schedule test-merge test-dry test-no-wait_idle test-deleted-renamed-referenced-files test-unused-modules-changed test-soft_failure-no-reference test-spec test-invalid-syntax test-code-style test-metadata test_pod_whitespace_rule

.PHONY: test
ifeq ($(TESTS),compile)
test: test-compile
else ifeq ($(TESTS),static)
test: test-static
else ifeq ($(TESTS),unit)
test: unit-test perlcritic
else ifeq ($(TESTS),isotovideo)
test: test-isotovideo
else
test: unit-test test-static test-compile test-isotovideo perlcritic
endif

PERLCRITIC=PERL5LIB=tools/lib/perlcritic:$$PERL5LIB perlcritic --stern --include "strict" --include Perl::Critic::Policy::HashKeyQuote \
  --verbose "::warning file=%f,line=%l,col=%c,title=%m - severity %s::%e\n"

.PHONY: perlcritic
perlcritic: tools/lib/
	${PERLCRITIC} $$(git ls-files -- '*.p[ml]' ':!:data/')

.PHONY: test-unused-modules-changed
test-unused-modules-changed:
	@echo "[make] Unused modules check called over modified/new files only. For a full run use make test-unused-modules-full"
	tools/detect_unused_modules -m ` (\
	git --no-pager diff --name-only --diff-filter=d origin/master | grep '^tests/*' | grep -v '^tests/test_pods/'; \
	git --no-pager diff --unified=0 origin/master products/* | sed -n "s~^-.*loadtest\s\+\([\"']\)\([^\"']\+\)\1.*~tests/\2.pm~p"; \
	git --no-pager diff --unified=0 origin/master schedule/* | sed -n "s~^-\s\+-\s\+\([\"']\)\([^\"']\+\)\1.*~tests/\2.pm~p" | grep -v '{{' ) \
	| sort -u`

.PHONY: test-unused-modules-full
test-unused-modules-full:
	tools/detect_unused_modules -a

.PHONY: test-deleted-renamed-referenced-files
test-deleted-renamed-referenced-files:
	tools/test_deleted_renamed_referenced_files `git diff --name-only --exit-code --diff-filter=DR origin/master | grep '^test*'`

.PHONY: test-soft_failure-no-reference
test-soft_failure-no-reference:
	@! git --no-pager grep -E -e 'record_soft_failure\>.*\;' --and --not -e '([a-zA-Z]+#[a-zA-Z-]*[0-9]+|fate.suse.com/[0-9]+|\$reference)' lib/ tests/

.PHONY: test-invalid-syntax
test-invalid-syntax:
	tools/check_invalid_syntax

.PHONY: test-code-style
test-code-style:
	tools/check_code_style

.PHONY: test-isotovideo
test-isotovideo:
	tools/test_isotovideo
