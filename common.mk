# vim:ts=2:et
# common includes for doc-base
# $Id: common.mk 168 2009-01-04 16:10:53Z robert $
#
# determine our version number


getCurrentMakefileName := $(CURDIR)/$(lastword $(MAKEFILE_LIST))
override TOPDIR   := $(dir $(call getCurrentMakefileName))

override PACKAGE  := doc-base

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
nlsdir          := $(prefix)/share/locale

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

sdir            := $(CURDIR)
ifndef bdir
  ifneq (,$(ALL_TARGET))
    bdir        := _build
  else
    bdir        :=
  endif
endif

ifndef DIR
  DIR           := $(notdir $(CURDIR))
endif

XGETTEXT_COMMON_OPTIONS   := --msgid-bugs-address $(PACKAGE)@packages.debian.org  \
                            --package-name $(PACKAGE)                           \
                            --package-version $(VERSION)



ifndef MAKE_VERBOSE
  override MAKEFLAGS      += --silent --no-print-directory
  define msg
    case "$1" in                                                \
      ""|all|all-local|build-local)                             \
        ;;                                                      \
      install|install-local)                                    \
        echo "$(msgprefix) Installing files from $(DIR) ..." ;  \
        ;;                                                      \
      clean|clean-local)                                        \
        echo "$(msgprefix) Cleaning $(DIR) ..."                 \
        ;;                                                      \
      *)                                                        \
        echo "$(msgprefix) Making $(DIR)$(1) ..."               \
        ;;                                                      \
    esac
  endef
endif

msgprefix         := *$(subst * ,*,$(wordlist 1,$(MAKELEVEL),* * * * * * * * * * * * * * * * * *))
emptyprefix       := $(subst *, ,$(msgprefix))


#SHELL:=/bin/echo
# install(dir/link_target,files,mode=compress|script|link|notdir)
define install
  set -e;                                                           \
  [ "$3" = "notdir" ] && dir="`dirname "$1"`" || dir="$1";          \
  if [ -z "$2" ]; then                                              \
    echo "$(emptyprefix) installing dir    $$dir";                  \
    $(install_dir) "$$dir";                                         \
  else for file in $2; do                                           \
    [ "$3" = "notdir" ] && bfile="`basename $1`" ||                 \
                           bfile=`basename "$$file"`;               \
    target="$$dir/$$bfile" ;                                        \
    [ "$3" = "link" ] || $(install_dir) "$$dir";                    \
    if [ "$3" = "script" ] ; then                                   \
      echo "$(emptyprefix) installing script $$target";             \
      $(install_script) "$$file" "$$target";                        \
    elif [ "$3" = "link" ] ; then                                   \
      echo "$(emptyprefix) installing link   $$file";               \
      rm -f "$$file";                                               \
      $(install_link) "$1" "$$file";                                \
    else                                                            \
      echo "$(emptyprefix) installing file   $$target";             \
      $(install_file) "$$file" "$$target";                          \
      if [ "$3" = "compress" ]; then                                \
        echo "$(emptyprefix) compressing file  $$target";           \
        $(compress) "$$target";                                     \
      fi                                                            \
    fi                                                              \
  done                                                              \
  fi
endef



define pochanged
  set -e;                                                                   \
  [ ! -e $(1) ] && rename=1 || rename=0 ;                                   \
  if [ $$rename = 0 ] ; then                                                \
    diff=`diff -q  -I'POT-Creation-Date:' -I'PO-Revision-Date:' $(1) $(2)`; \
    [ -z "$$diff" ] || rename=1 ;                                           \
  fi;                                                                       \
  [ $$rename = 1 ] && mv -f $(2) $(1) || rm -f $(2);                        \
  touch $(1)
endef

define recurse
  set -e;                                                                 \
  for dir in $(SUBDIRS); do                                               \
    $(MAKE) -C $$dir DIR=$(DIR)/$$dir $(1);                               \
  done
endef

define podtoman
    set -e;                                                     \
    find $(1) -type f -name '*.pod' -path '*/man*'                \
    | while read file; do                                       \
      sed -ne '1i=encoding utf8\n' -e '/^=head1/,$$p'  < $$file \
      | pod2man --utf8 --section=8 --center="Debian"            \
        --release="$(PACKAGE) v$(VERSION)"                      \
        --date="$(DATE_EN)"                                     \
        --name="INSTALL-DOCS"                                   \
      > `dirname $$file`/`basename $$file .pod`;                \
  done
endef


all: $(ALL_TARGET) | $(bdir)
	$(call recurse,$@)

clean-local:

install-local:

clean: clean-local
	test -z "$(bdir)" || $(call msg,$@)
	test -z "$(bdir)" || rm -rf $(bdir)
	$(call recurse,$@)

install: install-local
	$(call recurse,$@)
	$(AFTER_INSTALL)

$(bdir):
	$(call createmsg,$@)
	test -z "$(bdir)" || mkdir -p $(bdir)

# debug
print-%:
	 @echo "$* is >>$($*)<<"

.PHONY: all clean install $(ALL_TARGET) clean-local install-local
.DEFAULT: all

