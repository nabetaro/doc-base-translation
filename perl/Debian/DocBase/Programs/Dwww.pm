# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Dwww.pm 115 2008-03-31 18:16:38Z robert $
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

our $dwww_build_menu = "/usr/sbin/dwww-build-menu";

# Registering to dwww:
sub RegisterDwww(@) { # {{{
  my @documents = @_;
  $#documents < 0 and return;

  Debug("RegisterDwww started");

  if (-e $dwww_build_menu) {
    Execute($dwww_build_menu) if $opt_update_menus;
  } else {
    Debug("Skipping execution of $dwww_build_menu - dwww package doesn't seem to be installed");
  }  
  Debug("RegisterDwww finished");

} # }}}
