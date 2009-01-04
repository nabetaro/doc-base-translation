# vim:ts=2
# makefile for doc-base
# $Id: Makefile 168 2009-01-04 16:10:53Z robert $
#

ALL_TARGET=build-local
SUBDIRS=
include ../../common.mk

NLS_SOURCES 		:= $(sort $(wildcard ../../perl/Debian/DocBase/*.pm ../../perl/Debian/DocBase/Programs/*.pm ../../install-docs.in))
POFILES					:= $(sort $(wildcard *.po))
MOFILES				  := $(patsubst %.po,$(bdir)/%.mo,$(POFILES))


build-local: $(MOFILES)
	$(call msg,$@)


install-local: $(MOFILES)
	$(call msg,$@)
	$(foreach file,$(MOFILES),	\
		$(call install,$(DESTDIR)$(nlsdir)/$(notdir $(basename $(file)))/LC_MESSAGES/$(PACKAGE).mo,$(file),notdir))

$(bdir)/%.mo: %.po
	$(call msg,$@)
	mkdir -p $(bdir)
	msgfmt  -o $@ $<

doc-base.pot:	$(NLS_SOURCES)
	$(call msg,$@)
	xgettext -L perl  -k -k_g -k_ng:1,2 $(XGETTEXT_COMMON_OPTIONS) -o $@.new $^
	$(call pochanged,$@,$@.new)

%.po: doc-base.pot
	$(call msg,$@)
	msgmerge --previous $@ $< > $@.new
	$(call pochanged,$@,$@.new)

update-po: $(POFILES)
	$(call msg,$@)


.PHONY: update-po
