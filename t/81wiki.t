#!/usr/bin/perl

use Test::More;

use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib", "$Bin/../etc";
use Opsview::Wiki;

my %tests = (
    '= title ='         => '<h1>title</h1>',
    '== title =='       => '<h2>title</h2>',
    '=== title ==='     => '<h3>title</h3>',
    '==== title ===='   => '<h4>title</h4>',
    '===== title =====' => '<h5>title</h5>',
    "''italic''"        => '<p><em>italic</em></p>',
    "'''bold'''"        => '<p><strong>bold<\/strong></p>',
    '----'              => '<hr />',
    '[http://server/link/to/page]' =>
      '<p><a href="http://server/link/to/page">http://server/link/to/page</a></p>',
    '[http://server/link/to/new/page|page title]' =>
      '<p><a href="http://server/link/to/new/page">page title</a></p>',
    "    * item 1\n    * item 2\n" =>
      "<ul>\n<li>item 1</li>\n<li>item 2</li>\n</ul>\n",
    "    1. item 1\n    2. item 2\n" =>
      "<ol>\n<li value=\"1\">item 1</li>\n<li value=\"2\">item 2</li>\n</ol>\n",
    '      print scalar keys %hash' =>
      "<pre><code>print scalar keys %hash\n</code></pre>",
);

my %todo_tests = ( "'''''bold and italic'''''" =>
      '<p><strong><em>bold and italic</em><\/strong></p>', );

plan tests => ( scalar keys %tests ) + ( scalar keys %todo_tests );

foreach my $wiki ( keys(%tests) ) {
    like( Opsview::Wiki->convert_to_html($wiki),
        qr{^$tests{$wiki}}s, "'$wiki' ok" );
}

{
    local $TODO = "Tests need fix upstream";

    foreach my $wiki ( keys(%todo_tests) ) {
        like( Opsview::Wiki->convert_to_html($wiki),
            qr{^$todo_tests{$wiki}}, "'$wiki' ok" );
    }
}
