# vim:ts=2
# makefile for doc-base
# $Id: Makefile 223 2011-02-28 23:34:22Z robert $
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
		$(call install,$(nlsdir)/$(notdir $(basename $(file)))/LC_MESSAGES/$(PACKAGE).mo,$(file),notdir))

$(bdir)/%.mo: %.po
	$(call msg,$@)
	mkdir -p $(bdir)
	msgfmt  -o $@ $<

$(PACKAGE).pot:	$(NLS_SOURCES) | $(MAKEFILE_LIST)
	$(call msg,$@)
	xgettext -L perl  -cTranslators: -k -k_g -k_ng:1,2 $(XGETTEXT_COMMON_OPTIONS) -o $@.new $^
	$(call pochanged,$@,$@.new)

%.po: $(PACKAGE).pot
	$(call msg,$@)
	msgmerge --previous $@ $< > $@.new
	$(call pochanged,$@,$@.new)

update-po: 
	$(call msg,$@)
	$(MAKE) -W $(firstword $(NLS_SOURCES)) $(POFILES) 


.PHONY: update-po
