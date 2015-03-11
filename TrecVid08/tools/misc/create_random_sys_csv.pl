#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 random CSV generator
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 random CSV generator" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Version

# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TrecVid08 random CSV Generator Version: $version";

##########
# Check we have every module (perl wise)

my (@f4bv, $f4d);
BEGIN {
  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("MMisc", "TrecVid08ViperFile", "TrecVid08Observation", "CSVHelper") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long") {
  unless (eval "use $pn; 1") {
    &_warn_add("\"$pn\" is not available on your Perl installation. ", "Please look it up on CPAN [http://search.cpan.org/]\n");
    $have_everything = 0;
  }
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Get some values from TrecVid08ViperFile
my $dummy = new TrecVid08ViperFile();
my @ok_events = $dummy->get_full_events_list();
# We will use the '$dummy' to do checks before processing files

my @ok_csv_keys = TrecVid08Observation::get_ok_csv_keys();

########################################
# Options processing

my $usage = &set_usage();

# Default values for variables
my $writeto = "";
my @asked_events = ();
my ($beg, $end) = (0, 0);
my $entries = 100; 

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:                               e  h   l         vw     #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'writeTo=s'       => \$writeto,
   'limitto=s'       => \@asked_events,
   'entries=i'       => \$entries,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});

MMisc::error_quit("\'writeTo\' must be specified\n\n$usage\n")
  if (MMisc::is_blank($writeto));


if (scalar @asked_events == 0) {
  @asked_events = @ok_events;
} else {
  @asked_events = $dummy->validate_events_list(@asked_events);
  MMisc::error_quit("While checking \'limitto\' events list (" . $dummy->get_errormsg() .")")
    if ($dummy->error());
}

MMisc::ok_quit("Not enough arguments leftover, awaiting number of frames\n$usage\n") if (scalar @ARGV != 1);

($beg, $end) = (1, shift @ARGV);

MMisc::error_quit("For \'end\'\'s \'beg:end\' values must follow: beg < end\n\n$usage\n")
  if ($end <= $beg);


# initialize random number
srand();

my $ocsvh = new CSVHelper();
my @oh = ($ok_csv_keys[9], $ok_csv_keys[0], $ok_csv_keys[1], $ok_csv_keys[2], $ok_csv_keys[3]);
$ocsvh->set_number_of_columns(scalar @oh);
my $ocsvtxt = "";
$ocsvtxt .= $ocsvh->array2csvline(@oh) . "\n";
MMisc::error_quit("Problem with output CSV : " . $ocsvh->get_errormsg())
  if ($ocsvh->error());

foreach my $event (@asked_events) {
  my $ne = int(rand($entries));
  my $th = int(rand(100));
  my @bl = ();
  for (my $i = 0; $i < $ne; $i++) { push @bl, int(rand($end)); }
  @bl = sort { $a <=> $b } @bl;
  my $inc = 0;
  foreach my $bv (@bl) {
    $inc++;
    $bv = ($bv >= $end) ? $bv - 100 : $bv;
    $bv = ($bv < $beg) ? $beg : $bv;
    my $ev = $bv + int(rand((2*$end) / $ne));
    $ev = ($ev >= $end) ? $end : $ev;
    my $ds = int(rand(100));
    my $dt = ($ds > $th) ? 'true' : 'false';
    my @csvl = ($inc, $event, "$bv:$ev", sprintf("%0.03f", $ds / 100), $dt);
#    print join(" | ", @csvl) . "\n";
    $ocsvtxt .= $ocsvh->array2csvline(@csvl) . "\n";
    MMisc::error_quit("Problem with output CSV : " . $ocsvh->get_errormsg())
      if ($ocsvh->error());
  }
  print " - $event : " . scalar @bl . " entries\n";
}
MMisc::writeTo($writeto, "", 1, 0, $ocsvtxt);

MMisc::ok_exit();

########## END

sub set_usage {
  my $ro = join(" ", @ok_events);

  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version] [--writeTo file.csv] [--limitto event1[,event2[...]]] [--entries number] endframenumber

Create a CSV file filled with random system entries

 Where:
  --help          Print this usage information and exit
  --version       Print version number and exit
  --writeTo       File to write CSV values to
  --limitto       Only care about provided list of events
  --entries       Maximum number of entries per event

Note:
 - List of recognized events: $ro
EOF
    ;

  return $tmp;
}
