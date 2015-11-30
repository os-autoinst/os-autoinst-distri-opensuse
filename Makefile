test:
	test -d os-autoinst
	test -e tools || ln -s os-autoinst/tools .
	tools/tidy --check
	export PERL5LIB="../..:os-autoinst:lib:tests/installation:tests/x11:tests/qa_automation:$$PERL5LIB" ; for f in `find . -name \*.pm|grep -v /os-autoinst/` ; do perl -c $$f 2>&1 | grep -v " OK$$" && exit 2; done ; true

.PHONY: test
