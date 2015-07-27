# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# SearchForm - form to specify search parameters

package SearchForm;
use strict;
use CGI;

use Calendar::Date;
use Calendar::Javascript;
use Calendar::MatchForm;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($search, $cancel, $text, $searchIn, $caseSensitive, $useRegex,
        $fromMonth, $fromYear, $toMonth, $toYear, $isPopupWindow) =
        $self->getParams (qw (DoIt Cancel MatchText LookHere
                              CaseSensitive  UseRegex
                              FromMonthPopup FromYearPopup
                              ToMonthPopup   ToYearPopup IsPopup));

    if ($cancel) {
        print $self->redir ($self->makeURL ({Op => 'AdminPageUser'}));
        return;
    }

    my $cgi  = new CGI;
    my $i18n = $self->I18N;

    my @categories = $cgi->param ('FilterCategories');
    my ($message, $setOpener);

    # do the search, if we're searching
    if ($search and (($text ne '') or @categories)) {

        $self->{audit_searchstring} = $text;

        # Check for bad regex
        $message = MatchForm->checkRegex ($text, $i18n) if ($useRegex);

        unless ($message) {
            my $fromDate = Date->new ($fromYear, $fromMonth, 1);
            my $toDate   = Date->new ($toYear,   $toMonth, 1);
            $toDate->day ($toDate->daysInMonth);

            my %hash = (Op       => 'SearchPerform',
                        IsPopup  => undef,
                        FromDate => "$fromDate",
                        ToDate   => "$toDate");
            if ($text) {
                $hash{TextFilter} = $text;
                $hash{FilterIn}   = $searchIn;
                $hash{IgnoreCase} = !$caseSensitive;
                $hash{UseRegex}   = $useRegex;
            }
            if (@categories) {
                $hash{FilterCategories} = join $;, @categories;
            }

            my $link = $self->makeURL (\%hash);
            if (!$isPopupWindow) {
                print $self->redir ($link);
                return;
            } else {
                $setOpener = Javascript->SetLocation;
                $setOpener .= "\n<script language=\"JavaScript\"><!-- \n";
                $setOpener .= "SetLocation (self.opener, '$link')";
                $setOpener .= "\n// --></script>\n";
            }
        }
    }

    print GetHTML->startHTML (title  => $i18n->get ('Search for Events'),
                              op     => $self);

    # redisplay calendar, if we're a popup
    print $setOpener if $setOpener;

    # and display the search form
    print MatchForm->getHTML ($self, $message, $cgi, $isPopupWindow);
    print $cgi->end_html;
}

sub auditString {
    return undef;               # auditing done in SearchPerform
}

1;
