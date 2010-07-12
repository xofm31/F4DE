# F4DE
# TrialsFuncs.pm
# Author: Jon Fiscus
# Additions: Martial Michel
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. F4DE is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

package TrialsFuncs;

use strict;

use MMisc;
use Data::Dumper;
use SimpleAutoTable;

=pod

=head1 NAME

common/lib/TrialsFuncs - A database object for holding detection decision trials.  

=head1 SYNOPSIS

This object contains a data stucture to hold a database of trials.  A trial is....

=head1 DESCRIPTION

=head2 METHODS

=over 4

=item B<new>(...)  

This is the new

=cut

sub new {
  my $class = shift @_;
  my $trialParams = shift @_;
  my ($taskId, $blockId, $decisionId) = 
    MMisc::iuav(\@_, "Term Detection", "Term", "Occurrence");
  
  MMisc::error_quit("new Trial() called without a \$trialParams value") 
    if (! defined($trialParams));
  
  my $self =
    {
     "TaskID" => $taskId,
     "BlockID" => $blockId,
     "DecisionID" => $decisionId,
     "isSorted" => 1,
     "trials" => {},          ### This gets built as you add trials
     "trialParams" => $trialParams ### Hash table for passing info to the Trial* objects 
    };
  
  bless $self;
  return $self;
}

sub unitTest {
  print "Test TrialsFuncs\n";
  my $trial = new TrialsFuncs({ (TOTAL_TRIALS => 78) },
                              "Term Detection", "Term", "Occurrence");
  
  ## How to handle cases in F4DE
  ## Mapped 
  #$trial->addTrial("she", 0.3, <DEC>, 1);
  ## unmapped Ref
  #$trial->addTrial("she", -inf, "NO", 1);
  ## unmapped sys
  #$trial->addTrial("she", 0.3, <DEC>, 0);
  
  $trial->addTrial("she", 0.7, "YES", 1);
  $trial->addTrial("she", 0.3, "NO", 1);
  $trial->addTrial("she", 0.2, "NO", 0);
  $trial->addTrial("second", 0.7, "YES", 1);
  $trial->addTrial("second", 0.3, "YES", 0);
  $trial->addTrial("second", 0.2, "NO", 0);
  $trial->addTrial("second", 0.3, "NO", 1);
  
  ### Test the contents
  print " Copying structure...  ";
  my $sorted = $trial->copy();
  print "OK\n";
  print " Sorting structure...  ";
  $sorted->sortTrials();
  print "OK\n";
  print " Checking contents...  ";
  my @tmp = ($trial, $trial->copy(), $sorted);
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $tr = $tmp[$i];
    MMisc::error_quit("Not enough blocks")
        if (scalar(keys(%{ $tr->{"trials"} })) != 2);
    MMisc::error_quit("Not enough 'NO TARG' for block 'second'")
        if ( $tr->{"trials"}{"second"}{"NO TARG"} != 1);
    MMisc::error_quit("Not enough 'YES TARG' for block 'second'")
        if ( $tr->{"trials"}{"second"}{"YES TARG"} != 1);
    MMisc::error_quit("Not enough 'NO TARG' for block 'second'")
        if ( $tr->{"trials"}{"second"}{"NO NONTARG"} != 1);
    MMisc::error_quit("Not enough 'YES TARG' for block 'second'")
        if ( $tr->{"trials"}{"second"}{"YES NONTARG"} != 1);
    MMisc::error_quit("Not enough TARGs for block 'second'")
        if (scalar(@{ $tr->{"trials"}{"second"}{"TARG"} }) != 2);
    MMisc::error_quit("Not enough NONTARGs for block 'second'")
        if (scalar(@{ $tr->{"trials"}{"second"}{"NONTARG"} }) != 2);
    if ($tr->{isSorted}) {
      MMisc::error_quit("TARGs not sorted")
          if ($tr->{"trials"}{"second"}{"TARG"}[0] > $tr->{"trials"}{"second"}{"TARG"}[1]);
      MMisc::error_quit("NONTARGs not sorted")
          if ($tr->{"trials"}{"second"}{"NONTARG"}[0] > $tr->{"trials"}{"second"}{"NONTARG"}[1]);
    }
    MMisc::error_quit("pooledTotal trials does not exist")
        if (! $tr->getTrialParamValueExists("TOTAL_TRIALS"));
    MMisc::error_quit("pooledTotal trials not set")
        if ($tr->getTrialParamValue("TOTAL_TRIALS") != 78);
    
  }
  print "OK\n";
  return 1;
}

sub isCompatible(){
  my ($self, $tr2) = @_;
  
  return 0 if (ref($self) ne ref($tr2));

  my @tmp = $self->getTrialParamKeys();
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $k = $tmp[$i];
    return 0 if (! $tr2->getTrialParamValueExists($k));
#    return 0 if ($self->getTrialParamValue($k) ne $tr2->getTrialParamValue($k));
  }

  my @tmp = $tr2->getTrialParamKeys();
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $k = $tmp[$i];
    return 0 if (! $self->getTrialParamValueExists($k));
#    return 0 if ($self->getTrialParamValue($k) ne $tr2->getTrialParamValue($k));
  }

  return 1;    
}


####################################################################################################

=item B<addTrial>(I<$blockID>, I<$sysScore>, I<$decision>, I<$isTarg>)  

Addes a trail, which is a decision made by a system on a specific input, to the trials object.  
The variables are as follows:

I<$blockID> is the statistical sampling block ID for the trial.  This trial structure is designed to handle 
averaging over statistical blocks.  If you don't want to average over blocks, then use a single blockID for 
all trials.

I<$sysScore> is the system's belief that the trial is an instance of the target object.  It can be any floating point # or if 
I<$decision> is /OMITTED/ it can be C<undef>.

I<$decision> is the system's actual decision for the trial.  Please read the detection evaluation framework papers to 
understand the implications of this variable.  The possible values are:

=over

B<YES> Indicating the trial is above the system's threshold for declaring the trial to be an instance.

B<NO> Indicating the trial is below the system's threshold for declaring the trial to be an instance.

B<OMITTED> Indicating the system did not provide an output for this trial.  If the decision is /OMITTED/, then the 
I<$sysScore> is ignored.

=back 

I<$isTarg> is a boolean indicating if the trial is an instance of the target or not.

=cut

sub addTrial {
  my ($self, $block, $sysscore, $decision, $isTarg) = @_;
  
  MMisc::error_quit("Decision must be \"YES|NO|OMITTED\" not '$decision'")
      if ($decision !~ /^(YES|NO|OMITTED)$/);
  my $attr = ($isTarg ? "TARG" : "NONTARG");
  
  $self->_initForBlock($block);
  
  ## update the counts
  $self->{"isSorted"} = 0;
  if ($decision ne "OMITTED") {
    push(@{ $self->{"trials"}{$block}{$attr} }, $sysscore);
  } else {
    MMisc::error_quit("Adding an OMITTED target trail with and defined decision score is illegal")
        if (defined($sysscore));
    MMisc::error_quit("OMITTED trials must be Target trials")
        if (! $isTarg);
  }
  $self->{"trials"}{$block}{$decision." $attr"} ++;
}

sub _initForBlock {
  my ($self, $block) = @_;
  
  if (! defined($self->{"trials"}{$block}{"title"})) {
    $self->{"trials"}{$block}{"TARG"} = [];
    $self->{"trials"}{$block}{"NONTARG"} = [];
    $self->{"trials"}{$block}{"title"} = "$block";
    $self->{"trials"}{$block}{"YES TARG"} = 0;
    $self->{"trials"}{$block}{"NO TARG"} = 0;
    $self->{"trials"}{$block}{"YES NONTARG"} = 0;
    $self->{"trials"}{$block}{"NO NONTARG"} = 0;
    $self->{"trials"}{$block}{"OMITTED TARG"} = 0;
  }
}

sub getTaskID {
  my ($self) = @_;
  $self->{TaskID};
}

sub getBlockID {
  my ($self) = @_;
  $self->{BlockID};
}

sub getDecisionID {
  my ($self) = @_;
  $self->{DecisionID};
}

sub getTrialParams {
  my ($self) = @_;
  $self->{trialParams};
}

sub getTrialParamKeys {
  my ($self) = @_;
  keys %{ $self->{trialParams} };
}

sub getTrialParamsStr {
  my ($self) = @_;
  my $str = "{ (";
  my @tmp = keys %{ $self->{trialParams} };
  for (my $i = 0; $i < scalar @tmp; $i++) {
    my $k = $tmp[$i];
    $str .= "'$k' => '$self->{trialParams}->{$k}', ";
  }
  $str .= ') }';
  $str;   
}

sub setTrialParamValue {
  my ($self, $key, $val) = @_;
  $self->{trialParams}->{$key} = $val;
}

sub getTrialParamValueExists(){
  my ($self, $key) = @_;
  exists($self->{trialParams}->{$key});
}

sub getTrialParamValue(){
  my ($self, $key) = @_;
  $self->{trialParams}->{$key};
}

sub dump {
  my($self, $OUT, $pre) = @_;
  
  my($k1, $k2, $k3) = ("", "", "");
  print $OUT "${pre}Dump of Trial_data  isSorted=".$self->{isSorted}."\n";
  
  my @k1tmp = sort keys %$self;
  for (my $i1 = 0; $i1 < scalar @k1tmp; $i1++) {
    $k1 = $k1tmp[$i1];
    if ($k1 eq "trials") {
      print $OUT "${pre}   $k1 -> $self->{$k1}\n";
      my @k2tmp = keys %{ $self->{$k1} };
      for (my $i2 = 0; $i2 < scalar @k2tmp; $i2++) {
        $k2 = $k2tmp[$i2];
	print $OUT "${pre}      $k2 -> $self->{$k1}{$k2}\n";
	
        my @k3tmp = sort keys %{ $self->{$k1}{$k2} };
        for (my $i3 = 0; $i3 < scalar @k3tmp; $i3++) {
          $k3 = $k3tmp[$i3];
	  if ($k3 eq "TARG" || $k3 eq "NONTARG") {
	    my(@a) = @{ $self->{$k1}{$k2}{$k3} };
	    print $OUT "${pre}         $k3 (".scalar(@a).") -> (";
	    
	    if ($#a > 5) {
	      foreach $_(0..2) {
		print $OUT "$a[$_],";
	      }
	      
	      print $OUT "...";

	      foreach $_(($#a-2)..$#a) {
		print $OUT ",$a[$_]";
	      }
	    } else {
	      print $OUT join(",",@a);
	    }
	    
	    print $OUT ")\n";
	  } else {
	    print $OUT "${pre}         $k3 -> $self->{$k1}{$k2}{$k3}\n";
	  }
	}
      }
    } else {
      print $OUT "${pre}   $k1 -> $self->{$k1}\n";
    }
  }   
}

sub copy {
  my ($self, $block) = @_;
  my ($copy) = new TrialsFuncs($self->getTrialParams(), $self->getTaskID(), 
                               $self->getBlockID(), $self->getDecisionID());
    
  my @blocks = ();
  if (defined($block)) {
    push @blocks, $block;
  } else {
    @blocks = keys %{ $self->{"trials"} };
  }
  
  for (my $i1 = 0; $i1 < scalar @blocks; $i1++) {
    my $block = $blocks[$i1];
    my @k2tmp = keys %{ $self->{"trials"}{$block} };
    for (my $i2 = 0; $i2 < scalar @k2tmp; $i2++) {
      my $param = $k2tmp[$i2];
      if ($param eq "TARG" || $param eq "NONTARG") {
	my(@a) = @{ $self->{"trials"}{$block}{$param} };
	$copy->{"trials"}{$block}{$param} = [ @a ];
      } else {
	$copy->{"trials"}{$block}{$param} = $self->{"trials"}{$block}{$param};
      }
    }
  }
  
  $copy->{isSorted} = $self->{isSorted}; 
  $copy->{pooledTotalTrials} = $self->{pooledTotalTrials}; 
  $copy;
}

sub dumpCountSummary {
  my ($self) = @_;

  my $at = new SimpleAutoTable();
  my ($TY, $OT, $NT, $YNT, $NNT) = (0, 0, 0, 0, 0);
  my @ktmp = sort keys %{ $self->{"trials"} };
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    $at->addData($self->getNumYesTarg($block),     "Corr:YesTarg", $block);
    $at->addData($self->getNumOmittedTarg($block), "Miss:OmitTarg", $block);
    $at->addData($self->getNumNoTarg($block),      "Miss:NoTarg", $block);
    $at->addData($self->getNumYesNonTarg($block),  "FA:YesNontarg", $block);
    $at->addData($self->getNumNoNonTarg($block),   "Corr:NoNontarg", $block);
    
    $TY += $self->getNumYesTarg($block);
    $OT += $self->getNumOmittedTarg($block);
    $NT += $self->getNumNoTarg($block);
    $YNT += $self->getNumYesNonTarg($block);
    $NNT += $self->getNumNoNonTarg($block);
  }
  $at->addData("------",  "Corr:YesTarg", "-----");
  $at->addData("------",  "Miss:OmitTarg", "-----");
  $at->addData("------",  "Miss:NoTarg", "-----");
  $at->addData("------", "FA:YesNontarg", "-----");
  $at->addData("------", "Corr:NoNontarg", "-----");
  
  $at->addData($TY,  "Corr:YesTarg", "Total");
  $at->addData($OT,  "Miss:OmitTarg", "Total");
  $at->addData($NT,  "Miss:NoTarg", "Total");
  $at->addData($YNT, "FA:YesNontarg", "Total");
  $at->addData($NNT, "Corr:NoNontarg", "Total");
  
  my $txt = $at->renderTxtTable(2);
  if (! defined($txt)) {
    print "Error:  Dump of Count Summary Failed with ".$at->get_errormsg();
  }
  $txt;
}

sub dumpGrid {
  my ($self) = @_;
  
  my @k1tmp = keys %{ $self->{"trials"} };
  for (my $i1 = 0; $i1 < scalar @k1tmp; $i1++) {
    my $block = $k1tmp[$i1];
    my @k2tmp = sort keys %{ $self->{"trials"}{$block} };
    for (my $i2 = 0; $i2 < scalar @k2tmp; $i2++) {
      my $var = $k2tmp[$i2];
      if ($var eq "TARG" || $var eq "NONTARG") {
        my @k3tmp = @{ $self->{"trials"}{$block}{$var} };
        for (my $i3 = 0; $i3 < scalar @k3tmp; $i3++) {
          my $sc = $k3tmp[$i3];
	  printf "GRID $sc $block-$var %12.10f $sc-$block\n", $sc;
	}
      }
    }
  }
}

sub numerically { $a <=> $b; }

sub sortTrials {
  my ($self) = @_;
  return if ($self->{"isSorted"});

  my @ktmp = keys %{ $self->{"trials"} };
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    $self->{"trials"}{$block}{TARG} = [ sort numerically @{ $self->{"trials"}{$block}{TARG} } ];
    $self->{"trials"}{$block}{NONTARG} = [ sort numerically @{ $self->{"trials"}{$block}{NONTARG} } ];
  }
  
  $self->{"isSorted"} = 1;
}

sub getBlockIDs {
  my ($self, $block) = @_;
  keys %{ $self->{"trials"} };
}

sub getNumTargScr {
  my ($self, $block) = @_;
  scalar(@{ $self->{"trials"}{$block}{"TARG"} });
}

sub getTargScr {
  my ($self, $block) = @_;
  $self->{"trials"}{$block}{"TARG"};
}

sub getNumNoTarg {
  my ($self, $block) = @_;
  $self->{"trials"}->{$block}->{"NO TARG"};
}

sub getNumTarg {
  my ($self, $block) = @_;
  ($self->getNumNoTarg($block) + $self->getNumYesTarg($block) + $self->getNumOmittedTarg($block) );
}

sub getNumSys {
  my ($self, $block) = @_;
  ($self->getNumNoTarg($block) + $self->getNumYesTarg($block) + $self->getNumYesNonTarg($block) + $self->getNumNoNonTarg($block));
}

sub getNumYesTarg {
  my ($self, $block) = @_;
  $self->{"trials"}->{$block}->{"YES TARG"};
}

sub getNumOmittedTarg {
  my ($self, $block) = @_;
  $self->{"trials"}->{$block}->{"OMITTED TARG"};
}

sub getNumNonTargScr {
  my ($self, $block) = @_;
  scalar(@{ $self->{"trials"}{$block}{"NONTARG"} });
}

sub getNonTargScr {
  my ($self, $block) = @_;
  $self->{"trials"}{$block}{"NONTARG"};
}

sub getNumNoNonTarg {
  my ($self, $block) = @_;
  $self->{"trials"}->{$block}->{"NO NONTARG"};
}

sub getNumYesNonTarg {
  my ($self, $block) = @_;
  $self->{"trials"}->{$block}->{"YES NONTARG"};
}

sub getNumFalseAlarm {
  my ($self, $block) = @_;
  $self->getNumYesNonTarg($block);
}

sub getNumMiss {
  my ($self, $block) = @_;
  $self->getNumNoTarg($block) + $self->getNumOmittedTarg($block);
}

sub getNumCorr {
  my ($self, $block) = @_;
  $self->getNumYesTarg($block);
}

sub getNumNonTarg {
  my ($self, $block) = @_;
  ($self->{"trials"}->{$block}->{"NO NONTARG"} + 
   $self->{"trials"}->{$block}->{"YES NONTARG"})
}

sub _stater {
  my ($self, $data) = @_;
  my $sum = 0;
  my $sumsqr = 0;
  my $n = 0;
  for (my $i = 0; $i < scalar @$data; $i++) {
    my $d = $$data[$i];
    $sum += $d;
    $sumsqr += $d * $d;
    $n++;
  }
  ($sum, ($n > 0 ? $sum/$n : undef), ($n <= 1 ? undef : sqrt((($n * $sumsqr) - ($sum * $sum)) / ($n * ($n - 1)))));
}

sub getTotNumTarg {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumTarg($block);
  }
  $self->_stater(\@data);
}

sub getTotNumSys {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumSys($block);
  }
  $self->_stater(\@data);
}

sub getTotNumCorr {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumCorr($block);
  }
  $self->_stater(\@data);
}

sub getTotNumFalseAlarm {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumFalseAlarm($block);
  }
  $self->_stater(\@data);
}

sub getTotNumMiss {
  my ($self) = @_;
  my @data = ();
  my @ktmp = $self->getBlockIDs();
  for (my $i = 0; $i < scalar @ktmp; $i++) {
    my $block = $ktmp[$i];
    push @data, $self->getNumMiss($block);
  }
  $self->_stater(\@data);
}

sub getTargDecScr {
  my ($self, $block, $ind) = @_;
  $self->{"trials"}->{$block}->{"TARG"}[$ind]; 
}

sub getNonTargDecScr {
  my ($self, $block, $ind) = @_;
  $self->{"trials"}->{$block}->{"NONTARG"}[$ind]; 
}

sub getBlockId {
  my ($self) = @_;
  $self->{"BlockID"};
}

sub getDecisionId {
  my ($self) = @_;
  $self->{"DecisionID"};
}
  
### This is not an instance method
sub mergeTrials{
  my ($r_baseTrial, $mergeTrial, $trial, $mergeType) = @_;

  ### Sanity Check 
  my @blockIDs = $mergeTrial->getBlockIDs();
  MMisc::error_quit("trial merge with multi-block trial data not supported")
      if (@blockIDs > 1);
  MMisc::error_quit("trial merge requires at least one block ID")
      if (@blockIDs > 1);

  ### First the params
  if (! defined($$r_baseTrial)){
    $$r_baseTrial = new TrialsFuncs($mergeTrial->getTrialParams(),
                                    $mergeTrial->getTaskID(), $mergeTrial->getBlockID(),
                                    $mergeTrial->getDecisionID());
  } else { 
    my @ktmp = $$r_baseTrial->getTrialParamKeys();
    for (my $i = 0; $i < scalar @ktmp; $i++) {
      my $mkey = $ktmp[$i];
      my $newVal = $trial->trialParamMerge($mkey,
                                            $$r_baseTrial->getTrialParamValue($mkey), 
                                            $mergeTrial->getTrialParamValue($mkey), $mergeType);
      $$r_baseTrial->setTrialParamValue($mkey, $newVal);
    }
  }

  ### Now the data!!!
  my $newBlock = "pooled";
  if ($mergeType eq "blocked"){
    my @theIDs = $$r_baseTrial->getBlockIDs();
    $newBlock = sprintf("block_%03d",scalar(@theIDs));  
  }
    
  $$r_baseTrial->{isSorted} = 0;
  $$r_baseTrial->_initForBlock($newBlock);
    
  push (@{ $$r_baseTrial->{"trials"}{$newBlock}{"TARG"} }, @{ $mergeTrial->{trials}{$blockIDs[0]}{TARG} });
  push (@{ $$r_baseTrial->{"trials"}{$newBlock}{"NONTARG"} }, @{ $mergeTrial->{trials}{$blockIDs[0]}{NONTARG} });
  foreach my $counter("YES TARG", "NO TARG", "YES NONTARG", "NO NONTARG", "OMITTED TARG"){
    $$r_baseTrial->{"trials"}{$newBlock}{$counter} += $mergeTrial->{"trials"}{$blockIDs[0]}{$counter};
  }    
  
}

sub exportForDEVA{
  my ($self, $root) = @_;
  my $trialNum = 1;
  my $tid;
  
  my @blockIDs = $self->getBlockIDs();
  if (@blockIDs > 1){
    open (MD, ">$root.metadata.csv") || MMisc::error_quit("Failed to open $root.metadata.csv for metadata");
    print MD "TrialID,Block\n";
  }
  open (REF, ">$root.ref.csv") || MMisc::error_quit("Failed to open $root.ref.csv for reference file");
  print REF "TrialID,Targ\n";
  open (SYS, ">$root.sys.csv") || MMisc::error_quit("Failed to open $root.sys.csv for system file");
  print SYS "TrialID,Score,Decision\n";
  
  for (my $block; $block < @blockIDs; $block++){
    ### The TARGETS
    my $dec = $self->getTargScr($blockIDs[$block]);
    for (my $d = 0; $d < @$dec; $d++){
      $tid = sprintf("TID-%07.f", $trialNum++);    
      print REF "$tid,y\n";
      print SYS "$tid,$dec->[$d],y\n";
      if (@blockIDs > 1){
        print MD "$tid,$blockIDs[$block]\n";
      }
    }
    ### The NONTARGETS
    my $dec = $self->getNonTargScr($blockIDs[$block]);
    for (my $d = 0; $d < @$dec; $d++){
      $tid = sprintf("TID-%07.f", $trialNum++);    
      print REF "$tid,n\n";
      print SYS "$tid,$dec->[$d],y\n";
      if (@blockIDs > 1){
        print MD "$tid,$blockIDs[$block]\n";
      }
    }
  }

  if (@blockIDs > 1){
    close MD;
  }
  open REF;
  open SYS;
  
}

sub buildScoreDistributions{
  my ($self, $root) = @_;

  use Statistics::Descriptive;
  use Data::Dumper;
  
  my @blockIDs = $self->getBlockIDs();
  for (my $block; $block < @blockIDs; $block++){
    my $targStat = Statistics::Descriptive::Full->new();
    my $nontargStat = Statistics::Descriptive::Full->new();

    my $dec = $self->getTargScr($blockIDs[$block]);
    for (my $d = 0; $d < @$dec; $d++){
      $targStat->add_data($dec->[$d]);
    }
    ### The NONTARGETS
    my $dec = $self->getNonTargScr($blockIDs[$block]);
    for (my $d = 0; $d < @$dec; $d++){
      $nontargStat->add_data($dec->[$d]);
    }

    my $visMin = $targStat->min();
    $visMin = $nontargStat->min() if ($nontargStat->min() < $visMin);

    my $visMax = $targStat->max();
    $visMax = $nontargStat->max() if ($nontargStat->max() > $visMax);
    
    print "Block $block: visMin=$visMin, visMax=$visMax\n";
    
    ### 
    open TARG, "| his -n 100 -r $visMin:$visMax - | tee targ.his | his2dist_func > targ.his.dist" || die;
    print TARG join("\n",$targStat->get_data())."\n";
    close TARG;
    open NONTARG, "| his -n 100 -r $visMin:$visMax - | tee nontarg.his | his2dist_func > nontarg.his.dist" || die;
    print NONTARG join("\n",$nontargStat->get_data())."\n";
    close NOTARG;
    
    print "./his2gnuplot -s -f targ.his -l Targets -f nontarg.his -l NonTargets foo\n";
    print "hp_plt -png -color foo.plt > foo.png\n";
    
    open DIST, ">CDF.plt" || die;
    print DIST "set terminal postscript\n";                                                                                                                                                                    
    print DIST "set ylabel \"Percent\"\n";                                                                                                                                                                        
    print DIST "set xlabel \"Decision Score\"\n";                                                                                                                                                                        
    print DIST "set title  \"Cumulative distributions of Targets and Non-Targets\"\n";
    print DIST "plot 'targ.his.dist' using 1:2 title \"Targets\" with lines,";                                                                                                                              
    print DIST "     'nontarg.his.dist' using 1:2 title \"NonTargets\" with lines\n";
    close DIST;                                          
    print "hp_plt -png -color CDF.plt > CDF.png\n";
                                                                                                                                                                                           
                                                                   
##    my @partitions = ($visMin);
##    my $nPartitions = 10;
##    for (my $i=0; $i <= $nPartitions; $i++){
##      push @partitions, $visMin + $i * (($visMax - $visMin) / $nPartitions);
##    }
##    print Dumper(\@partitions);
##      
##    my %targHist = $targStat->frequency_distribution(\@partitions);
##    my %nontargHist = $nontargStat->frequency_distribution(\@partitions);
##    my @keys = sort {$a <=> $b} keys %targHist;
##
##    foreach my $k(@keys){
##      print "$k -> $targHist{$k} $nontargHist{$k}\n";
##    }
   
  }
}

1;
