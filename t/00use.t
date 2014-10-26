#!/usr/bin/perl -w

use Test::More;
use File::Spec;
use File::Basename qw( dirname );

my %mods_to_skip = ();
my $manifest = File::Spec->catdir( dirname(__FILE__), '..', 'MANIFEST' );
plan skip_all => 'MANIFEST does not exist' unless -e $manifest;
open FH, $manifest;

my @pms = map { s|^lib/||; chomp; $_ } grep { m|^lib/.*pm$| } <FH>;

plan tests => scalar @pms;
for my $pm (@pms) {
    $pm =~ s|\.pm$||;
    $pm =~ s|/|::|g;

    SKIP: {
        skip "Skipping $pm", 1 if $mods_to_skip{$pm};
        use_ok ($pm);
    }
}
