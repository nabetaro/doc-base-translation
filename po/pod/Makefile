# vim:ts=2
# makefile for doc-base
# $Id: Makefile 189 2009-04-26 22:57:37Z robert $
#

ALL_TARGET=build-local
SUBDIRS=
include ../../common.mk

SOURCE_FILES=$(shell sed -ne 's/^\[type: pod\] \$$(srcdir)\/\([^ ]*\)*.*$$/..\/..\/\1/p' < po4a.cfg)
build-local: $(bdir)/stamp-po4a
  
$(bdir)/stamp-po4a: po4a.cfg $(wildcard *.po) $(SOURCE_FILES) $(MAKEFILE_LIST)
	$(call msg,$@)
	po4a  $(XGETTEXT_COMMON_OPTIONS)          \
	      --previous                          \
	      -v                                  \
	      --variable srcdir=../..             \
	      --variable builddir=$(bdir)         \
	      po4a.cfg
	$(call podtoman,$(bdir))
	touch "$@"

install-local: $(bdir)/stamp-po4a
	$(call msg,$@)
	set -e; \
	cd $(bdir); \
	for file in */man*/*.pod; do                  \
	  basedir=`dirname $$file`;                   \
	  dir=$(mandir)/$$basedir;                    \
	  src=$$basedir/`basename $$file .pod`;       \
	  $(call install,$$dir,$$src,compress)        \
	done


update-po:
	$(call msg,$@)
	po4a  $(XGETTEXT_COMMON_OPTIONS)          \
	      --previous                          \
	      --force                             \
	      -v                                  \
	      --variable srcdir=../..             \
	      --variable builddir=$(bdir)         \
	      po4a.cfg


.PHONY: update-po
