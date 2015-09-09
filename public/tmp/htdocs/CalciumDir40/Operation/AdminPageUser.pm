# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

package AdminPageUser;
use strict;

use CGI (':standard');

use Calendar::GetHTML;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $cgi = new CGI;
    my $i18n = $self->I18N;

    my $isPopup = $self->getParams ('IsPopup');

    my $calName = $self->calendarName;

    # if we're a popup and cookie for display params not already set, set it
    my $cookie;
    if ($isPopup and !$cgi->cookie ('CalciumDisplayParams')) {
        $cookie = $self->displayParamCookie;
    }

    print GetHTML->startHTML (title  => $i18n->get ('Calendar Options') .
                                        ": $calName",
                              cookie => $cookie,
                              class  => 'CalendarOptions',
                              op     => $self);
    print '<div class="PopupMenuWindow">'
        if ($isPopup);

    print GetHTML->PageHeader ($i18n->get ('Options for Calendar: ') .
                               '<font color="blue">' . "$calName</font>");
    print '<br>';

    my %links =  (print      => $self->makeURL ({Op => 'PrintView'}),
                  freetime   => $self->makeURL ({Op => 'FreeTimeSearch'}),
                  subscribe  => $self->makeURL ({Op => 'OptionSubscribe'}),
                  icalsub    => $self->makeURL ({Op => 'OptioniCal'}),
                  search     => $self->makeURL ({Op => 'SearchForm'}),
                  textFilter => $self->makeURL ({Op => 'TextFilter'}),
                  eventFilter => $self->makeURL ({Op => 'EventFilter'}),
                  export     => $self->makeURL ({Op  => 'AdminExport',
                                                 FromUserPage => 1}),
                  import     => $self->makeURL ({Op  => 'AdminImport',
                                                 FromUserPage => 1}),
                  timezone   => $self->makeURL ({Op => 'UserOptions'}),
                  'delete'   => $self->makeURL ({Op => 'AdminDeleteEvents'}),
                  statistics => $self->makeURL ({Op => 'AdminStatistics'}));

    my %linkText = (print       => $i18n->get ('Printable View'),
                    freetime    => $i18n->get ('Open Time Search'),
                    subscribe   => $i18n->get ('Email Subscriptions'),
                    icalsub     => $i18n->get ('iCalendar Subscription'),
                    search      => $i18n->get ('Search for Events'),
                    textFilter  => $i18n->get ('Event Filter'),
                    eventFilter => $i18n->get ('Source Filter'),
                    export      => $i18n->get ('Export Events'),
                    import      => $i18n->get ('Import Events'),
                    timezone    => $i18n->get ('Time Offset'),
                    'delete'    => $i18n->get ('Delete Events'),
                    statistics  => $i18n->get ('Calendar Statistics'));

    my %description = (print      => $i18n->get ('Display a printable view ' .
                                                 'of the calendar'),
                       freetime   => $i18n->get ('Search for open time slots ' .
                                                 'in multiple calendars'),
                       subscribe  => $i18n->get ('Sign up to receive email ' .
                                                 'for future events'),
                       icalsub    => $i18n->get ('Subscribe via desktop ' .
                                                "calendar, e.g. Apple's iCal"),
                       search     => $i18n->get ('Find events by text or ' .
                                                 'category'),
                       textFilter => $i18n->get ('Only display events that ' .
                                                 'match text or are in ' .
                                                 'certain categories'),
                       eventFilter => $i18n->get ('Only display events from ' .
                                                  'particular included ' .
                                                  'calendars or Add-Ins'),
                       export     => $i18n->get ('Export event data to ASCII'),
                       import     => $i18n->get ('Create new ' .
                                                 'events from an ASCII file'),
                       timezone   => $i18n->get ('Set your timezone, ' .
                                                 'relative to the server ' .
                                                 'time'),
                       'delete'   => $i18n->get ('Remove all events in a ' .
                                                 'specified date range'),
                       statistics => $i18n->get ('Display various statistics' .
                                                 ' about the calendar'));

    # We use this list to ensure the order of links comes out right
    my @tableCrap = qw (print subscribe freetime search textFilter eventFilter);
#                        delete statistics);
    if ($self->permission->permitted ($self->getUsername, 'Add')) {
        push @tableCrap, 'import';
    }
    push @tableCrap, ('export', 'icalsub');

    # Allow anon users to set timezone
    if (!$self->getUsername) {
        push @tableCrap, 'timezone';
    }

    if (!Defines->mailEnabled) {
        splice @tableCrap,1,1;  # remove 'subscribe'
#         $description{subscribe} .= '&nbsp;&nbsp;<i>[' .
#             $i18n->get ('Disabled in this version') . ']</i>';
#         delete $links{subscribe};
    }
    elsif (!$self->prefs->RemindersOn) {
        $description{subscribe} .= '&nbsp;&nbsp;<i>' .
            $i18n->get ('[Turned off for this calendar]') . '</i>';
        delete $links{subscribe};
    }

    print table ({-width => '100%',
                  -cellspacing => 1},
                 map {
                     Tr (td ({-bgcolor => "#dddddd"},
                             ($links{$_} ? a ({-href => $links{$_}},
                                              $linkText{$_})
                                         : $linkText{$_}),
                             td ($description{$_})))
                 } @tableCrap);

    my $closeIt;
    if ($isPopup) {
        $closeIt = '<center>' . a ({-href => "Javascript:window.close()"},
                                   $i18n->get ('Close')) . '</center>';
        $closeIt .= '</div>';   # for <div class="PopupMenuWindow">
    } else {
        $closeIt = table ({-width => "60%",
                           -align => 'center'},
                          Tr (td (a ({-href =>
                                      $self->makeURL ({Op => 'ShowIt'})},
                                     $i18n->get ('Return to the Calendar'))),
                              td (a ({href => $self->makeURL
                                      ({CalendarName => undef,
                                        PlainURL     => 1})},
                                     $i18n->get ('Home')))));
    }

    print '<br><br>';
    print $closeIt;
    print $cgi->end_html;
}

sub auditString {
    return undef;       # we don't care about this
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
