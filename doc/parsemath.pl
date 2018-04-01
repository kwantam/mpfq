#!/usr/bin/perl

BEGIN { push @INC, "perl-lib"; }

use strict;
use warnings;

use encoding 'utf-8';

use XML::Reprocess 1.0 qw(parse);
use Digest::MD5 qw(md5_hex);
use POSIX qw(floor ceil);

my $htmlonly = 0;

# {{{ Configuration
my $tmpdir = "/tmp";
my $cachedir = "math_cache";
my $htmldir = "html";
# subdir of $htmldir
my $mathdir = "math";

# Default postscript rendering is 72dpi. Changing this has the
# unfortunate effect of also scaling the images, which is not necessarily
# intended.
my $resolution = 120;

my $tex_prologue = <<EOF;
\\nonstopmode
\\documentclass[12pt]{article}
\\usepackage{amsmath,amssymb}
\\usepackage[utf8]{inputenc}
\\pagestyle{empty}
EOF
# }}}

while (scalar @ARGV) {
    $_ = shift @ARGV;
    if (/^--html$/) { $htmlonly = 1; next; }
    if (/^--htmldir=(.*)$/) { $htmldir = $1; next; }
    if (/^--cachedir=(.*)$/) { $cachedir = $1; next; }
    if (/^--tmpdir=(.*)$/) { $tmpdir = $1; next; }
    if (/^--mathdir=(.*)$/) { $mathdir = $1; next; }
    die "usage : parsemath.pl [options -- see source code]\n";
}

# {{{ This hack is to detect in advance where the baseline will fit.
# With these settings, it should be at 442pt.  Disable and leave
# $expected_baseline undefined if this feature is not desired.
my $expected_baseline = 442;
$tex_prologue .= <<EOF;
\\topskip 400bp
\\topmargin 0pt
\\headheight 0pt
\\headsep 0pt
\\oddsidemargin 0pt
\\evensidemargin\\oddsidemargin
\\marginparwidth 0pt
\\textheight 842bp
\\textwidth 595bp
\\hoffset-1in
\\voffset-1in
\\footskip 0pt
\\parindent 0pt
EOF
#}}}

mkdir $cachedir unless -d $cachedir;
mkdir $htmldir unless -d $htmldir;
mkdir "$htmldir/$mathdir" unless -d "$htmldir/$mathdir";

sub round {
    my $x = shift @_;
    my $l = $x - floor $x;
    my $h = ceil $x - $x;
    if ($l < $h) {
        return floor $x;
    } else {
        return ceil $x;
    }
}

sub bbox {
    # gs-bbox has the nasty idea of outputing useful information to
    # stderr.
    my @x = `gs -dNOPAUSE -dBATCH -sDEVICE=bbox -dQUIET -dQUIT $_[0] 2>&1`;
    my @dims;
    for (@x) {
        if (/^\%\%BoundingBox:\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/) {
            @dims = ($1, $2, $3, $4);
        }
        if
        (/^\%\%HiResBoundingBox:\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)$/) {
            @dims = ($1, $2, $3, $4);
        }
    }
    die "bad bbox" unless @dims;
    return @dims;
}

# Takes a TeX expression and a filename base, and produces
# "$htmldir/$mathdir/$fname.png" ; returns also the desired sinking amout
# in pixels
sub texit {
    my $text = shift @_;
    my $md = shift @_;
    $md =~ /^\w+$/ || die "bad filename";

    if (-e "$htmldir/$mathdir/$md.png") {
        if (!defined($expected_baseline)) {
            return undef;
        }
        if (-e "$cachedir/$md.cache") {
            my $x;
            { local $/=undef;
                $x=`cat $cachedir/$md.cache`;
            }
            chomp($x);
            return $x;
        }
    }
    my @files = ();
    my $base = "$tmpdir/" . $md;

    print STDERR "TeX-ing expression: $text\n";

    push @files, "$base.tex";
    open my $tex, ">$base.tex";
    print $tex $tex_prologue;
    print $tex "\\begin{document}\n";
    print $tex "\\ensuremath{$text}\n";
    print $tex "\\end{document}\n";
    close $tex;

    push @files, "$base.aux";
    push @files, "$base.dvi";
    system "cd $tmpdir ; latex $base.tex > /dev/null";

    push @files, "$base.ps";
    system "dvips -t a4 -q -R $base.dvi -o $base.ps";

    my ($llx, $lly, $urx, $ury) = bbox "$base.ps";

    my $sink;
    if (defined($expected_baseline)) {
        $sink = $expected_baseline - $lly;
        $sink *= $resolution / 72;
        # print STDERR "sink: $sink\n";
        $sink = round($sink);
        if ($sink <= 0) { $sink = undef; }
    }

    # Do everything at high precision
    my $w = $urx - $llx;
    my $h = $ury - $lly;
    $llx *= $resolution / 72;
    $lly *= $resolution / 72;
    $w   *= $resolution / 72;
    $h   *= $resolution / 72;

    # approximate the crop box
    $w += $llx - floor($llx); $w = ceil($w);
    $h += $lly - floor($lly); $h = ceil($h);
    $llx = floor($llx);
    $lly = floor($lly);

    # :-< something rotten with pnmtopng, apparently.
    system "convert -gravity SouthWest -crop '${w}x${h}+${llx}+${lly}' -quality 100 -density $resolution $base.ps $htmldir/$mathdir/$md.png 2>/dev/null\n";

    # # Create transparent images. Easy, in fact.
    # my $pgm = "$base.pgm";
    # push @files, $pgm;
    # system "convert -gravity SouthWest -crop '${w}x${h}+${llx}+${lly}' -quality 100 -density $resolution $base.ps pgm:- | pnminvert > $pgm";
    # system "pbmmake -black $w $h | pnmtopng -alpha=$pgm > $htmldir/$mathdir/$md.png 2>/dev/null\n";

    for (@files) { unlink $_; }

    if (defined($sink)) {
        open F, ">$cachedir/$md.cache";
        print F "$sink\n";
        close F;
    }
    return $sink;
}

sub dump_attrs {
    my $r = shift @_;
    local $_;
    my $x = '';
    for (@_) {
        next unless $r->{$_};
        $x .= " $_=\"$r->{$_}\""; 
    }
    return $x;
}

sub transform_math {
    my ($tag, $content) = @_;

    die if ref $content ne 'ARRAY';
    die if scalar @$content != 3;
    die if $content->[1] ne '0';

    my $attr = $content->[0];
    my $text = $content->[2];

    $text =~ s/^\s*//g;
    $text =~ s/\s*$//g;
    my $inline='';
    my $md = md5_hex $text;
    my $sink = texit($text, $md);

    if (!exists($attr->{'image'})) { $attr->{'image'} = "$mathdir/$md.png"; }

    if (!exists($attr->{'style'}) && defined($sink)) {
        $attr->{'style'} = "vertical-align: -${sink}px;";
    }

    my @ret;

    if ($htmlonly) {
        my $img = $attr->{'image'};
        delete $attr->{'image'};
        $attr->{'class'} = 'math';
        @ret = ('span', [ $attr,
            'img', [ { src=>"\"$img\"", alt=>"\"$text\"", } ], ]);
    } else {
        @ret = ($tag, [ $attr, '0', $text ]);
    }

    return @ret;
}

# Here we format things the docbook way.
sub transform_displaymath {
    my ($tag, $content) = @_;

    die if ref $content ne 'ARRAY';
    die if scalar @$content != 3;
    die if $content->[1] ne '0';

    my $attr = $content->[0];
    my $text = $content->[2];
    $text =~ s/^\s*//g;
    $text =~ s/\s*$//g;
    my $text0 = $text;
    $text = "\\displaystyle " . $text;
    my $md = md5_hex $text;
    texit($text, $md);

    my $img = "$mathdir/$md.png";

    my @ret;

    if ($htmlonly) {
        @ret = (
            'div', [ { class=>'displaymath', },
                'img', [ { src=>"\"$img\"", alt=>"\"$text\"", }, ]
                ]);
        print "<div class=\"displaymath\">\n";
        print "<img src=\"$mathdir/$md.png\" alt=\"$text0\"/>\n";
        print "</div>\n";
    } else {
        @ret = (
            'equation', [ {}, 'mediaobject',
                [ {},
                'imageobject',
                    [ {}, 'imagedata',
                        [ { fileref=>"\"$img\"", format=>"\"PNG\"", }, ]
                    ],
                'textobject',
                    [ {}, 'phrase', [ {}, '0', "\\[$text\\]" ], ],
                'textobject',
                    [ { role=>"\"tex\""}, 'phrase', [ {}, '0', "$text" ], ],
                ]]
            );
#        print <<EOF;
#<equation>
#<mediaobject>
#<imageobject>
#<imagedata fileref=\"$mathdir/$md.png\" format=\"PNG\"/>
#</imageobject>
#<textobject><phrase>\\\[$text\\\]</phrase></textobject>
#<textobject role=\"tex\"><phrase>$text</phrase></textobject>
#</mediaobject>
#</equation>
#EOF
    }
    return @ret;
}

sub print_doctype {
    my ($expat, $name, $sysid, $pubid, $internal) = @_;
    # this is of course improper for most uses.
    print <<EOF;
<!DOCTYPE $name
PUBLIC \"$pubid\" \"$sysid\">
EOF
#print <<EOF;
#<!DOCTYPE book
#PUBLIC \"-//Emmanuel Thome at normalesup dot org//DTD DocBook V4.4-based Extension TeXMath//EN\" \"mpfqdoc.dtd\"
#>
#EOF
}

XML::Reprocess::parse(*STDIN,
    Handlers => {
        Doctype => \&print_doctype,
    },
    Transformations => {
        math => \&transform_math,
        displaymath => \&transform_displaymath,
    },
    # ProtocolEncoding => 'UTF-8',
);
