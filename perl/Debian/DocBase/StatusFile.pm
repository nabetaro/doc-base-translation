# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: StatusFile.pm 48 2007-04-12 19:25:15Z robert $
#

package Debian::DocBase::StatusFile;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(remove_data_files read_status_file write_status_file display_status_information);

use Debian::DocBase::Common;


sub remove_data_files { # {{{
  my $status_file = "$DATA_DIR/$docid.status";
  if (-f $status_file) {
    print "Removing status file $status_file\n" if $verbose;
    unlink($status_file)
      or die "$status_file: cannot remove status file: $!";
  }

  my $list_file = "$DATA_DIR/$docid.list";
  if (-f $list_file) {
    print "Removing list file $list_file\n" if $verbose;
    unlink($list_file)
      or die "$list_file: cannot remove status file: $!";
  }
} # }}}


sub read_status_file { # {{{
  my ($ignore) = @_;

  my $status_file = "$DATA_DIR/$docid.status";
  if (not -f $status_file) {
    return(0) if $ignore;

    warn "Document `$docid' is not installed.\n";
    exit 1;
  }

  open(S,"$status_file")
    or die "$status_file: cannot open status file for reading: $!";
  while (<S>) {
    chomp;
    next if /^\s*$/o;
    /^\s*(\S+):\s*(.*\S)\s*$/
      or die "syntax error in status file: $_";
    $status{$1} = $2;
  }
  close(S)
    or die "$status_file: cannot close status file: $!";
} # }}}

sub write_status_file { # {{{
  return unless $status_changed;

  my $status_file = "$DATA_DIR/$docid.status";

  open(S,">$status_file")
    or die "$status_file: cannot open status file for writing: $!";
  for my $k (keys %status) {
    print S "$k: $status{$k}\n";
  }
  close(S) or die "$status_file: cannot close status file: $!";

  $status_changed = 0;
} # }}}

sub display_status_information { # {{{
  print "---document-information---\n";
  print "Document: $$doc_data{'document'}\n";
  for my  $k (sort keys %$doc_data) {
    next if $k eq 'document';
    my $kk = $k; 
    substr($kk,0,1) =~ tr/a-z/A-Z/;
    print "$kk: $$doc_data{$k}\n";
  }
  for my $format_data (@format_list) {
    print "\n";
    print "---format-description---\n";
    print "Format: $$format_data{'format'}\n";
    for my $k (sort keys %$format_data) {
      next if $k eq 'format';
      my $kk = $k; 
      substr($kk,0,1) =~ tr/a-z/A-Z/;
      print "$kk: $$format_data{$k}\n";
    }
  }
  print "\n";
  print "---status-information---\n";
  for my $k (sort keys %status) {
    print "$k: $status{$k}\n";
  }
} # }}}

1;
