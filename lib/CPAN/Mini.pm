package CPAN::Mini;
our $VERSION = '0.18';

use strict;
use warnings;

=head1 NAME

CPAN::Mini - create a minimal mirror of CPAN

=head1 VERSION

version 0.18

 $Id: Mini.pm,v 1.11 2004/09/22 00:17:32 rjbs Exp $

=head1 SYNOPSIS

(If you're not going to do something weird, you probably want to look at the
L<minicpan> command, instead.)

 use CPAN::Mini;

 CPAN::Mini->update_mirror(
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
use File::Spec::Functions qw(catfile canonpath);
use File::Find qw(find);

use URI ();
use LWP::Simple qw(mirror RC_OK RC_NOT_MODIFIED);

use Compress::Zlib qw(gzopen $gzerrno);

=head1 METHODS

=head2 C<< update_mirror( %args ) >>

 CPAN::Mini->update_mirror(
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

The C<dirmode> option (generally an octal number) sets the permissions of
created directories.  It defaults to 0711.

This method returns the number of files updated.

=cut

sub update_mirror {
	my $class    = shift;
	my %defaults = (changes_made => 0, dirmode => 0711, mirrored => {});
	my $self   = bless { %defaults, @_ } => $class;
	croak "no local mirror supplied"  unless $self->{local};
	croak "no remote mirror supplied" unless $self->{remote};

	# mirrored tracks the already done, keyed by filename
	# 1 = local-checked, 2 = remote-mirrored
	$self->mirror_indices;
	
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
		next if
			$self->{skip_perl} and
			$path =~ m{/(?:perl|parrot|ponie)-\d};  # skip the languages
		$self->mirror_file("authors/id/$path", 1);
	}

	# eliminate files we don't need
	$self->clean_unmirrored;
	return $self->{changes_made};
}

=head2 C<< mirror_indices >>

This method updates the index files from the CPAN.

=cut

sub mirror_indices {
	my $self = shift;

	$self->mirror_file($_) for qw(
	                              authors/01mailrc.txt.gz
	                              modules/02packages.details.txt.gz
	                              modules/03modlist.data.gz
	                             );
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

		mkpath(dirname($local_file), $self->{trace}, $self->{dirmode});
		$self->trace($path);
		my $status = mirror($remote_uri, $local_file);

		if ($status == RC_OK) {
			$checksum_might_be_up_to_date = 0;
			$self->trace(" ... updated\n");
			$self->{changes_made}++;
		} elsif ($status != RC_NOT_MODIFIED) {
			warn "\n$remote_uri: $status\n";
			return;
		} else {
			$self->trace(" ... up to date\n");
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
		my $file = canonpath($File::Find::name);
		return unless -f $file and not $self->{mirrored}{$file};
		$self->trace("$file ... removed\n");
		unlink $file or warn "Cannot remove $file $!";
	}, $self->{local};
}

=head2 C<< trace( $message, $force ) >>

If the object is mirroring verbosely, this method will print messages sent to
it.  If CPAN::Mini is not operating in verbose mode, but C<$force> is true, it
will print the message anyway.

=cut

sub trace {
	my ($self, $message, $force) = @_;
	print "$message" if $self->{trace} or $force;
}

=head1 SEE ALSO

Randal Schwartz's original article on minicpan, here:

	http://www.stonehenge.com/merlyn/LinuxMag/col42.html

L<CPANPLUS::Backend>, which provides the C<local_mirror> method, which performs
the same task as this module.

=head1 THANKS

Thanks to David Dyck for letting me know about my stupid documentation errors.

Thanks to Roy Fulbright for finding an obnoxious bug on Win32.

=head1 AUTHORS

Randal Schwartz <F<merlyn@stonehenge.com>> did all the work. 

Ricardo SIGNES <F<rjbs@cpan.org>> made a module and distribution.

This code was copyrighted in 2004, and is released under the same terms as Perl
itself.

=cut

1;
