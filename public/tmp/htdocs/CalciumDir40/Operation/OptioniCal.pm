# Copyright 2003-2006, Fred Steinberg, Brown Bear Software

package OptioniCal;
use strict;

# Set up iCalendar subscription, suitable for e.g. Apple's iCal, or Mozilla
# Calendar.
#
use Calendar::EventvEvent;
use Calendar::GetHTML;
use Calendar::vCalendar::vCalendar;
use Operation::Operation;
use Time::Local;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($save, $cancel) = $self->getParams (qw (Save Cancel));

    my $cgi     = CGI->new;
    my $i18n    = $self->I18N;
    my $calName = $self->calendarName;

    if ($cancel or !$calName) {
        print $self->redir ($self->makeURL ({Op => 'AdminPageUser'}));
        return;
    }

    print GetHTML->startHTML (title  => $i18n->get ('iCalendar Subscription'),
                              class  => 'OptioniCal',
                              op     => $self);
    print GetHTML->PageHeader ($i18n->get ('iCalendar Subscription'));
    print GetHTML->SectionHeader ($calName);
    print '<br>';

    if ($save) {
        my ($incCal, $incAddins, $uname, $password) =
                            $self->getParams (qw (IncCals IncAddins Uname PW));
        my %args = (FullURL   => 1,
                    PlainURL  => 1,
                    Op        => 'iCalSubscribe');
        $args{User}     = $uname    if ($uname);
        $args{Password} = $password if ($password);
        $args{Includes} = 1         if ($incCal);
        $args{AddIns}   = 1         if ($incAddins);

        my $url = $self->makeURL (\%args);
        $url .= '&x=1';    # Apple might tack on an .ics or some such
        my $webcal_url = $url;
        $webcal_url =~ s/^http/webcal/;

#        print $self->redir ($url);

        print <<END_MESSAGE;
<p>Click one of these links if your web browser and desktop calendar are
configured to recognize "webcal" links or the "text/calendar" content
type:</p>
<ul>
    <li><a href="$webcal_url"><b>webcal</b> subscription</a>
        &nbsp;&nbsp;&nbsp;(e.g. for Apple OS X "iCal")</li>
    <li><a href="$url"><b>HTTP</b> subscription</a></li>
</ul>

<p>Otherwise, you'll need to configure the subscription in the
settings of your desktop calendar program. Use this URL as the
subscription address:<br/><center><small>$url</small></center></p>
END_MESSAGE

        print '<hr>';
        print $cgi->startform;
        print $cgi->submit (-name => 'Cancel', -value => $i18n->get ('Done'));
        print $cgi->hidden (-name => 'Op',     -value => __PACKAGE__);
        print $cgi->hidden (-name => 'CalendarName', -value => $calName)
          if $calName;
        print $self->hiddenDisplaySpecs;
        print $cgi->endform;

        print $cgi->end_html;
        return;
    }

    my $mess = $i18n->get ('OptioniCal_Inst');
    if ($mess eq 'OptioniCal_Inst') {
        $mess = 'If you have a desktop application that supports '      .
                "iCalendar Subscriptions - like Apple's iCal or the "   .
                'Mozilla calendar - you can use this page to set up a ' .
                'subscription.';
    }
    print $mess;
    print '<br><br>';

    print $cgi->startform;

    my @rows;
    push @rows, $cgi->Tr ($cgi->td ({-class => 'MenuLabel'},
                                    $i18n->get ('Use Events from') . ':'),
                          $cgi->td ($cgi->checkbox (-name    => 'IncCals',
                                                    -checked => 1,
                                                    -label   =>
                                          $i18n->get ('Included Calendars')) .
                                    '&nbsp;' .
                                    $cgi->checkbox (-name    => 'IncAddins',
                                                    -checked => 1,
                                                    -label   =>
                                                     $i18n->get ('Add-Ins'))));
    push @rows, $cgi->Tr ($cgi->td ({-colspan => 2}, '<br>' .
                                    $i18n->get ('If this calendar requires ' .
                                                'logging in to View, enter ' .
                                                'the login to use.')));
    push @rows, $cgi->Tr ($cgi->td ({-class => 'MenuLabel'},
                                    $i18n->get ('Username') . ':'),
                          $cgi->td ($cgi->textfield (-name      => 'Uname',
                                                     -maxlength => 40,
                                                     -size      => 20)));
    push @rows, $cgi->Tr ($cgi->td ({-class => 'MenuLabel'},
                                    $i18n->get ('Password') . ':'),
                          $cgi->td ($cgi->password_field (-name      => 'PW',
                                                          -override  => 1,
                                                          -maxlength => 40,
                                                          -size      => 20)));
    print $cgi->table (@rows);

    print '<hr>';
    my $doIt = $i18n->get ('"Subscribe" to this calendar');
    print $cgi->submit (-name  => 'Save',  -value => $doIt);
    print '&nbsp;';
    print $cgi->submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print $cgi->hidden (-name => 'Op',     -value => __PACKAGE__);
    print $cgi->hidden (-name => 'CalendarName', -value => $calName)
        if $calName;
    print $self->hiddenDisplaySpecs;
    print $cgi->endform;

    print '<br><div class="AdminNotes">';
    print $cgi->span ({-class => 'AdminNotesHeader'},
                      $i18n->get ('Notes') . ':');
    print '<ul><li>';
    print $i18n->get ('The username/password will appear in plain text in ' .
                      'the subscription URL.');
    print '</li>';
    print '<li>';
    print $i18n->get ('If you change your Calcium password, remember that ' .
                      'you\'ll need to resubscribe here with the new ' .
                      'password, or change the URL in your desktop ' .
                      'application.');
    print '</li>';
    print '</ul></div>';

    print $cgi->end_html;
}

1;
