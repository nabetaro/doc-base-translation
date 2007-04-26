# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: FilesListFile.pm 50 2007-04-12 19:35:53Z robert $
#

package Debian::DocBase::FilesListFile;

use Exporter();
#use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(display_listing read_list_file write_list_file);

use Debian::DocBase::Common;



sub display_listing { # {{{
  for $k (sort keys %list) {
    print "$k\n";
  }
} # }}}

sub read_list_file { # {{{
  my $list_file = "$DATA_DIR/$docid.list";
  return unless -f $list_file;

  open(L,"$list_file") 
    or die "$list_file: cannot open list file for reading: $!";
  while (<L>) {
    chomp;
    next if /^\s*$/o;
    $list{$_} = 1;
  }
  close(L) or die "$list_file: cannot close file: $!";
} # }}}

sub write_list_file { # {{{
  return unless $list_changed;

  my $list_file = "$DATA_DIR/$docid.list";

  open(L,">$list_file")
    or die "$list_file: cannot open list file for writing: $!";
  for $k (keys %list) {
    print L "$k\n";
  }
  close(L) or die "$list_file: cannot close file: $!";

  $list_changed = 0;
} # }}}

1;
