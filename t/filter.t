#!perl

use warnings;
use strict;

use Test::More tests => 17;

use CPAN::Mini;

my $self = {
	changes_made => 1,
	force => 1,
};

bless $self, "CPAN::Mini";
################################################
# skip_perl

$self->{skip_perl} = 1;

ok($self->_filter_module({
	module => 'perl',
	version => '0.01',
	path => '/perl-0.01.tar.gz',
}), "perl distro skip check");


ok($self->_filter_module({
	module => 'bioperl',
	version => '0.01',
	path => '/bioperl-0.01.tar.gz',
}), "bioperl distro skip check");

ok($self->_filter_module({
	module => 'embperl',
	version => '0.01',
	path => '/embperl-0.01.tar.gz',
}), "embperl distro skip check");

ok(!$self->_filter_module({
	module => 'notperl',
	version => '0.01',
	path => '/POE-0.01.tar.gz',
}), "POE distro not-skip check");

ok($self->_filter_module({
	module => 'ponie',
	version => '0.01',
	path => '/ponie-0.01.tar.gz',
}), "ponie distro skip check");

ok($self->_filter_module({
	module => 'parrot',
	version => '0.01',
	path => '/parrot-0.01.tar.gz',
}), "parrot distro skip check");

delete $self->{skip_perl};

ok(!$self->_filter_module({
	module => 'perl',
	version => '0.01',
	path => '/perl-0.01.tar.gz',
}), "perl distro no-skip check");


################################################
# path_filters

$self->{path_filters} = qr/skipme/;

ok($self->_filter_module({
	module => 'skipme',
	version => '0.01',
	path => '/skipme-0.01.tar.gz',
}), "path_filters skip check");

ok(!$self->_filter_module({
	module => 'noskip',
	version => '0.01',
	path => '/noskip-0.01.tar.gz',
}), "path_filters no-skip check");


$self->{path_filters} = [ 
	qr/skipme/,
	qr/burnme/,
];

ok($self->_filter_module({
	module => 'skipme',
	version => '0.01',
	path => '/skipme-0.01.tar.gz',
}), "path_filters skip check");

ok($self->_filter_module({
	module => 'burnme',
	version => '0.01',
	path => '/burnme-0.01.tar.gz',
}), "path_filters skip check");


ok(!$self->_filter_module({
	module => 'noskip',
	version => '0.01',
	path => '/noskip-0.01.tar.gz',
}), "path_filters no-skip check");


################################################
# module_filters

$self->{module_filters} = qr/skipme/;

ok($self->_filter_module({
	module => 'skipme',
	version => '0.01',
	path => '/skipme-0.01.tar.gz',
}), "module_filters skip check");

ok(!$self->_filter_module({
	module => 'noskip',
	version => '0.01',
	path => '/noskip-0.01.tar.gz',
}), "module_filters no-skip check");


$self->{module_filters} = [ 
	qr/skipme/,
	qr/burnme/,
];

ok($self->_filter_module({
	module => 'skipme',
	version => '0.01',
	path => '/skipme-0.01.tar.gz',
}), "module_filters skip check");

ok($self->_filter_module({
	module => 'burnme',
	version => '0.01',
	path => '/burnme-0.01.tar.gz',
}), "module_filters skip check");


ok(!$self->_filter_module({
	module => 'noskip',
	version => '0.01',
	path => '/noskip-0.01.tar.gz',
}), "module_filters no-skip check");
