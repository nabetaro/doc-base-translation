# vim:ts=2
# makefile for doc-base
# $Id: Makefile 178 2009-01-11 14:14:16Z robert $
#

ALL_TARGET    := build-local
AFTER_INSTALL := $(call check_install)
SUBDIRS       := doc data perl po
include       common.mk

x:=$(subst /, ,$(abspath ))
x1:=$(strip $x)

generated     := $(bdir)/man/man8/install-docs.8  \
                $(bdir)/check-stamp             \
                $(bdir)/install-docs.html       \
                $(bdir)/install-docs

$(ALL_TARGET): $(generated) | $(bdir)



$(bdir)/check-stamp: $(bdir)/install-docs
	$(call msg,$@)
	PERL5LIB="perl" perl -cw $(bdir)/install-docs
	touch $@


$(bdir)/install-docs: install-docs.in $(CHANGELOGFILE) | $(bdir)
	$(call msg,$@)
	sed -e '/#LINE_REMOVED_BY_MAKE#/d'   \
	    -e 's/#VERSION#/$(VERSION)/' \
	    < $< > $@
	chmod 755 $@

$(bdir)/man/man8/install-docs.8: $(bdir)/install-docs $(bdir)/check-stamp
	$(call msg,$@)
	mkdir -p $(dir $@)
	cp $< $@.pod
	$(call podtoman,$(bdir)/man)

$(bdir)/install-docs.html: $(bdir)/install-docs $(bdir)/check-stamp
	$(call msg,$@)
	cd $(bdir) && \
	pod2html --title "install-docs reference" \
	  < $(notdir $<) > $(notdir $@)

define check_install
	echo checking_installation; \
	PERL5LIB=$(perldir)      perl -cw $(sbindir)/install-docs
endef

install-local: $(generated)
	$(call msg,$@)
	$(call install,$(sbindir),$(bdir)/install-docs,script)
	$(call install,$(omfdir),,)
	$(call install,$(libdir)/omf,,)
	$(call install,$(libdir)/info,,)
	$(call install_links,$(libdir)/omf,$(omfdir)/doc-base)
	$(call install,$(mandir)/man8,$(bdir)/man/man8/install-docs.8,compress)
	$(call install,$(docdir),$(bdir)/install-docs.html)

