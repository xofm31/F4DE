#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
  if 0;

#
# $Id$
#
# Mirror XML directory structure (specialized for use with Convert_Analyze_Set)
#
# Author:    Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEAR Detection and Tracking Viper XML Validator" is an experimental system.
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
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my (@f4bv, $f4d);
BEGIN {
  if ( ($^V ge 5.18.0)
       && ( (! exists $ENV{PERL_HASH_SEED})
	    || ($ENV{PERL_HASH_SEED} != 0)
	    || (! exists $ENV{PERL_PERTURB_KEYS} )
	    || ($ENV{PERL_PERTURB_KEYS} != 0) )
     ) {
    print "You are using a version of perl above 5.16 ($^V); you need to run perl as:\nPERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl\n";
    exit 1;
  }

  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../CLEAR07/lib", "$f4d/../../../common/lib");
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

# Part of this tool
foreach my $pn ("MMisc") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "AVSS Mirror XML directory structure (uses Convert_Analyze_Set) ($versionkey)";

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
my $toolsb = "Convert_Analyze_Set";

my $usage = &set_usage();

my $dosys = 0;
my $doStarterSys = 0;
my $doEmptySys = 0;
my $ifgap = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz  #
# Used:     E   I         S              h          s         #

my %opt;
GetOptions
  (
   \%opt,
   'help',
   'sys'          => \$dosys,
   'StarterSys'   => \$doStarterSys,
   'EmptySys'     => \$doEmptySys,
   'IFramesGap=i' => \$ifgap,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});

MMisc::error_quit("Not enough arguments\n$usage\n") if (scalar @ARGV < 2);

MMisc::error_quit("\'sys\', \'StarterSys\' or \'EmptySys\' can not be used at the same time\n$usage")
  if ($dosys + $doStarterSys + $doEmptySys > 1);

MMisc::error_quit("Invalid \'IFramesGap\' value [$ifgap], must be positive and not equal to zero\n$usage")
  if ($ifgap < 1);

my ($in, $out) = @ARGV;

MMisc::error_quit("No input_dir provided.\n $usage")
  if (MMisc::is_blank($out));
MMisc::error_quit("No output_dir provided.\n $usage")
  if (MMisc::is_blank($out));

my $err = MMisc::check_dir_r($in);
MMisc::error_quit("input_dir [$in] problem: $err")
  if (! MMisc::is_blank($err));

my $err = MMisc::check_dir_w($out);
MMisc::error_quit("output_dir [$out] problem: $err")
  if (! MMisc::is_blank($err));

my $tool = MMisc::iuv($ARGV[2], MMisc::get_pwd() . "/${toolsb}.pl");
my $err = MMisc::check_file_x($tool);
MMisc::error_quit("tool [$tool] problem: $err")
  if (! MMisc::is_blank($err));

# Extend $tool
$tool .= " --IFramesGap $ifgap";
if ($dosys) {
  $tool .= " --sys";
} elsif ($doStarterSys) {
  $tool .= "  --StarterSys";
} elsif ($doEmptySys) {
  $tool .= " --EmptySys";
}

&do_xmls($in, $out);

MMisc::ok_quit("\nDone\n");

############################################################

sub do_xmls {
  my ($in, $out) = @_;

  my $cwd = MMisc::get_pwd();

  chdir($in);
  my $cmd = 'find . -name "*.xml"';
  my ($retcode, $stdout, $stderr) = MMisc::do_system_call($cmd);
  MMisc::error_quit("Problem finding XML files: $stderr")
      if ($retcode != 0);
  chdir($cwd);

  my @files = split(m%\n%, $stdout);
  chomp @files;

  my %sets = &split_into_sets(@files);
  my @sl = keys %sets;

  print "Found: ", scalar @sl, " sets\n";

  my $inc = 0;
  foreach my $set (sort @sl) {
    print "|-> Processing Set ", ++$inc, " / ", scalar @sl, " [$set]\n";
    &process_set($set, $in, $out, @{$sets{$set}});
  }

}

####################

sub split_into_sets {
  my @fl = @_;

  my %res = ();
  foreach my $f (@fl) {
    my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($f);
    MMisc::error_quit("Problem splitting file name: $err")
        if (! MMisc::is_blank($err));
    # remove heading './', '/' and trailing '/'
    $dir =~ s%^\.\/%%;
    $dir =~ s%^\/%%;
    $dir =~ s%\/$%%;
    # Get just the filename
    my $fn = MMisc::concat_dir_file_ext("", $file, $ext);
    push @{$res{$dir}}, $fn;
  }
  
  return(%res);
}

####################

sub process_set {
  my ($set_dir, $set_indir, $set_outdir, @set_files) = @_;

  MMisc::error_quit("No XML files expected ?")
      if (scalar @set_files == 0);

  my $id = "$set_indir/$set_dir";
  my $err = MMisc::check_dir_r($id);
  MMisc::error_quit("Problem with input directory [$id]: $err")
      if (! MMisc::is_blank($err));
      
  my $od = "$set_outdir/$set_dir";
  MMisc::error_quit("Problem creating output directory [$od]")
      if (! MMisc::make_dir($od));

  my $logfile = "$od/set_run.log";
  my ($ok, $otxt, $stdout, $stderr, $retcode, $ofile) =
    MMisc::write_syscall_logfile($logfile, $tool, $id, $od);

  MMisc::error_quit("Problem while set processing, see logfile [$ofile]")
      if (! $ok);
  MMisc::error_quit("Problem processing set command, see logfile [$ofile]")
      if ($retcode != 0);

  print "|   |-> See run logfile [$ofile]\n";

  foreach my $file (@set_files) {
    my $of = "$od/$file";
    my ($size, $err) = MMisc::get_file_size($of);
    MMisc::error_quit("Problem while checking output file size [$of]: $err")
        if (! MMisc::is_blank($err));
    MMisc::error_quit("Output file is 0 [$of]")
        if ($size == 0);
  }

  print "|   |-> Set output files (", scalar @set_files, ") generated\n";
  print "|\n";
}

############################################################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) . "\n";
}

########################################

sub set_usage {
  my $tmp=<<EOF

$versionid

$0 [--help] --IFramesGap gap [--sys | --StarterSys | --EmptySys] input_dir output_dir [full_path_to_tool]

Convert all the XML files found following the input_dir directory structure from AVSS ViPER to CLEAR ViPER files.

Relies on the $toolsb tool for this process.

Where:
  --help          Print this usage information and exit
  --IFramesGap    Specify the gap between I-Frames and Annotated frames
  --sys           Generate a CLEAR ViPER system file
  --StarterSys    Generate a CLEAR ViPER Starter sys file (only contains the first five non occluded bounding boxes)
  --EmptySys      Generate a CLEAR ViPER system file with no person defintion

EOF
;

  return($tmp);
}
