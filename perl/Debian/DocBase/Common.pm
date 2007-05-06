# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Common.pm 73 2007-05-06 10:54:35Z robert $


package Debian::DocBase::Common;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw($DATA_DIR  $CONTROL_DIR @supported_formats @need_index_formats
              $opt_verbose $opt_debug $exitval $opt_rootdir $opt_update_menus);

our $DATA_DIR = "/var/lib/doc-base/info";
our $CONTROL_DIR = "/usr/share/doc-base";


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


our $opt_verbose      = 0;
our $opt_debug        = 0;
our $opt_update_menus = 1;
our $opt_rootdir      = "";
our $exitval          = 0;


1;
