# vim:ts=2
# makefile for doc-base
# $Id: Makefile 167 2009-01-04 12:24:45Z robert $
#

ALL_TARGET 		:= build-local
AFTER_INSTALL	:= $(call check_install)
SUBDIRS		 		:= doc data perl po
include 			common.mk

x:=$(subst /, ,$(abspath $(DESTDIR)))
x1:=$(strip $x)

generated 		:= $(bdir)/man/man8/install-docs.8	\
						 		$(bdir)/check-stamp							\
  					 		$(bdir)/install-docs.html				\
  					 		$(bdir)/install-docs						

$(ALL_TARGET): $(generated) | $(bdir)



$(bdir)/check-stamp: $(bdir)/install-docs
	@echo; echo "*** Creating $@:"
	PERL5LIB="perl" perl -cw $(bdir)/install-docs
	touch $@


$(bdir)/install-docs: install-docs.in $(CHANGELOGFILE) | $(bdir)
	@echo; echo "*** Creating $@:"
	sed -e '/#LINE_REMOVED_BY_MAKE#/d'   \
	    -e 's/#VERSION#/$(VERSION)/' \
	    < $< > $@
	chmod 755 $@

$(bdir)/man/man8/install-docs.8: $(bdir)/install-docs $(bdir)/check-stamp
	@echo; echo "*** Creating $@:"
	mkdir -p $(dir $@)
	cp $< $@.pod
	$(call podtoman,$(bdir)/man)

$(bdir)/install-docs.html: $(bdir)/install-docs $(bdir)/check-stamp
	@echo; echo "*** Creating $@:"
	cd $(bdir) && \
	pod2html --title "install-docs reference" \
	  < $(notdir $<) > $(notdir $@)

define check_install
	echo checking_installation; \
	PERL5LIB=$(DESTDIR)/$(perldir)      perl -cw $(DESTDIR)$(sbindir)/install-docs
endef

install-local: $(generated) 
	$(install_dir)                           $(DESTDIR)$(sbindir)
	$(install_script) $(bdir)/install-docs   $(DESTDIR)$(sbindir)

	$(install_dir)                            $(DESTDIR)$(omfdir)
	$(install_dir)                            $(DESTDIR)$(libdir)/omf
	$(install_dir)                            $(DESTDIR)$(libdir)/info
	rm -f                                     $(DESTDIR)$(omfdir)/doc-base
	$(install_link) $(libdir)/omf             $(DESTDIR)$(omfdir)/doc-base

	$(install_dir)                            $(DESTDIR)$(mandir)/man8
	$(install_file) $(bdir)/man/man8/install-docs.8  $(DESTDIR)$(mandir)/man8
	$(compress)                               $(DESTDIR)$(mandir)/man8/install-docs.8

	$(install_dir)                            $(DESTDIR)$(docdir)
	$(install_file) $(bdir)/install-docs.html $(DESTDIR)$(docdir)

