# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Common.pm 63 2007-04-28 22:41:18Z robert $


package Debian::DocBase::Common;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw($DATA_DIR  $CONTROL_DIR @supported_formats @need_index_formats
              $verbose $debug);

our $DATA_DIR = "/var/lib/doc-base/info";
our $CONTROL_DIR = "/usr/share/doc-base";

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


our $verbose = 0;
our $debug   = 0;


1;
