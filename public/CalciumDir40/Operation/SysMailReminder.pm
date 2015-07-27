# Copyright 2000-2006, Fred Steinberg, Brown Bear Software

# Don't display mail stuff - unregistered. Just put up a message.

package SysMailReminder;
use strict;

use CGI (':standard');

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($cancel) = $self->getParams (qw (Cancel));

    my $i18n  = $self->I18N;
    my $cgi   = new CGI;

    if ($cancel) {
        print $self->redir ($self->makeURL ({Op => 'SysAdminPage'}));
        return;
    }

    print GetHTML->startHTML (title  => $i18n->get ('Email Reminders'),
                              op     => $self);
    print '<center>';
    print GetHTML->PageHeader    ('Calcium ' .
                                  $i18n->get ('System Administration'));
    print GetHTML->SectionHeader ($i18n->get ('Email Reminder Process'));
    print '</center>';
    print '<br>';

    print $cgi->h4 ('Sorry, you need to purchase the Calcium Email ' .
                    'package to use the email reminder features.');
    print 'Please visit ' . $cgi->a ({href => 'http://www.brownbearsw.com'},
                                     'Brown Bear Software') . ' to do so.';

    print '<hr>';
    print $cgi->startform;
    print submit (-name  => 'Cancel', -value => $i18n->get ('Done'));
    print hidden (-name => 'Op',      -value => 'SysMailReminder');
    print $cgi->endform;
    print $cgi->end_html;
}

1;
