# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Don't Create a new Calendar - unregistered. Just put up a message.

package CreateCalendar;
use strict;

use CGI (':standard');
use Calendar::GetHTML;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($cancel) = $self->getParams (qw (Cancel));

    my $i18n = $self->I18N;
    my $cgi  = new CGI;

    # if we've been cancel-ed, go back
    if ($cancel) {
        print $self->redir ($self->makeURL ({Op => 'SysAdminPage'}));
        return;
    }

    # Display the message
    print GetHTML->startHTML (title  => $i18n->get ('Create a New Calendar'),
                              op     => $self);
    print '<center>';
    print GetHTML->PageHeader    ('Calcium ' .
                                  $i18n->get ('System Administration'));
    print GetHTML->SectionHeader ($i18n->get ('Create a New Calendar'));
    print '</center>';
    print '<br>';

    print $cgi->h4 ('Sorry, you need to register for the Professional ' .
                    'version of Calcium if you want to create more '    .
                    'calendars.');
    print 'Please visit ' . $cgi->a ({href => 'http://www.brownbearsw.com'},
                                     'Brown Bear Software') . ' to do so.';

    print $cgi->startform;
    print $cgi->submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print $cgi->hidden (-name => 'Op',     -value => 'CreateCalendar');

    print $cgi->endform;
    print $cgi->end_html;
}

sub checkName {
    my $selfOrClass = shift;
    my ($name, $i18n) = @_;
    my ($message, $badName);    # retvals

    # Strip leading, trailing whitespace
    $name =~ s/^\s+//;
    $name =~ s/\s+$//;

    # Make sure the name has only simple chars. Fix this one day.
    if ($name =~ /\W/) {
        $badName++;
        $message = ('Error: only letters, digits, and the ' .
                    'underscore are allowed in Calendar '   .
                    'names.');
    } elsif ($name eq '') {
        $badName++;
        $message = ('Error: cannot have blank calendar name');
    }
    else {
        # Make sure name doesn't already exist
        my @existing = MasterDB->getAllCalendars;
        if (grep /^$name$/, @existing) {
            $message = 'Error: a Calendar with that name already ' .
                       'exists!';
        }
    }
    return ($i18n->get ($message), $badName);
}

1;
