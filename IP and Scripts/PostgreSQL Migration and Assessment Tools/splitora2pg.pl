#!/usr/bin/perl
#
# initially created by Bram Pahlawanto
# $Author: bpahlawa $
# $Id: splitora2pg.pl 274 2020-04-24 03:29:09Z bpahlawa $
# $Date: 2020-04-24 13:29:09 +1000 (Fri, 24 Apr 2020) $
# $Revision: 274 $
#


use strict;
use DBI;
my $driver= "Oracle";
my $ora2pgconf= "ora2pg.conf";
my $line= undef;
my @lines=undef;
my $dsn=undef
my $orauser=undef;
my $orapwd=undef;
my $dbh=undef;
my $sth=undef;
my $oraclehome=undef;
my $schemaname=undef;
my $thelist=undef;
my $outputfile=undef;
my $noofcols=undef;
my $prefix=undef;
my $pprefix=undef;
my $theprevlist=undef;


sub exit_prog {
    print "\nExiting due to ctrl+c was pressed!...\n\n";
    exit(0);
}


if ($#ARGV < 1 ) {
	print "usage: splitora2pg.pl query no_of_objects\n";
	exit;
}

my $query = $ARGV[0];
my $noofobj = $ARGV[1];


$SIG{INT}  = \&exit_prog;
$SIG{TERM} = \&exit_prog;


unless ( -e $ora2pgconf ) {
   $ora2pgconf = "/etc/ora2pg/$ora2pgconf";
   unless ( -e $ora2pgconf ) { 
      print "$ora2pgconf doesnt exists";
      exit;
   }
}


print "Configuration file to be used: $ora2pgconf\n";

open (my $fh, '<', $ora2pgconf) or die "Could not open '$ora2pgconf' $!\n";

#Filter out ora2pg.conf file 
while ($line = <$fh>)
{
   ($line =~ /(^|^\s+)ORACLE_.*$|(^|^\s+)SCHEMA[\s\t]+.*$|(^|^\s+)OUTPUT[\s\t]+.*$/g) ? push(@lines,$line) : next;
}
close $fh;

#Get only few lines from ora2pg.conf such as oracle connect string info, outputfile and schema name 
foreach (@lines)
{
   chomp;
   $dsn = $_ if ($_ =~ /(^|^\s+)ORACLE_DSN.*$/g);
   $orauser = $_ if ($_ =~ /(^|^\s+)ORACLE_USER.*$/g);
   $orapwd = $_ if ($_ =~ /(^|^\s+)ORACLE_PWD.*$/g);
   $oraclehome = $_ if ($_ =~ /(^|^\s+)ORACLE_HOME.*$/g);
   $outputfile = $_ if ($_ =~ /(^|^\s+)OUTPUT.*$/g);
   $schemaname = uc $_ if ($_ =~ /(^|^\s+)SCHEMA.*$/g);
}


$dsn =~ s/(^|^\s+)ORACLE_DSN\s+(.*)$/$2/g;
$orauser =~ s/(^|^\s+)ORACLE_USER\s+(.*)$/$2/g;
$orapwd =~ s/(^|^[\s]+)ORACLE_PWD\s+(.*)$/$2/g;
$schemaname =~ s/(^|^[\s]+)SCHEMA\s+(.*)$/$2/g;
$outputfile =~ s/(^|^[\s]+)OUTPUT\s+(.*)$/$2/g;


#Replace query which has word SCHEMA to the schemaname that is set in ora2pg.conf
$query =~ s/SCHEMA/$schemaname/g;

die "Unable to find either ORACLE_DSN, ORACLE_USER or ORACLE_PWD in $ora2pgconf file\n" if ($dsn eq "" or $orauser eq "" or $orapwd eq "");

print "Runing Query:\n$query\n";

my $dbh = DBI->connect($dsn, $orauser, $orapwd);
# prepare and execute the SQL statement
my $sth = $dbh->prepare($query);
$sth->execute;

my $counter=0;
my $batchno=1;

$noofcols= $sth->{NUM_OF_FIELDS};


# retrieve the results
while(  my $ref = $sth->fetchrow_arrayref() ) {
    $counter++;
	$thelist = $thelist . " " . $ref->[0];
	

	if ($noofcols > 1) { $prefix=$ref->[1]; } else { $prefix=$schemaname; }
	
	if ($pprefix eq undef) { $pprefix=$prefix; } 

    if ($pprefix ne $prefix)
    {
	    
	    $theprevlist = $thelist;
		$thelist =~ s/(.*) (.*)/$1/g;
		$theprevlist =~ s/(.*) (.*)/$2/g;
		print "\nList objects:\n$thelist\n";
		print "Running ora2pg with output \"$batchno" . "_" . $pprefix . "_" . $outputfile . "\"\n";
	    exec("ora2pg -c $ora2pgconf -a \"$thelist\" -o \"$batchno" . "_" . $pprefix . "_" . $outputfile . "\"");
		$batchno++;
		$pprefix=$prefix;
		$thelist=$theprevlist;
	    $counter=0;
		
		
	}
    else
	{
		if ($counter >= $noofobj)
		{
			
		
			print "\nList objects:\n$thelist\n";
			print "Running ora2pg with output \"$batchno" . "_" . $prefix . "_" . $outputfile . "\"\n";
			system("ora2pg -c $ora2pgconf -a \"$thelist\" -o \"$batchno" . "_" . $prefix . "_" . $outputfile . "\"");
			$thelist="";
			$counter=0;
			$batchno++;
		}
	}
}


if ($counter<$noofobj && $thelist ne "")
{
    print "\nList objects:\n$thelist\n";
    print "Running ora2pg with output \"$batchno" . "_" . $prefix . "_" . $outputfile . "\"\n";
    system("ora2pg -c $ora2pgconf -a \"$thelist\" -o \"$batchno" . "_" . $prefix . "_" . $outputfile . "\"");
}

exit;
