#!/usr/bin/perl -w
package CPAN::Mini;
our $VERSION = '0.10';

use strict;
use warnings;

=head1 NAME

CPAN::Mini -- create a minimal mirror of CPAN

=head1 VERSION

version 0.10

 $Id: Mini.pm,v 1.3 2004/08/26 14:52:08 rjbs Exp $

=head1 SYNOPSIS

(If you're not going to do something weird, you probably want to look at the
L<minicpan> command, instead.)

 use CPAN::Mini;

 CPAN::Mini->mirror(
  remote => "http://cpan.mirrors.comintern.su",
  local  => "/usr/share/mirrors/cpan",
  trace  => 1
 );

=head1 DESCRIPTION

CPAN::Mini provides a simple mechanism to build and update a minimal mirror of
the CPAN on your local disk.  It contains only those files needed to install
the newest version of every distribution.  Those files are:

=over 4

=item * 01mailrc.txt.gz

=item * 02packages.details.txt.gz

=item * 03modlist.data.gz

=item * the last non-developer release of every dist for every author

=back

=cut

use Carp;

use File::Path qw(mkpath);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use File::Find qw(find);

use URI ();
use LWP::Simple qw(mirror RC_OK RC_NOT_MODIFIED);

use Compress::Zlib qw(gzopen $gzerrno);

=head1 METHODS

=head2 C<< update_mirror( %args ) >>

 CPAN::Mini->mirror(
  remote => "http://cpan.mirrors.comintern.su",
  local  => "/usr/share/mirrors/cpan",
	force  => 0,
  trace  => 1
 );

This is the only method that need be called from outside this module.  It will
update the local mirror with the files from the remote mirror.  If the C<trace>
option is true, CPAN::Mini will print status messages as it runs.

C<update_mirror> creates an ephemeral CPAN::Mini object on which other
methods are called.  That object is used to store mirror location and state.

This method returns the number of files updated.

=cut

sub update_mirror {
	my $class  = shift;
	my $self   = bless { changes_made => 0, mirrored => {}, @_ } => $class;
	croak "no local mirror supplied"  unless $self->{local};
	croak "no remote mirror supplied" unless $self->{remote};

	# mirrored tracks the already done, keyed by filename
	# 1 = local-checked, 2 = remote-mirrored

	## first, get index files
	$self->mirror_file($_) for qw(
	                              authors/01mailrc.txt.gz
	                              modules/02packages.details.txt.gz
	                              modules/03modlist.data.gz
	                             );
	
	return unless $self->{force} or $self->{changes_made};

	# now walk the packages list
	my $details = catfile($self->{local}, qw(modules 02packages.details.txt.gz));
	my $gz = gzopen($details, "rb") or die "Cannot open details: $gzerrno";
	my $inheader = 1;
	while ($gz->gzreadline($_) > 0) {
		if ($inheader) {
			$inheader = 0 unless /\S/;
			next;
		}

		my ($module, $version, $path) = split;
		next if $path =~ m{/perl-5};  # skip Perl distributions
		$self->mirror_file("authors/id/$path", 1);
	}

	## finally, clean the files we didn't stick there
	$self->clean_unmirrored;
	return $self->{changes_made};
}

=head2 C<< mirror_file($path, $skip_if_present) >>

This method will mirror the given file from the remote to the local mirror,
overwriting any existing file unless C<$skip_if_present> is true.

=cut

sub mirror_file {
	my $self   = shift;
	my $path   = shift;           # partial URL
	my $skip_if_present = shift;  # true/false

	my $remote_uri = URI->new_abs($path, $self->{remote})->as_string; # full URL
	my $local_file = catfile($self->{local}, split "/", $path); # native absolute file
	my $checksum_might_be_up_to_date = 1;

	if ($skip_if_present and -f $local_file) {
		## upgrade to checked if not already
		$self->{mirrored}{$local_file} = 1 unless $self->{mirrored}{$local_file};
	} elsif (($self->{mirrored}{$local_file} || 0) < 2) {
		## upgrade to full mirror
		$self->{mirrored}{$local_file} = 2;

		mkpath(dirname($local_file), $self->{trace}, 0711);
		print $path if $self->{trace};
		my $status = mirror($remote_uri, $local_file);

		if ($status == RC_OK) {
			$checksum_might_be_up_to_date = 0;
			print " ... updated\n" if $self->{trace};
			$self->{changes_made}++;
		} elsif ($status != RC_NOT_MODIFIED) {
			warn "\n$remote_uri: $status\n";
			return;
		} else {
			print " ... up to date\n" if $self->{trace};
		}
	}

	if ($path =~ m{^authors/id}) { # maybe fetch CHECKSUMS
		my $checksum_path =
			URI->new_abs("CHECKSUMS", $remote_uri)->rel($self->{remote});
		if ($path ne $checksum_path) {
			$self->mirror_file($checksum_path, $checksum_might_be_up_to_date);
		}
	}
}

=head2 C<< clean_unmirrored >>

This method finds any files in the local mirror which are no longer needed and
removes them.

=cut

sub clean_unmirrored {
	my $self = shift;

	find sub {
		return unless -f and not $self->{mirrored}{$File::Find::name};
		print "$File::Find::name ... removed\n" if $self->{trace};
		unlink $_ or warn "Cannot remove $File::Find::name: $!";
	}, $self->{local};
}

=head1 SEE ALSO

Randal Schwartz's original article on minicpan, here:

	http://www.stonehenge.com/merlyn/LinuxMag/col42.html

L<CPANPLUS::Backend>, which provides the C<local_mirror> method, which performs
the same task as this module.

=head1 AUTHORS

Randal Schwartz <F<merlyn@stonehenge.com>> did all the work. 

Ricardo SIGNES <F<rjbs@cpan.org>> made a module and distribution.

This code was copyrighted in 2004, by Randal Schwartz.

=cut

1;
