# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Dwww.pm 46 2007-04-12 19:17:46Z robert $
#

package Debian::DocBase::Programs::Dwww;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(register_dwww update_dwww_menus);

use Debian::DocBase::Common;

our $dwww_update = "/usr/bin/update-menus";

# Registering to dwww:
sub register_dwww { # {{{
  my $update_dwww = 0;
  for my $format_data (@format_list) {
    $update_dwww = 1;
    # set status
    $status{'Registered-to-dwww'} = 1;
    $status_changed = 1;
  }

  if ($update_dwww) {
    update_dwww_menus();
  }
} # }}}

sub update_dwww_menus { # {{{
  if ($do_dwww_update && -x $dwww_update) {
    print "Executing $dwww_update\n" if $verbose;
    if (system($dwww_update) != 0) {
      warn "warning: error occured during execution of $dwww_update";
    }
  }
} # }}}

