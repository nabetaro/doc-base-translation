# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Common.pm 43 2007-04-12 17:28:48Z robert $
#

package Debian::DocBase::Common;

use Exporter();
use strict;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(DATA_DIR do_dwww_update warn_nonexistent_files supported_formats need_index_formats);

our $DATA_DIR = "/var/lib/doc-base/info";

our $do_dwww_update = 1;
our  $warn_nonexistent_files = 0;


# All formats handled by the doc-base
our @supported_formats =  (
                            'html',
                            'text',
                            'pdf',
                            'postscript',
                            'info',
                            'dvi',
                            'debiandoc-sgml'
                      );

# Formats which need the Index: field
our @need_index_formats = (
                            'html',
                            'info'
                         );


# ---end-of-configuration-part---

1;
