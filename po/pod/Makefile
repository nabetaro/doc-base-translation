# vim:ts=2
# makefile for doc-base
# $Id: Makefile 167 2009-01-04 12:24:45Z robert $
#

ALL_TARGET=build-local
SUBDIRS=
include ../../common.mk

SOURCE_FILES=$(shell set -x ; sed -ne 's/^\[type: pod\] \$$(srcdir)\/\([^ ]*\)*.*$$/..\/..\/\1/p' < po4a.cfg)
build-local: $(bdir)/stamp-po4a
	
$(bdir)/stamp-po4a: po4a.cfg $(wildcard %.po) $(SOURCE_FILES) $(MAKEFILE_LIST)
	po4a  $(XGETTEXT_COMMON_OPTIONS) \
			 	--previous \
 			 	-k0 -v 		\
			 	--variable srcdir=../.. 	\
				--variable builddir=$(bdir) \
				po4a.cfg
	$(call podtoman,$(bdir))
	touch "$@"

install-local: $(bdir)/stamp-po4a
	set -e; \
	cd $(bdir); \
	for file in */man*/*.pod; do 									\
		basedir=`dirname $$file`;										\
		basefile=`basename $$file .pod`;						\
		dir=$(DESTDIR)/$(mandir)/$$basedir; 				\
		$(install_dir)  $$dir;										  \
		$(install_file) $$basedir/$$basefile $$dir;	\
		$(compress)			$$dir/$$basefile;						\
	done


.PHONY:  update-bin-po
