#!/usr/bin/perl

use strict;
use warnings;
use feature qw|say|;

#package Class;
#use Alpha;

#package Child;
#use Alpha;
#use parent -norequire, 'Class';

package main;
use Data::Dumper;
$Data::Dumper::Indent = 1;
use Getopt::Std;

INIT {}

RUN: {
	MAIN(options());
}

sub options {
	my @opts = (
		['h' => 'help'],
		#['i:' => 'input file (path)'],
		['d:' => 'database']
	);
	getopts (join('',map {$_->[0]} @opts), \my %opts);
	if (! %opts || $opts{h}) {
		say join ' - ', @$_ for @opts;
		exit; 
	}
	$opts{$_} || die "required opt $_ missing\n" for qw||;
	-e $opts{$_} || die qq|"$opts{$_}" is an invalid path\n| for qw||;
	return \%opts;
}

sub MAIN {
	my $opts = shift;
	
	use DBI;
	unlink $opts->{d};
	my $dbh = DBI->connect('dbi:SQLite:dbname='.$opts->{d},'','');
	$dbh->{AutoCommit} = 0;
	
	ODS: {
		$dbh->do(q|create table docs ("bib" int, "lang", "key")|);
		my $sth = $dbh->prepare(q|insert into docs values (?,?,?)|);
		open my $s3, '-|', 'aws s3 ls s3://undhl-dgacm/Drop/docs_new/ --recursive';
		while (<$s3>) {
			chomp;
			my @line = split /\s+/, $_;
			#my ($mdate,$mtime,$size) = @line[0..2];
			my $key = substr $_,31;
			my $bib = (split /\//, $key)[3];
			my $lang = substr $key,-6,2;
			say $key;
			$sth->execute($bib,$lang,$key);			
		}
		$dbh->do(q|create index bib on docs (bib)|);
	}
	
	EXTRAS: {
		$dbh->do(q|create table extras ("bib" int, "lang", "key")|);
		my $sth = $dbh->prepare(q|insert into extras values (?,?,?)|);
		open my $s3, '-|', 'aws s3 ls s3://undhl-dgacm/Drop/extras/ --recursive';
		while (<$s3>) {
			chomp;
			my $key = substr $_,31;
			my $bib = (split /\//, $key)[2];
			my $lang = $1 if $key =~ /\-([^\-]+)\.\w+$/;
			say $key;
			$sth->execute($bib,$lang,$key);	
		}
		$dbh->do(q|create index extras_index on extras (bib)|);
	}
	
	ERRORS: {
		$dbh->do(q|create table error ("bib" int, "lang", "key"|);
	}
	
	$dbh->commit;
}

END {}

__DATA__