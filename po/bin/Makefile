# vim:ts=2
# makefile for doc-base
# $Id: Makefile 167 2009-01-04 12:24:45Z robert $
#

ALL_TARGET=build-local
SUBDIRS=
include ../../common.mk

NLS_SOURCES 		:= $(sort $(wildcard ../../perl/Debian/DocBase/*.pm ../../perl/Debian/DocBase/Programs/*.pm ../../install-docs.in))
POFILES					:= $(sort $(wildcard *.po))
MOFILES				  := $(patsubst %.po,$(bdir)/%.mo,$(POFILES))


build-local: $(MOFILES)


install-local: $(MOFILES)
	set -e; \
	for file in $(MOFILES) ; do \
		dir=$(DESTDIR)$(nlsdir)/`basename $$file .mo`/LC_MESSAGES; \
		$(install_dir)													$$dir; \
		$(install_file) $$file 									$$dir/doc-base.mo ; \
	done

$(bdir)/%.mo: %.po
	mkdir -p $(bdir)
	msgfmt  -o $@ $<

doc-base.pot:	$(NLS_SOURCES)
	xgettext -L perl  -k -k_g -k_ng:1,2 $(XGETTEXT_COMMON_OPTIONS) -o $@.new $^
	$(call pochanged,$@,$@.new)

%.po: doc-base.pot
	msgmerge --previous $@ $< > $@.new
	$(call pochanged,$@,$@.new)

update-po: $(POFILES)


.PHONY: update-po
