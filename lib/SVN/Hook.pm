package SVN::Hook;
use strict;
use warnings;
our $VERSION = '0.28';

=head1 NAME

SVN::Hook - Managing subversion hooks

=head1 SYNOPSIS

 my $hooks = SVN::Hook->new({ repospath => '/path/to/repos' });

 $hooks->init($_) for SVN::Hook->ALL_HOOKS;

 my $pre_commit = $hooks->scripts('pre-commit');
 print $_->path."\n" for (@$pre_commit);

=head1 DESCRIPTION

C<SVN::Hook> provides a programmable interface to manage hook scripts
for Subversion.  See L<svnhook> for the CLI usage.

=cut

use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw(repospath));

use SVN::Hook::Script;
use constant ALL_HOOKS =>
  qw<post-commit post-lock post-revprop-change post-unlock pre-commit
     pre-lock pre-revprop-change pre-unlock start-commit>;

use Cwd 'abs_path';
sub _this_perl {
    return join(' ', $^X, map { "-I$_" } map { abs_path($_) } @INC);

}

use File::Spec::Functions 'catfile';
use Path::Class;
sub hook_path {
    my ($self, $hook) = @_;
    return Path::Class::Dir->new($self->repospath)->subdir('hooks')->file($hook);
}

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    die $self->repospath." is not a svn repository.\n"
	unless -e catfile($self->repospath, 'format');
    return $self;
}

sub init {
    my ($self, $hook) = @_;
    my $path = $self->hook_path($hook);
    die "There is already $hook file.\n" if -e $path;

    my $svnlook = $ENV{SVNLOOK} || 'svnlook';
    $self->_install_perl_hook( $path, <<"EOF");
# Generated by svnhook version $VERSION.
# This $hook hook is managed by svnook.

BEGIN {
  \$ENV{SVNLOOK} = "$svnlook";
  eval 'require SVN::Hook::Redispatch; 1' or exit 0;
}
use SVN::Hook::Redispatch {
  ''     => '',
# Add other dispatch mapping here:
# 'foo'  => 'bar'
# will run scripts under _$hook/bar/ when commit are solely within foo.
}, \@ARGV;
exit 0;
EOF

    mkdir catfile($self->repospath, 'hooks', "_$hook") or die $!;
}

sub _install_perl_hook {
    my ($self, $hook_file, $perl_code) = @_;
    my $perl = _this_perl();
    open my $fh, '>', $hook_file or die "$hook_file: $!";
    print $fh "#!$perl\n$perl_code";
    close $fh;
    chmod 0755, $hook_file or die $!;
}

sub scripts {
    my ( $self, $hook ) = @_;
    SVN::Hook::Script->load_from_dir($self->hook_path("_$hook"));
}

sub run_hook {
    my $self  = shift;
    my $hook  = shift;
    my $ignore_error = $hook =~ m/^post-/? 1 : 0;

    $self->run_scripts( [grep { $_->enabled } $self->scripts($hook)],
			 $ignore_error, @_ );
}

sub run_scripts {
    my $self    = shift;
    my $scripts = shift;

    my $ignore_error = shift;

    for my $script (@$scripts) {
	system($script->path, @_);

	if ($? == -1) {
	    die "Failed to execute $_: $!.\n";
	}
	elsif ($?) {
	    exit ($? >> 8) unless $ignore_error;
	}
    }
    return 0;
}

sub status {
    my $self = shift;
    my $result;
    for (ALL_HOOKS) {
	my $path = $self->hook_path($_);
	if (-x $path) {
	    open my $fh, '<', $path or die $!;
	    local $/;
	    if (<$fh> =~ m/managed by svnook/) {
		$result->{$_} = scalar $self->scripts($_);
		next;
	    }
	}
	$result->{$_} = undef;
    }
    return $result;
}

=head1 TODO

=over

=item *

CLI to manage enable/disable scripts

=item *

CLI to display and dry-run for subdir scripts for redispatch

=item *

More tests and doc

=back

=head1 LICENSE

Copyright 2007 Best Practical Solutions, LLC.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 AUTHORS

Chia-liang Kao E<lt>clkao@bestpractical.com<gt>

=cut

1;
