# vim:ts=2
# makefile for doc-base
# $Id: Makefile 167 2009-01-04 12:24:45Z robert $
#

ALL_TARGET := build-local
SUBDIRS		 := 
include ../common.mk

generated := $(bdir)/version.ent							\
						 $(bdir)/doc-base.sgml						\
						 $(bdir)/doc-base.txt 						\
						 $(bdir)/doc-base.html/index.html \
						 $(bdir)/check-stamp							\
						 $(bdir)/section.list

$(ALL_TARGET): $(generated) | $(bdir)


$(bdir)/doc-base.sgml: doc-base.sgml | $(bdir)
	@echo; echo "*** Creating $@:"
	cp -f $< $@
	touch -r $< $@

$(bdir)/check-stamp: $(bdir)/doc-base.sgml $(bdir)/version.ent
	nsgmls -wall -s -E20 $(bdir)/doc-base.sgml	# check SGML syntax
	touch $@

$(bdir)/doc-base.txt: $(bdir)/doc-base.sgml $(bdir)/version.ent $(bdir)/check-stamp
	@echo; echo "*** Creating $@:"
	cd $(bdir) && debiandoc2text $(<F)

$(bdir)/doc-base.html/%: $(bdir)/doc-base.sgml $(bdir)/version.ent $(bdir)/check-stamp
	@echo; echo "*** Creating $(@D):"
	cd $(bdir) && debiandoc2html $(<F)

$(bdir)/version.ent: $(bdir)/doc-base.sgml $(CHANGELOGFILE) $(MAKEFILESLIST) | $(bdir)
	@echo; echo "*** Creating $@:"
	echo "<!ENTITY version \"$(VERSION)\">"    > $@.new
	echo "<!ENTITY date    \"$(DATE_EN)\">"    >> $@.new
	mv -f $@.new $@

$(bdir)/section.list: doc-base.sgml | $(bdir)
	@echo; echo "*** Creating $@:"
	perl -e  \
	   'exec ("'perl'", "-ne", join("",@ARGV)) if $$#ARGV >-1;                    '\
	   '      last                    if /<!--\s*section\s+list\s+end\s*-->/;     '\
	   '      $$insect=1              if /<!--\s*section\s+list\s+begin\s*-->/;   '\
	   '      next                    unless $$insect;                            '\
	   '      s/item>/tag>/g          if $$inlst;                                 '\
	   '      $$inlst = 1             if s/<list>/<taglist>/;                     '\
	   '      $$inlst = 0             if s/<\/list>/<\/taglist>/;                 '\
	   '      $$top .= ($$sect . "/") if /<taglist>/ and $$sect;                  '\
	   '      $$top =~ s/[^\/]+\/$$// if /<\/taglist>/;                           '\
	   '      $$sect = $$1            if (/<tag>(?:(?:<\w+[>\/])*?)\s*([^<>\/]+)\s*(.*?)<\/tag>/);  '\
	   '      print "$$top$$sect\n"   if /<tag>/ && !/<!--\s*skip\s*-->/;         '\
	 < $< > $@.tmp
	 touch -r $< $@.tmp
	 mv $@.tmp $@

install-local: $(generated) 
	$(install_dir)                            $(DESTDIR)$(docdir)
	$(install_file) $(bdir)/version.ent       $(DESTDIR)$(docdir)
	$(install_file) doc-base.sgml             $(DESTDIR)$(docdir)
	$(compress)                               $(DESTDIR)$(docdir)/doc-base.sgml

	$(install_file) $(bdir)/doc-base.txt      $(DESTDIR)$(docdir)
	$(compress)                               $(DESTDIR)$(docdir)/doc-base.txt

	$(install_dir)                            $(DESTDIR)$(docdir)/doc-base.html
	$(install_file) $(bdir)/doc-base.html/*   $(DESTDIR)$(docdir)/doc-base.html

	$(install_dir)  $(DESTDIR)$(sharedir)/data/
	$(install_file) $(bdir)/section.list      $(DESTDIR)$(sharedir)/data/
