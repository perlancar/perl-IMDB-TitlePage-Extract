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
    my $ld;

    # 0 linked-data
  LINKED_DATA:
    {
        last unless
            $ct =~ m!\Q<script type="application/ld+json">\E(.+?)</script>!s;
        require JSON::MaybeXS;
        eval { $ld = JSON::MaybeXS::decode_json($1) };
        if ($@) {
            log_error("Cannot parse linked data as JSON: $@");
            last;
        }
        $resmeta->{'func.ld'} = $ld;
    }

    # countries
    {
        my $countries = {};
        while ($ct =~ m!<a href="/search/title\?country_of_origin=(\w+)!g) {
            $countries->{$1}++;
        }
        $res->{countries} = [sort keys %$countries];
    }

    # duration
    if ($ld && defined $ld->{duration}) {
        $res->{duration} = $ld->{duration};
    } elsif ($ct =~ m!<time itemprop="duration" datetime="(PT.+?)"!) {
        $res->{duration} = $1
    }

    # genres
    if ($ld && $ld->{genre}) {
        $res->{genres} = [ map {lc} @{ $ld->{genre} } ];
    } else {
        my $genres = {};
        while ($ct =~ m!<a href="/genre/([^/?]+)!g) {
            $genres->{lc($1)}++;
        }
        $res->{genres} = [sort keys %$genres];
    }

    # keywords
    if ($ld && $ld->{keywords}) {
        $res->{keywords} = [split /\s*,\s*/, $ld->{keywords}];
    }

    # languages
    {
        my $langs = {};
        while ($ct =~ m!<a href="/search/title\?title_type=feature&primary_language=(\w+)!g) {
            $langs->{$1}++;
        }
        $res->{languages} = [sort keys %$langs];
    }

    # rating
    if ($ct =~ m!<span itemprop="ratingValue">(.+?)</span>!) {
        $res->{rating} = $1;
    }

    # summary
    if ($ld && $ld->{description}) {
        $res->{summary} = $ld->{description};
    } elsif ($ct =~ m!<div class="summary_text"[^>]*>\s*(.+?)\s*</div>!s) {
        $res->{summary} = _strip_summary($1)
    }

    # year
    if ($ct =~ m!<span id="titleYear">\(<a href="/year/(\d{4})/!) {
        $res->{year} = $1;
    } elsif ($ct =~ m!<title>[^<]+ (\d+)(?:/\w+)?\)!) {
        $res->{year} = $1;
    }

    # title
    if ($ld && defined $ld->{name}) {
        $res->{title} = $ld->{name};
    } elsif ($ct =~ m!<div class="title_wrapper">\s*<h1 class="">(.+)?&nbsp;<!s) {
        $res->{title} = $1;
    }

    [200, "OK", $res, $resmeta];
}

1;
# ABSTRACT:

=head1 SEE ALSO

L<IMDB::NamePage::Extract>
