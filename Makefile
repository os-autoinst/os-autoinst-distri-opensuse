PERL5LIB:="../..:os-autoinst:lib:tests/installation:tests/x11:tests/qa_automation:tests/virt_autotest:$$PERL5LIB"

.PHONY: all
all:

.PHONY: help
help:
	echo "Call 'make test' to call tests"

.PHONY: prepare
prepare:
	git clone git://github.com/os-autoinst/os-autoinst
	ln -s os-autoinst/tools .
	cd os-autoinst && cpanm -nq --installdeps .
	cpanm -nq --installdeps .

os-autoinst/:
	@test -d os-autoinst || (echo "Missing test requirements, \
link a local working copy of 'os-autoinst' into this \
folder or call 'make prepare' to install download a copy necessary for \
testing" && exit 2)

tools/: os-autoinst/
	@test -e tools || ln -s os-autoinst/tools .

.PHONY: check-links
check-links: tools/ os-autoinst/

.PHONY: check-links
tidy: check-links
	tools/tidy --check

.PHONY: test-compile
test-compile: check-links
	export PERL5LIB=${PERL5LIB} ; for f in `git ls-files "*.pm" || find . -name \*.pm|grep -v /os-autoinst/` ; do perl -c $$f 2>&1 | grep -v " OK$$" && exit 2; done ; true

.PHONY: test-compile-changed
test-compile-changed: tools/
	export PERL5LIB=${PERL5LIB} ; for f in `git diff --name-only | grep '.pm'` ; do perl -c $$f 2>&1 | grep -v " OK$$" && exit 2; done ; true

.PHONY: test
test: tidy test-compile

.PHONY: perlcritic
perlcritic: check-links
	PERL5LIB=tools/lib/perlcritic:$$PERL5LIB perlcritic --quiet --gentle --include Perl::Critic::Policy::HashKeyQuote .
