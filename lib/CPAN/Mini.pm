package CPAN::Mini;
our $VERSION = '0.24';

use strict;
use warnings;

=head1 NAME

CPAN::Mini - create a minimal mirror of CPAN

=head1 VERSION

version 0.24

 $Id: Mini.pm,v 1.14 2004/11/29 21:06:32 rjbs Exp $

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
use File::Basename qw(basename dirname);
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
update the local mirror with the files from the remote mirror.   

C<update_mirror> creates an ephemeral CPAN::Mini object on which other
methods are called.  That object is used to store mirror location and state.

This method returns the number of files updated.

The following options are recognized:

=over 4

=item * C<dirmode>

Generally an octal number, this option sets the permissions of created
directories.  It defaults to 0711.

=item * C<force>

If true, this option will cause CPAN::Mini to read the entire module list and
update anything out of date, even if the module list itself wasn't out of date
on this run.

=item * C<skip_perl>

If true, CPAN::Mini will skip the major language distributions: perl, parrot,
and ponie.

=item * C<trace>

If true, CPAN::Mini will print status messages to STDOUT as it works.

=item * C<path_filters>

This options provides a set of regexps for filtering paths.  If a distribution
matches one of the regexps in C<path_filters>, it will not be mirrored.  For
example, the following setting would skip all distributions from RJBS and
SUNGO:

 path_filters => [
   qr/RJBS/,
   qr/SUNGO/,
 ]

=item * C<module_filters>

This options provides a set of regexps for filtering modules.  It behaves like
path_filters, but acts only on module names.  (Since most modules are in
distributions with more than one module, this setting will probably be less
useful than C<path_filters>.)  For example, this setting will skip any
distribution containing only modules with the word "Acme" in them:

 module_filters => [ qr/Acme/i ]

=back

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
		next if $self->_filter_module({
			module  => $module,
			version => $version,
			path    => $path,
		});

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

=begin devel

=head2 C<< _filter_module({ module => $foo, version => $foo, path => $foo }) >>

This internal-only method encapsulates the logic where we figure out if a
module is to be mirrored or not. Better stated, this method holds the filter
chain logic. C<update_mirror()> takes an optional set of filter parameters.  As
C<update_mirror()> encounters a distribution, it calls this method to figure
out whether or not it should be downloaded. The user provided filters are taken
into account. Returns 1 if the distribution is filtered (to be skipped).
Returns 0 if the distribution is to not filtered (not to be skipped).

=end devel

=cut

sub _filter_module {
	my $self = shift;
	my $args = shift;
 
	if($self->{skip_perl}) {
		return 1 if $args->{path} =~ m{/(?:emb|syb|bio)*perl-\d}i;
		return 1 if $args->{path} =~ m{/(?:parrot|ponie)-\d}i;
	}

 if ($self->{path_filters}) {
		if (ref $self->{path_filters} && ref $self->{path_filters} eq 'ARRAY') {
			foreach my $filter (@{ $self->{path_filters} }) {
				return 1 if $args->{path} =~ $filter;
			}
		} else {
			return 1 if $args->{path} =~ $self->{path_filters};
		}
	}

	if ($self->{module_filters}) {
		if (ref $self->{module_filters} && ref $self->{module_filters} eq 'ARRAY') {
			foreach my $filter (@{ $self->{module_filters} }) {
				return 1 if $args->{module} =~ $filter;
			}
		} else {
			return 1 if $args->{module} =~ $self->{module_filters};
		}
	}

	return 0;
}

=head2 C<< file_allowed($file) >>

This method returns true if the given file is allowed to exist in the local
mirror, even if it isn't one of the required mirror files.

By default, only dot-files are allowed.

=cut

sub file_allowed {
	my ($self, $file) = @_;
	return if $self->{exact_mirror};
	return (substr(basename($file),0,1) eq '.') ? 1 : 0;
}

=head2 C<< clean_unmirrored >>

This method finds any files in the local mirror which are no longer needed and
removes them.

=cut

sub clean_unmirrored {
	my $self = shift;

	find sub {
		my $file = canonpath($File::Find::name);
		return unless (-f $file and not $self->{mirrored}{$file});
		return if $self->file_allowed($file);
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

Thanks to Shawn Sorichetti for fixing a stupid octal-number-as-string bug.

Thanks to sungo for implementing the filters, so I can finally stop mirroring
bioperl.

=head1 AUTHORS

Randal Schwartz <F<merlyn@stonehenge.com>> did all the work. 

Ricardo SIGNES <F<rjbs@cpan.org>> made a module and distribution.

This code was copyrighted in 2004, and is released under the same terms as Perl
itself.

=cut

1;
