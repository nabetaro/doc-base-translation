# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Dwww.pm 73 2007-05-06 10:54:35Z robert $
#

package Debian::DocBase::Programs::Dwww;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(RegisterDwww);

use Debian::DocBase::Common;
use Debian::DocBase::Utils;

our $dwww_update = "/usr/bin/update-menus";
our $dwww_build_menu = "/usr/sbin/dwww-build-menu";

# Registering to dwww:
sub RegisterDwww { # {{{
  my @documents = @_;
  $#documents < 0 and return;

  if (-e $dwww_build_menu) {
    &Execute($dwww_update) if $opt_update_menus;
  } else {
    &Debug("Skipping execution of $dwww_build_menu - dwww package doesn't seem to be installed");
  }  
} # }}}
