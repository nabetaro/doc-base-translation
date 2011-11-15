# vim:ts=2:et
# common includes for doc-base
#
getCurrentMakefileName := $(CURDIR)/$(lastword $(MAKEFILE_LIST))
override TOPDIR   := $(dir $(call getCurrentMakefileName))

override PACKAGE  := doc-base

PATH            := /usr/bin:/usr/sbin:/bin:/sbin:$(PATH)

# build abstraction
install_file    := install -p -o root -g root -m 644
install_script  := install -p -o root -g root -m 755
install_dir     := install -d -o root -g root -m 755
install_link    := ln -sf
compress        := gzip -9f

prefix          := /usr
etcdir          := /etc/$(PACKAGE)
sbindir         := $(prefix)/sbin
mandir          := $(prefix)/share/man
sharedir        := $(prefix)/share/$(PACKAGE)
perllibdir      := $(prefix)/share/perl5
docdir          := $(prefix)/share/doc/$(PACKAGE)
libdir          := /var/lib/$(PACKAGE)
omfdir          := $(prefix)/share/omf
nlsdir          := $(prefix)/share/locale

# determine our version number

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
    override ddirshort  :=  DESTDIR
    export ddirshort
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
  DIR           := .
endif

XGETTEXT_COMMON_OPTIONS   := --msgid-bugs-address $(PACKAGE)@packages.debian.org  \
                            --package-name $(PACKAGE)                             \
                            --package-version $(VERSION)                          \
                            --copyright-holder='Robert Luberda <robert@debian.org>'



ifndef MAKE_VERBOSE
  override MAKEFLAGS      += --silent --no-print-directory
  define msg
    case "$1" in                                                \
      ""|all|all-local|build-local)                             \
        ;;                                                      \
      install|install-local)                                    \
        echo "$(msgprefix) Installing files from $(DIR) ..." ;  \
        [ -z "$(DESTDIR)" ] ||                                  \
          echo "$(msgprefix)   (DESTDIR=$(DESTDIR))";           \
        ;;                                                      \
      clean|clean-local)                                        \
        echo "$(msgprefix) Cleaning $(DIR) ..."                 \
        ;;                                                      \
      *)                                                        \
        echo "$(msgprefix) Making $(DIR)/$(1) ..."              \
        ;;                                                      \
    esac
  endef
else
  msg := :
endif

msgprefix         := *$(subst * ,*,$(wordlist 1,$(MAKELEVEL),* * * * * * * * * * * * * * * * * *))
emptyprefix       := $(subst *, ,$(msgprefix))


#SHELL:=/bin/echo
# install(dir,files,mode=compress|script|notdir)
define install
  set -e;                                                           \
  tgt="$1"; dir="$1"; files="$2";  prg="$(install_file)";           \
  doCompress=0;  bfile=""; what="file  ";                           \
  set -- $3;                                                        \
  while [ "$$1" ] ; do                                              \
    if [ "$$1" = "notdir" ] ; then                                  \
      dir="`dirname "$$dir"`";                                      \
      bfile="`basename "$$tgt"`";                                   \
    elif [ "$$1" = "compress" ] ; then                              \
      doCompress=1;                                                 \
    elif [ "$$1" = "script" ] ; then                                \
      prg="$(install_script)";                                      \
      what="script";                                                \
    fi;                                                             \
    shift;                                                          \
  done;                                                             \
  [ -n "$$files" ] ||                                               \
    echo "$(emptyprefix) installing dir    $(ddirshort)$$dir";      \
  $(install_dir) "$(DESTDIR)/$$dir";                                \
  for file in $$files; do                                           \
      [ -n "$$bfile" ] && tgt="$$dir/$$bfile"  ||                   \
        tgt="$$dir/`basename "$$file"`";                            \
      echo "$(emptyprefix) installing $$what $(ddirshort)$$tgt";    \
      $$prg "$$file" "$(DESTDIR)/$$tgt";                            \
      if [ "$$doCompress" -eq 1 ] ; then                            \
        echo "$(emptyprefix) compressing file  $(ddirshort)$$tgt";  \
        $(compress) "$(DESTDIR)/$$tgt";                             \
      fi;                                                           \
  done;
endef

# install(link_target,files)
define install_links
  set -e;                                                          \
  for file in $2; do                                               \
    echo "$(emptyprefix) installing link   $(ddirshort)$$file";    \
    $(install_dir) $(DESTDIR)/`dirname "$$file"`;                  \
    rm -f "$(DESTDIR)/$$file";                                     \
    $(install_link) "$1" "$(DESTDIR)/$$file";                      \
  done
endef


define pochanged
  set -e;                                                                       \
  [ ! -e $(1) ] && rename=1 || rename=0 ;                                       \
  if [ $$rename = 0 ] ; then                                                    \
    diff -q  -I'POT-Creation-Date:' -I'PO-Revision-Date:' $(1) $(2) >/dev/null  \
      ||  rename=1;                                                             \
  fi;                                                                           \
  [ $$rename = 1 ] && mv -f $(2) $(1) || rm -f $(2);                            \
  touch $(1)
endef

define recurse
  set -e;                                                                 \
  for dir in $(SUBDIRS); do                                               \
    $(MAKE) -C "$$dir" DIR="$(DIR)/$$dir" $(1);                               \
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
	$(call msg,$@)
	test -z "$(bdir)" || mkdir -p $(bdir)

# debug
print-%:
	 @echo "$* is >>$($*)<<"

.PHONY: all clean install $(ALL_TARGET) clean-local install-local
.DEFAULT: all

