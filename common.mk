# vim:ts=2
# common includes for doc-base
# $Id: common.mk 167 2009-01-04 12:24:45Z robert $
#
# determine our version number


getCurrentMakefileName := $(CURDIR)/$(lastword $(MAKEFILE_LIST))
override TOPDIR	  := $(dir $(call getCurrentMakefileName))

override PACKAGE	:= doc-base
ifndef VERSION
  CHANGELOGFILE     := $(TOPDIR)/debian/changelog 
  VERSION           := $(shell LC_ALL=C dpkg-parsechangelog -l$(CHANGELOGFILE) \
                        | sed -ne 's/^Version: *//p')
  DATE              := $(shell LC_ALL=C dpkg-parsechangelog -l$(CHANGELOGFILE) \
                        | sed -n 's/^Date: *//p')
  # pretty-print the date; I wish this was dynamic like the top-level makefile but oh well
  DATE_EN           := $(shell LC_ALL=C date --date="$(DATE)" '+%d %B, %Y')

  export VERSION DATE DATE_EN
  unexport CDPATH

  ifdef DESTDIR
    ifneq ($(DESTDIR),$(abspath $(DESTDIR)))
      $(error DESTDIR "$(DESTDIR)" is not an absolute path)
    endif
  endif

endif

#ifdef DESTDIR
#ifneq ($(strip $(subst /, ,$(abspath($DESTDIR))),$(subst /, ,$(abspath $(DESTDIR)))


XGETTEXT_COMMON_OPTIONS	 := --msgid-bugs-address $(PACKAGE)@packages.debian.org	\
														--package-name $(PACKAGE)		   											\
														--package-version $(VERSION)												
				
		
sdir            := $(CURDIR)
ifndef bdir
ifneq (,$(ALL_TARGET))
bdir            := _build
else
bdir						:=
endif
endif

# build abstraction
install_file    := install -p -o root -g root -m 644
install_script  := install -p -o root -g root -m 755
install_dir     := install -d -o root -g root -m 755
install_link    := ln -sf
compress        := gzip -9f

prefix          := /usr
etcdir          := /etc/doc-base
sbindir         := $(prefix)/sbin
mandir          := $(prefix)/share/man
sharedir        := $(prefix)/share/doc-base
perllibdir      := $(prefix)/share/perl5
docdir          := $(prefix)/share/doc/doc-base
libdir          := /var/lib/doc-base
omfdir          := $(prefix)/share/omf
nlsdir					:= $(prefix)/share/locale


define pochanged
	set -x; \
  [ ! -e $(1) ] && rename=1 || rename=0	;	\
	if [ $$rename = 0 ] ; then		\
		diff=`diff -q  -I'POT-Creation-Date:' -I'PO-Revision-Date:' $(1) $(2)`; \
		[ -z "$$diff" ] || rename=1	; \
	fi; \
	[ $$rename = 1 ] && mv -f $(2) $(1) || rm -f $(2); 
  touch $(1) 
endef

define recurse
	set -ex; \
	for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir $(1); \
	done
endef
# recurse := $(foreach subdir,$(SUBDIRS),$(shell $(MAKE) -C $(subdir) $1))

define podtoman
		set -ex; 																										\
		find $1 -type f -name '*.pod' -path '*/man*' 								\
		| while read file; do																				\
			sed -ne '1i=encoding utf8\n' -e '/^=head1/,$$p'  < $$file \
			| pod2man --utf8 --section=8 --center="Debian"    				\
	  		--release="$(PACKAGE) v$(VERSION)"            					\
	  		--date="$(DATE_EN)"                           					\
				--name="INSTALL-DOCS"																		\
	  	> `dirname $$file`/`basename $$file .pod`;								\
	done
endef


all: $(ALL_TARGET) | $(bdir)
	$(call recurse,$@)

clean-local:

install-local:

clean: clean-local
	test -z "$(bdir)" || rm -rf $(bdir)
	$(call recurse,$@)

install: install-local
	$(call recurse,$@)
	$(AFTER_INSTALL)

$(bdir):
	test -z "$(bdir)" || mkdir -p $(bdir)

# debug
print-%:
	 @echo "$* is >>$($*)<<"

.PHONY: all clean install $(ALL_TARGET) clean-local install-local
.DEFAULT: all

