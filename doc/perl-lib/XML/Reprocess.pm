#!/usr/bin/perl

package XML::Reprocess;

our $VERSION     = 1.0;

# This package handle XML trees, and performs node manipulations. As long
# as manipulations are pending, the tree is kept in memory, but there is
# also the possibility of outputting the data quickly when no such
# modification is to be done.

# The bare call XML::Reprocess::parse(*STDIN) should copy verbatim the
# XML structure from STDIN.
#
# However, when called as:
#
# XML::Reprocess::parse(*STDIN, Transformations=> { blah=>\&func });
#
# then all occurences of tag <blah> in the tree will undergo
# transformation by the function func(). The input to func is the subtree
# as with the Tree module to XML::Parser: First the tag, then an array
# hash containing first the attributes, then the (tag, content) pairs for
# the content in the tree. The output should be an array, either empty to
# delete the argument, or any desired number of (tag, content) pairs.
#
# as with the Tree parser, a special tag name '0' is used, in which case
# the content is simply a string.

# OO interface:
# my $p = new XML::Reprocess(Transformations => { ... });
# $p->parse(...)

# In order to obtain the tree as the return value of parse, use Tree=>1
# as an argument (either to new XML::Reprocess or to
# XML::Reprocess::parse)

# xml declarations as well as doctypes should pass unmodified.

use strict;
use warnings;
use base 'XML::Parser';
use Exporter qw(import);
use Carp;

our @EXPORT_OK = qw(parse filter xmlstringify);

sub StartDocument {
    my $ex = $_[0];
    my $tops = [];
    $ex->{'tops'} = $tops;
    if ($ex->{'Reprocess::Tree'}) {
        push @$tops, [ '__toplevel' ] , [ {} ];
    }
}

sub StartTag {
    my $t = $_[1];
    my $tops = $_[0]->{'tops'};
    my $transforms = $_[0]->{'Transformations'};
    # If there is no reprocessing action pending, and if this tag is
    # not going to start one, then we take the default action.
    if (!(exists $transforms->{$t} || scalar @$tops)) { print; return; }

    # Otherwise, stack this as a tree.
    my %tmp = %_; #attribute list
    my $ntop = [ \%tmp ];
    my $n = [ $t, $ntop ];
    if (!scalar @$tops) {
        push @$tops, [ $t ];
        push @$tops, $ntop;
    } else {
        # FIXME: since tree elements might undergo some
        # modifications, it is perhaps wise to append to the
        # current list _later on_ !.
        #push @{$tops->[$#$tops]}, @$n;
        push @{$tops->[$#$tops]}, $t;
        push @$tops, $ntop;
    }
}

# beware.
sub ReEscape {
    my $x = shift @_;
    my %ent = (
        '<' => '&lt;',
        '>' => '&gt;',
        '"' => '&quot;',
        '\'' => '&apos;',
        '&' => '&amp;',
    );
    # External entities are not parsed, so it's not valid to just put
    # &amp; back in !
    $x =~ s/([<>"'])/$ent{$1}/g;
    # $x =~ s/([<>"'&])/$ent{$1}/g;
    # $x =~ s/&amp;([a-zA-Z_:]+;)/&$1/g;
    return $x;
}

use Data::Dumper;
sub Text {
    #print ReEscape($_) unless scalar @tops;
    my $tops = $_[0]->{'tops'};
    my $transforms = $_[0]->{'Transformations'};
    my $t = '0';
    if (!(exists $transforms->{$t} || scalar @$tops)) { print ReEscape($_); return; }
    my $ltop = $$tops[$#$tops];

    my @r = ($t, $_);
    if (my $f = $transforms->{$t}) { @r = &$f(@r); }

    push @$ltop, @r;
}

# # consumes its argument !
# sub shipout {
# 	my $a = shift @_;
# 	while (scalar @$a) {
# 		my $t = shift @$a;
# 		my $v = shift @$a;
# 		if ($t eq '0') {
# 			print $v;
# 			next;
# 		}
# 		my $attr = shift @$v;
# 		my $s = "<$t";
# 		for my $k (keys %$attr) {
# 			my $w = $attr->{$k};
# 			if ($w =~ /"/) {
# 				$s .= " $k='" . $w . "'";
# 			} else {
# 				$s .= " $k=\"" . $w . "\"";
# 			}
# 		}
# 		$s .= ">";
# 		print $s;
# 		&shipout($v);
# 		print "</$t>";
# 	}
# }

# does not consume its argument. perhaps slower.
sub xmlstringify {
    my $a = shift @_;

    croak "xmlstringify not given [ (tag, content) * ]"
    unless ref $a eq 'ARRAY';
    my @xa = @$a;
    my $s = '';
    while (scalar @xa) {
        my $t = shift @xa;
        my $v = shift @xa;
        if ($t eq '0') {
            $s .= $v;
            next;
        }
        croak "xmlstringify not given [ (tag, content) * ]"
        unless ref $v eq 'ARRAY';
        my @xv = @$v;
        my $attr = shift @xv;
        $s .= "<$t";
        croak "xmlstringify not given [ (tag, [ attr, (tag, content)* ] ) * ]"
        unless ref $attr eq 'HASH';
        for my $k (keys %$attr) {
            my $w = $attr->{$k};
            if ($w =~ /"/) {
                $s .= " $k='" . $w . "'";
            } else {
                $s .= " $k=\"" . $w . "\"";
            }
        }
        $s .= ">";
        $s .= &xmlstringify(\@xv);
        $s .= "</$t>";
    }
    return $s;
}


sub EndTag {
    my $t = $_[1];
    my $tops = $_[0]->{'tops'};
    my $transforms = $_[0]->{'Transformations'};
    if (!scalar @$tops) { print; return; }

    my $l = pop @$tops;
    my $otop = $$tops[$#$tops];

    my $ot = pop @$otop;
    die if $t ne $ot;

    my @r = ($t, $l);

    # Note that we may have here an inner level, to which no
    # transformation is applicable.
    if ($transforms->{$t}) {
        @r = &{$transforms->{$t}}(@r);
    }

    push @$otop, @r;

    if (scalar @$tops == 1) {

        print &xmlstringify($otop);
        pop @$tops;
    }
}

sub EndDocument {
    my $ex = shift;
    if ($ex->{'Reprocess::Tree'}) {
        my $tops = $ex->{'tops'};
        die unless scalar @$tops == 2;
        die unless scalar @{$tops->[0]} == 1;
        die unless $tops->[0]->[0] eq '__toplevel';
        my $doc = $tops->[1];
        shift @$doc;
        return $doc;
    }
}

sub print_doctype {
    my ($expat, $name, $sysid, $pubid, $internal) = @_;
    # this is of course improper for most uses.
    my $s = "<!DOCTYPE $name";
    if (defined($pubid)) {
        $s .= " PUBLIC \"$pubid\" \"$sysid\"";
    } elsif (defined($sysid)) {
        $s .= " SYSTEM \"$sysid\"";
    }
    if ($internal) {
        $s .= " [$internal]";
    }
    $s .= ">\n";
    print $s;
}

sub print_xmldecl {
    my ($expat, $version, $encoding, $standalone) = @_;
    my $s = "<?xml version=\"$version\"";
    $s .= " encoding=\"$encoding\"" if $encoding;
    $s .= " standalone=\"$standalone\"" if $standalone;
    $s .= "?>\n";
    print $s;
}

sub fallback_for_entities {
    my $e = shift @_;
    my $s = shift @_;
    if ($s && $s =~ /^&.*;$/) {
        $e->{'Text'} .= $s;
    }
}


sub new {
    my $class = shift @_;
    my %hash = @_;
    my $transforms = $hash{'Transformations'} || {};
    delete $hash{'Transformations'};
    my $p = new XML::Parser( Style => 'Stream' );
    # $p->setHandlers('ExternEnt', \&ent);
    $p->setHandlers('Default', \&fallback_for_entities);
    $p->setHandlers('Doctype', \&print_doctype);
    $p->setHandlers('XMLDecl', \&print_xmldecl);

    if (my $hh = $hash{'Handlers'}) {
        for my $k (keys %$hh) {
            $p->setHandlers($k, $hh->{$k});
        }
        delete $hash{'Handlers'};
    }

    for my $k (qw/Tree/) {
        if (my $hh = $hash{$k}) {
            $p->{'Reprocess::' . $k} = $hh;
            delete $hash{$k};
        }
    }
    if (ref $transforms ne 'HASH') {
        my $pkg = 'main';
        if (my $x = $hash{'Pkg'}) {
            $pkg = $x;
            delete $hash{'Pkg'};
        }

        my $h = {};
        my $k = $::{$pkg . '::'};
        my @x;
        if (ref $transforms eq 'ARRAY') {
            @x = @$transforms;
        } elsif (ref $transforms eq '' && $transforms eq '*') {
            # take everybody.
            @x = keys %$k;
        } else {
            croak "bad Transforms($transforms)/Pkg($pkg) combination";
        }
        for my $f (@x) {
            $h->{$f} = $k->{$f};
        }
        $transforms = $h;
    }
    croak "trailing arguments " . join(', ', keys %hash)
    if scalar keys %hash;
    $p->{'Transformations'}=$transforms;
    bless $p, $class;
    return $p;
}

sub filter {
    # carp "legacy call, use ::parse instead";
    my $glob = shift @_;
    my $p = new XML::Reprocess(@_);
    $p->SUPER::parse($glob);
}

sub parse {
    my $glob = shift @_;
    my $p = new XML::Reprocess(@_);
    $p->SUPER::parse($glob);
}

1;
