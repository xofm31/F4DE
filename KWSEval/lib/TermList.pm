package TermList;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# KWSEval
# TermList.pm
#
# Original Author: Jerome Ajot
# Extensions: Martial Michel
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
# 
# KWSEval is an experimental system.  
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
#
# $Id$

use TranscriptHolder;
@ISA = qw(TranscriptHolder);

use strict;

my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TermList.pm Version: $version";

##

use TermListRecord;

use MMisc;
use xmllintHelper;
use MtXML;

sub new
{
    my $class = shift;
    my $termlistfile = shift;

    my $self = TranscriptHolder->new();

    $self->{TERMLIST_FILENAME} = $termlistfile;
    $self->{ECF_FILENAME} = "";
    $self->{VERSION} = "";
    $self->{TERMS} = {};
	
    bless $self;
    $self->loadFile($termlistfile) if (defined($termlistfile));
    
    return $self;
}

sub new_empty
{
    my $class = shift;
    my $termlistfile = shift;
    my $self = {};

    $self->{TERMLIST_FILENAME} = $termlistfile;
    $self->{ECF_FILENAME} = shift;
    $self->{VERSION} = shift;
    die "Failed: New TermList failed: \n   ".$self->errormsg() if (! $self->setLanguage(shift));
    die "Failed: New TermList failed: \n   ".$self->errormsg() if (! $self->setEncoding(shift));
    die "Failed: New TermList failed: \n   ".$self->errormsg() if (! $self->setCompareNormalize(shift));
    $self->{TERMS} = {};
	
    bless $self;    
    return $self;
}

sub unitTest
{
  print "TList Unit Test\n";
  print "OK\n";
}

sub union_intersection
{
    my($list1, $list2, $out_union, $out_intersection) = @_;
    
    my %union;
    my %isect;    
    foreach my $e (@{ $list1 }, @{ $list2 }) { $union{$e}++ && $isect{$e}++ }

    @{ $out_union } = keys %union;
    @{ $out_intersection } = keys %isect;
}

sub multiarray
{
    my($list1, $list2, $multi) = @_;
    
    foreach my $e1 (@{ $list1 })
    {
        foreach my $e2 (@{ $list2 })
        {
            push(@{$multi}, ($e1 ne "")?"$e1|$e2":"$e2");
        }
    }
}

sub QueriesToTermSet
{
    my ($self, $arrayqueries, $filterTerms) = @_;
    
    my %attributes;

    foreach my $termid(keys %{ $self->{TERMS} } )
    {
        foreach my $attrib_name(keys %{ $self->{TERMS}{$termid} })
        {
            if( ($attrib_name ne "TERMID") && ($attrib_name ne "TEXT") )
            {
                $attributes{$attrib_name} = 1;
            }
        }
    }
    
    foreach my $quer(@{ $arrayqueries })
    {
        MMisc::error_quit("$quer is not a valid attribute.")
            if (!$attributes{$quer});
    }
    
    my %hashterm;

    foreach my $termid(keys %{ $self->{TERMS} } )
    {
        foreach my $attrib_name(keys %{ $self->{TERMS}{$termid} })
        {
            if( ($attrib_name ne "TERMID") && ($attrib_name ne "TEXT") )
            {
                my $attribute_value = $self->{TERMS}{$termid}->{$attrib_name};
                push(@{ $hashterm{$attrib_name}{$attribute_value} }, $termid);
            }
        }
    }

    my @multivalues = ("");
    my @sorted_queries = sort @{ $arrayqueries };
    
    foreach my $quer(@sorted_queries)
    {
        my @values = sort keys %{ $hashterm{$quer} };
        my @finalmulti;
        multiarray(\@multivalues, \@values, \@finalmulti);
        @multivalues = @finalmulti;
    }
    
    my %hashlistterms;

    foreach my $multivalue(@multivalues)
    {
        my @values = split(/\|/, $multivalue);
    
        my @listterm = @{ $hashterm{$sorted_queries[0]}{$values[0]} };
        my $title = "$sorted_queries[0] $values[0]";
        
        for(my $i=1; $i<@sorted_queries; $i++)
        {
            my @outtmp;
            my @out_inter;
            union_intersection(\@listterm, \@{ $hashterm{$sorted_queries[$i]}{$values[$i]} }, \@outtmp, \@out_inter);
            @listterm = @out_inter;
            $title .= "|$sorted_queries[$i] $values[$i]";
        }
        
        $title =~ s/ /_/g;
    
        push(@{ $hashlistterms{$title} }, @listterm);
    }

    foreach my $finalkey(sort keys %hashlistterms)
    {
        push(@{ $filterTerms->{$finalkey} }, @{ $hashlistterms{$finalkey} });
    }
}

sub toString
{
    my ($self) = @_;

    print "Dump of TermList File\n";
    print "   File: " . $self->{TERMLIST_FILENAME} . "\n";
    print "   ECF filename: " . $self->{ECF_FILENAME} . "\n";
    print "   Version: " . $self->{VERSION} . "\n";
    print "   Language: " . $self->{LANGUAGE} . "\n";
    print "   TermList:\n";
    
    foreach my $terms(sort keys %{ $self->{TERMS} })
    {
        print "    ".$self->{TERMS}{$terms}->toString()."\n";
    }
}

####################

sub loadFile {
  my $self = shift @_;
  return($self->loadXMLFile(@_));
}

#####

sub loadXMLFile {
  my ($self, $tlistf) = @_;

  my $err = MMisc::check_file_r($tlistf);
  MMisc::error_quit("Problem with input file ($tlistf): $err")
      if (! MMisc::is_blank($err));

  my $modfp = MMisc::find_Module_path('TermList');
  MMisc::error_quit("Could not obtain \'TermList.pm\' location, aborting")
      if (! defined $modfp);

  my $f4b = 'F4DE_BASE';
  my $xmllint_env = "F4DE_XMLLINT";
  my $xsdpath = (exists $ENV{$f4b}) ? $ENV{$f4b} . "/lib/data" : $modfp . "/../../KWSEval/data";
  my @xsdfilesl = ('KWSEval-termlist.xsd');

  print STDERR "Loading Term List file '$tlistf'.\n";
  
  # First let us use xmllint on the file XML file
  my $xmlh = new xmllintHelper();
  my $xmllint = MMisc::get_env_val($xmllint_env, "");
  MMisc::error_quit("While trying to set \'xmllint\' (" . $xmlh->get_errormsg() . ")")
      if (! $xmlh->set_xmllint($xmllint));
  MMisc::error_quit("While trying to set \'xsdfilesl\' (" . $xmlh->get_errormsg() . ")")
    if (! $xmlh->set_xsdfilesl(@xsdfilesl));
  MMisc::error_quit("While trying to set \'Xsdpath\' (" . $xmlh->get_errormsg() . ")")
      if (! $xmlh->set_xsdpath($xsdpath));
  MMisc::error_quit("While trying to set xmllint \'encoding\' (" . $xmlh->get_errormsg() . ")")
      if (! $xmlh->set_encoding('UTF-8'));

  my $tlistfilestring = $xmlh->run_xmllint($tlistf);
  MMisc::error_quit("$tlistf: \'xmllint\' validation failed [" . $xmlh->get_errormsg() . "]\n")
      if ($xmlh->error());

  ## Processing file content

  # Remove all XML comments
  $tlistfilestring =~ s%\<\!\-\-.+?\-\-\>%%sg;
  
  # Remove <?xml ...?> header
  $tlistfilestring =~ s%^\s*\<\?xml.+?\?\>%%is;
  
  # At this point, all we ought to have left is the '<termlist>' content
  MMisc::error_quit("After initial cleanup, we found more than just \'termlist\', aborting")
      if (! ( ($tlistfilestring =~ m%^\s*\<termlist\s%is) && ($tlistfilestring =~ m%\<\/termlist\>\s*$%is) ) );
  my $dem = "Martial's DEFAULT ERROR MESSAGE THAT SHOULD NOT BE FOUND IN STRING, OR IF IT IS WE ARE SO VERY UNLUCKY";
  # and if we extract it, the remaining string should be empty
  
  # for attributes, array order is important
  my $here = 'termlist';
  my @tlist_attrs = ( 'ecf_filename', 'language', 'encoding', 'compareNormalize', 'version' );
  my ($err, $string, $section, %tlist_attr) = &element_extractor_check($dem, $tlistfilestring, $here, \@tlist_attrs);
  MMisc::error_quit($err) if (! MMisc::is_blank($err));
  MMisc::error_quit("After removing '<$here>', found leftover content, aborting")
      if (! MMisc::is_blank($string));
  
  $self->{ECF_FILENAME} = &__get_attr(\%tlist_attr, $tlist_attrs[0]);
  MMisc::error_quit("new TermList failed: " . $self->errormsg())
      if (! $self->setLanguage(&__get_attr(\%tlist_attr, $tlist_attrs[1])));
  MMisc::error_quit("new TermList failed: " . $self->errormsg())
      if (! $self->setEncoding(&__get_attr(\%tlist_attr, $tlist_attrs[2])));
  MMisc::error_quit("new TermList failed: " . $self->errormsg())
      if (! $self->setCompareNormalize(&__get_attr(\%tlist_attr, $tlist_attrs[3])));
  $self->{VERSION} = &__get_attr(\%tlist_attr, $tlist_attrs[4]);
  
  # UTF-8 data pre-processing
  $section = decode_utf8($section)
    if ($self->{ENCODING} eq 'UFT-8');
  
  # process all 'term'
  my %attrib = ();
  my $exp = 'term';
  my @term_attrs = ('termid');
  while (! MMisc::is_blank($section)) {
    # First off, confirm the first section is the expected one
    my $name = MtXML::get_next_xml_name(\$section, $dem);
    MMisc::error_quit("In \'$here\', while checking for \'$exp\': Problem obtaining a valid XML name, aborting")
        if ($name eq $dem);
    MMisc::error_quit("In \'$here\': \'$exp\' section not present (instead: $name), aborting")
        if ($name ne $exp);
    ($err, $section, my $insection, my %term_attr) = &element_extractor_check($dem, $section, $exp, \@term_attrs);
    MMisc::error_quit($err) if (! MMisc::is_blank($err));
    
    $attrib{TERMID} = &__get_attr(\%term_attr, $term_attrs[0]);
    MMisc::error_quit("Term ID $attrib{TERMID} already exists")
        if (exists($self->{TERMS}{$attrib{TERMID}}));
    
    ($err, my $termtext, my %ti_attr) = &process_term_content($insection, $dem);
    MMisc::error_quit($err) if (! MMisc::is_blank($err));
    
    $attrib{TEXT} = $termtext;
    foreach my $name (keys %ti_attr) {
      $attrib{$name} = ($name eq 'Syllables') ? sprintf("%02d", $ti_attr{$name}) : $ti_attr{$name};
    }
    
    $self->{TERMS}{$attrib{TERMID}} = new TermListRecord(\%attrib);
  }
}

#####

sub __get_attr {
  my ($rh, $key) = @_;

  MMisc::error_quit("Requested hash key does not exists ($key)")
      if (! exists $$rh{$key});

  return($$rh{$key});
}

####

sub element_extractor_check {
  my ($dem, $string, $here, $rattr) = @_;

  $string = MMisc::clean_begend_spaces($string);

  (my $err, $string, my $section, my %iattr) = MtXML::element_extractor($dem, $string, $here);
  return("$err $string") if (! MMisc::is_blank($err));

  foreach my $attr (@$rattr) {
    return("Could not find <$here>'s $attr attribute")
      if (! exists $iattr{$attr});
  }

  return("", $string, $section, %iattr);
}

##########

sub process_term_content {
  my ($string, $dem) = @_;

  my @no_attrs = ();
  # get 'termtext'
  (my $err, $string, my $termtext, my %iattr1) = &element_extractor_check($dem, $string, 'termtext', \@no_attrs);
  return($err) if (! MMisc::is_blank($err));

  my %ti_attr = ();
  # if $string is now empty, there was no terminfo
  return("", $termtext, %ti_attr) if (MMisc::is_blank($string));

  # if not empty, it _must_ be a 'terminfo'
  ($err, $string, my $content, my %iattr2) = &element_extractor_check($dem, $string, 'terminfo', \@no_attrs);
  return($err) if (! MMisc::is_blank($err));
  # now it must be empty
  return("After extracting the \'terminfo\', there was some unexpected leftover data, aborting: $string")
    if (! MMisc::is_blank($string));

  my $doit = 1;
  while ($doit) {
    # process 'attr'
    ($err, $content, my $attr, my %iattr3) = &element_extractor_check($dem, $content, 'attr', \@no_attrs);
    return("Processing <terminfo>: $err") if (! MMisc::is_blank($err));
    
    # from <attr>: <name> and <value>
    ($err, $attr, my $name, my %iattr4) = &element_extractor_check($dem, $attr, 'name', \@no_attrs);
    return("Processing <terminfo>'s <attr>: $err") if (! MMisc::is_blank($err));
    ($err, $attr, my $value, my %iattr5) = &element_extractor_check($dem, $attr, 'value', \@no_attrs);
    return("Processing <terminfo>'s <attr>: $err") if (! MMisc::is_blank($err));
    return("After processing <terminfo>'s <attr>: leftover content found, aborting: $attr")
      if (! MMisc::is_blank($attr));
    
    $ti_attr{$name} = $value;

    $doit = 0 if (MMisc::is_blank($content));
  }

  return("", $termtext, %ti_attr);
}

############################################################

sub saveFile
{
    my ($self, $file) = @_;
    
    ### Write to a different file IF defined
    if (defined($file))
    {
		$self->{TERMLIST_FILENAME} = $file
    }

    open(OUTPUTFILE, ">$self->{TERMLIST_FILENAME}") 
      or MMisc::error_quit("cannot open file '$self->{TERMLIST_FILENAME}' : $!");
#    if ($self->{ENCODING} eq "UTF-8"){
#      binmode OUTPUTFILE, $self->getPerlEncodingString();
#    }
 
#    print OUTPUTFILE "<?xml version=\"1.0\" encoding=\"$self->{ENCODING}\"?>\n";
    
    print OUTPUTFILE "<termlist ecf_filename=\"$self->{ECF_FILENAME}\" language=\"$self->{LANGUAGE}\" encoding=\"$self->{ENCODING}\" compareNormalize=\"$self->{COMPARENORMALIZE}\" version=\"$self->{VERSION}\">\n";
    
    foreach my $termid(sort keys %{ $self->{TERMS} })
    {
        print OUTPUTFILE "<term termid=\"$termid\">\n  <termtext>$self->{TERMS}{$termid}->{TEXT}</termtext>\n";
        print OUTPUTFILE "  <terminfo>\n";
        
        foreach my $termattrname(sort keys %{ $self->{TERMS}{$termid} })
        {
            next if( ($termattrname eq "TERMID") || ($termattrname eq "TEXT") );
            print OUTPUTFILE "    <attr>\n      <name>$termattrname</name>\n      <value>$self->{TERMS}{$termid}->{$termattrname}</value>\n    </attr>\n";
        }
        
        print OUTPUTFILE "  </terminfo>\n</term>\n";
    }
    
    print OUTPUTFILE "</termlist>\n";
    
    close OUTPUTFILE;
}

1;

