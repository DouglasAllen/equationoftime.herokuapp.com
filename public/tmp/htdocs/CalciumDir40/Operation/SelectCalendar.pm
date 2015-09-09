# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Select Calendar - present a list of calendars

package SelectCalendar;
use strict;
use CGI;

use Calendar::Javascript;
use Calendar::GetHTML;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $cgi  = new CGI;
    my (@calendars, @groups);

    my $calName = $self->calendarName;     # undef for the MasterDB
    unless ($calName) {
        @calendars = MasterDB->getAllCalendars;
    } else {
        @groups = $self->prefs->getGroups;
        my ($matchList, $noGroup) = MasterDB->getCalendarsInGroup (@groups);
        @calendars = (@$matchList, @$noGroup);
    }

    my $i18n    = I18N->new ($self->getParams ('Language'));
    my $isPopup = $self->getParams ('IsPopup');

    # if we're a popup and cookie for display params not already set, set it
    my $cookie;
    if ($isPopup and !$cgi->cookie ('CalciumDisplayParams')) {
        $cookie = $self->displayParamCookie;
    }

    print GetHTML->startHTML (title  => $i18n->get ('Select Calendar'),
                              class  => 'SelectCalendar',
                              op     => $self,
                              cookie => $cookie);

    print Javascript->SetLocation;

    my $closeOnClick = 0;       # make this a user pref some day
    my $closeIt = $closeOnClick ? ", window.close()" : '';

    my @rows;
    foreach (sort {lc($a) cmp lc($b)} @calendars) {
        my $db = Database->new ($_);
        my $perm = Permissions->new ($db);
        next unless $perm->permitted ($self->getUsername, 'View');

        my $link = $self->makeURL ({CalendarName => $_,
                                    CookieParams => 1,
                                    IsPopup      => undef,
                                    Op           => 'ShowIt'});
        my $description = $db->description;

         if ($isPopup) {
            $link = "JavaScript:SetLocation (window.opener, '$link')" .
                    $closeIt;
        }

        push @rows,
        $cgi->Tr ({-class => $_},
                  $cgi->td ([$cgi->a ({-href => $link}, $_),
                             $description || '']));
    }

    print GetHTML->PageHeader ($i18n->get ('Available Calendars'));
    if (@groups) {
        print GetHTML->SectionHeader ($i18n->get (@groups > 1 ? 'Groups'
                                                              : 'Group') .
                                      ': ' . join ', ',
                                      sort {lc($a) cmp lc($b)} @groups);
    }

    my $body;
    $body .= '<center>';
    $body .= $cgi->table ({-border      => 0,
                           -cellpadding => 3},
                          $cgi->th ({-class => 'SectionHeader'},
                                    [$i18n->get ('Name'),
                                     $i18n->get ('Description')]),
                          @rows);
    $body .=  '<hr>';
    $body .= '</center>';
    if ($isPopup) {
        $body .= $cgi->startform (-onSubmit => 'return false');
        $body .= $cgi->submit (-name    => $i18n->get ('Close'),
                               -onClick => "window.close()");
        $body .= $cgi->endform;
    } else {
        my $url = $self->makeURL ({Op => 'ShowIt'});
        $body .= $cgi->a ({-href => $url}, 'Back to the calendar');
    }

    print $body;
    print $cgi->end_html;
}

1;
