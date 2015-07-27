# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# TextFilter - form to specify filter parameters

package TextFilter;
use strict;
use CGI;

use Calendar::Javascript;
use Calendar::MatchForm;
use Calendar::I18N;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($filter, $cancel, $text, $filterIn,
        $caseSensitive, $useRegex, $isPopupWindow) =
        $self->getParams (qw (DoIt Cancel MatchText LookHere
                              CaseSensitive UseRegex IsPopup));

    if ($cancel) {
        # clear previous settings
        $self->clearParams (qw /TextFilter FilterIn FilterCategories
                                IgnoreCase UseRegex/);
        print $self->redir ($self->makeURL ({Op => 'AdminPageUser'}));
        return;
    }

    my $cgi  = new CGI;
    my $i18n = $self->I18N;

    my @categories = $cgi->param ('FilterCategories');
    my ($message, $setOpener);

    if ($filter and (($text ne '') or @categories)) {

        # Check for bad regex
        $message = MatchForm->checkRegex ($text, $i18n) if ($useRegex);

        unless ($message) {
            my %hash = (Op      => 'ShowIt',
                        IsPopup => undef);
            if ($text) {
                $hash{TextFilter} = $text;
                $hash{FilterIn}   = $filterIn;
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

        $self->{audit_formsaved}++;
        $self->{audit_filtertext} = $text . ($message ? " - $message" : '');
    }

    print GetHTML->startHTML (title  => $i18n->get ('Event Text Filter'),
                              op     => $self);
    print $setOpener if $setOpener;

    # and display the search form
    print MatchForm->getHTML ($self, $message, $cgi, $isPopupWindow);
    print $cgi->end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line =  $self->SUPER::auditString ($short);
    $line .= ' ' . join ' ', $self->{audit_filtertext};
}

1;
