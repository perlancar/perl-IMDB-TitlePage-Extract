package IMDB::TitlePage::Extract;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use HTML::Entities qw(decode_entities);

our %SPEC;

sub _strip_summary {
    my $html = shift;
    $html =~ s!<a[^>]+>.+?</a>!!sg;
    #$html = replace($html, {
    #    '&nbsp;' => ' ',
    #    '&raquo;' => '"',
    #    '&quot;' => '"',
    #});
    decode_entities($html);
    $html =~ s/\n+/ /g;
    $html =~ s/\s{2,}/ /g;
    $html;
}

$SPEC{parse_imdb_title_page} = {
    v => 1.1,
    summary => 'Extract information from an IMDB title page',
    args => {
        page_content => {
            schema => 'str*',
            req => 1,
            cmdline_src => 'stdin_or_file',
        },
    },
};
sub parse_imdb_title_page {
    my %args = @_;

    my $ct = $args{page_content} or return [400, "Please supply page_content"];

    my $res = {};
    my $resmeta = {};

  LINKED_DATA:
    {
        last unless
            $ct =~ m!\Q<script type="application/ld+json">\E(.+?)</script>!s;
        require JSON::MaybeXS;
        my $ld;
        eval { $ld = JSON::MaybeXS::decode_json($1) };
        if ($@) {
            log_error("Cannot parse linked data as JSON: $@");
            last;
        }
        $resmeta->{'func.ld'} = $ld;
        $res->{duration} //= $ld->{duration};
    }

    $res->{rating} //= $1
        if $ct =~ m!<span itemprop="ratingValue">(.+?)</span>!;

    if ($ct =~ m!<span id="titleYear">\(<a href="/year/(\d{4})/!) {
        $res->{year} //= $1;
    } elsif ($ct =~ m!<title>[^<]+ (\d+)(?:/\w+)?\)!) {
        $res->{year} //= $1;
    }

    my $genres = {};
    while ($ct =~ m!<a href="/genre/([^/?]+)!g) {
        $genres->{lc($1)}++;
    }
    $res->{genres} //= [sort keys %$genres];

    $res->{summary} //= _strip_summary($1)
        if $ct =~ m!<div class="summary_text"[^>]*>\s*(.+?)\s*</div>!s;

    $res->{duration} //= $1
        if $ct =~ m!<time itemprop="duration" datetime="(PT.+?)"!;

    [200, "OK", $res, $resmeta];
}

1;
# ABSTRACT:

=head1 SEE ALSO

L<IMDB::NamePage::Extract>
