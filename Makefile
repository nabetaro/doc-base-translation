# vim:ts=2
# makefile for doc-base
# $Id: Makefile 75 2007-05-06 12:45:36Z robert $
#
# determine our version number
DEB_VERSION     := $(shell LC_ALL=C dpkg-parsechangelog | grep ^Version: | sed 's/^Version: *//')
DEB_DATE        := $(shell dpkg-parsechangelog | sed -n 's/^Date: *//p')
# pretty-print the date; I wish this was dynamic like the top-level makefile but oh well
DATE_EN         := $(shell LC_ALL=C     date --date="$(DEB_DATE)" '+%d %B, %Y')

bdir            := build
sdir            := $(CURDIR)
generated       := $(bdir)/install-docs \
                   $(bdir)/install-docs.8 \
                   $(bdir)/install-docs.html \
                   $(bdir)/doc-base.txt \
                   $(bdir)/doc-base.html/index.html


# build abstraction
install_file    := install -p -o root -g root -m 644
install_script  := install -p -o root -g root -m 755
install_dir     := install -d -o root -g root -m 755 
install_link    := ln -sf
compress        := gzip -9f

prefix          := /usr
sbindir         := $(prefix)/sbin
mandir          := $(prefix)/share/man/man8
sharedir        := $(prefix)/share/doc-base
perldir         := $(prefix)/share/perl5/Debian/DocBase
docdir          := $(prefix)/share/doc/doc-base
libdir          := /var/lib/doc-base
omfdir          := $(prefix)/share/omf



all: $(generated)


$(bdir):
	@echo; echo "*** Creating $@:"
	mkdir -p $@

$(bdir)/doc-base.sgml: doc-base.sgml | $(bdir)
	@echo; echo "*** Creating $@:"
	cp -f $< $@

$(bdir)/check-stamp: $(bdir)/install-docs $(bdir)/doc-base.sgml $(bdir)/version.ent
	@echo; echo "*** Creating $@:"
	PERL5LIB="perl" perl -cw $(bdir)/install-docs
	nsgmls -wall -s -E20 $(bdir)/doc-base.sgml	# check SGML syntax
	touch $@


$(bdir)/install-docs: install-docs.in | $(bdir)
	@echo; echo "*** Creating $@:"
	sed -e '/use lib.*perl/d' \
	    -e 's/#VERSION#/$(DEB_VERSION)/' \
	    < $< > $@
	chmod 755 $@

$(bdir)/install-docs.8: $(bdir)/install-docs $(bdir)/check-stamp
	@echo; echo "*** Creating $@:"
	pod2man --section=8 --center="Debian Utilities"		\
		--release="doc-base v$(DEB_VERSION)"						\
		--date="$(DATE_EN)"															\
		$< > $@ 

$(bdir)/install-docs.html: $(bdir)/install-docs $(bdir)/check-stamp
	@echo; echo "*** Creating $@:"
	pod2html --title "install-docs reference" 		\
		< $< > $@
	rm -f pod2htm*.tmp

$(bdir)/doc-base.txt: $(bdir)/doc-base.sgml $(bdir)/version.ent $(bdir)/check-stamp
	@echo; echo "*** Creating $@:"
	cd $(bdir) && debiandoc2text $(<F)

$(bdir)/doc-base.html/%: $(bdir)/doc-base.sgml $(bdir)/version.ent $(bdir)/check-stamp
	@echo; echo "*** Creating $(@D):"
	cd $(bdir) && debiandoc2html $(<F)

$(bdir)/version.ent: $(bdir)/doc-base.sgml debian/changelog | $(bdir)
	@echo; echo "*** Creating $@:"
	echo "<!ENTITY version \"$(DEB_VERSION)\">"    > $@
	echo "<!ENTITY date    \"$(DATE_EN)\">"        >> $@

clean:
	rm -rf build-stamp version.ent $(bdir)
	rm -f `find . -name "*~"`


install: $(generated)
	@echo; echo "*** Installing script and perl libraries:"
	$(install_dir)                           $(DESTDIR)$(sbindir)
	$(install_script) $(bdir)/install-docs   $(DESTDIR)$(sbindir)

	$(install_dir)                           $(DESTDIR)$(perldir)
	$(install_file) perl/Debian/DocBase/*.pm $(DESTDIR)$(perldir)
	$(install_dir)                           $(DESTDIR)$(perldir)/Programs
	$(install_file) perl/Debian/DocBase/Programs/*.pm \
	                                         $(DESTDIR)$(perldir)/Programs

	@echo; echo "*** Checking the script:"
	# validate installation correctness                                              
	PERL5LIB=$(DESTDIR)$(perldir)/../..      perl -cw $(DESTDIR)$(sbindir)/install-docs


	@echo; echo "*** Installing control files and data:"
	$(install_dir)                           $(DESTDIR)$(sharedir)
	$(install_file) data/doc-base.desc       $(DESTDIR)$(sharedir)/doc-base
	$(install_file) data/install-docs.desc   $(DESTDIR)$(sharedir)/install-docs-man


	$(install_dir)                           $(DESTDIR)$(sharedir)/data
	$(install_file) data/scrollkeeper.map    $(DESTDIR)$(sharedir)/data/


	$(install_dir)                           $(DESTDIR)$(omfdir)
	$(install_dir)                           $(DESTDIR)$(libdir)/omf
	$(install_dir)                           $(DESTDIR)$(libdir)/info
	rm -f                                    $(DESTDIR)$(omfdir)/doc-base
	$(install_link) $(libdir)/omf            $(DESTDIR)$(omfdir)/doc-base


	@echo; echo "*** Installing docs:"
	$(install_dir)                           $(DESTDIR)$(mandir)
	$(install_file) $(bdir)/install-docs.8   $(DESTDIR)$(mandir)
	$(compress)                              $(DESTDIR)$(mandir)/install-docs.8

	$(install_dir)                           $(DESTDIR)$(docdir)
	$(install_file) $(bdir)/version.ent      $(DESTDIR)$(docdir)
	$(install_file) doc-base.sgml            $(DESTDIR)$(docdir)
	$(compress)                              $(DESTDIR)$(docdir)/doc-base.sgml

	$(install_file) $(bdir)/doc-base.txt     $(DESTDIR)$(docdir)
	$(compress)                              $(DESTDIR)$(docdir)/doc-base.txt
	$(install_file) $(bdir)/install-docs.html \
   	                                       $(DESTDIR)$(docdir)

	$(install_dir)                           $(DESTDIR)$(docdir)/doc-base.html
	$(install_file) $(bdir)/doc-base.html/*  $(DESTDIR)$(docdir)/doc-base.html

.PHONY: install clean all