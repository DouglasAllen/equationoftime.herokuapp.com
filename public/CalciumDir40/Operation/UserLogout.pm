# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Clear cookie from the browser.

package UserLogout;
use strict;

use CGI (':standard');

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;
    my $cgi = new CGI;

    # Clear the cookie, go to login screen.
    my $cookie = User->clearCookie ($cgi);
    my $url = $self->makeURL ({Op           => 'Splash',
                               CalendarName => undef});
    print GetHTML->startHTML (title  => $i18n->get ('Logout'),
                              op     => $self,
                              cookie => $cookie,
                              Refresh => "1; URL=$url");
    print '<center>';
    print $cgi->h1 ($i18n->get ("Thank you for logging out."));
    print $cgi->p ($i18n->get ('Click') . ' ' .
                   $cgi->a ({href => $url}, $i18n->get ('here')) . ' '.
                   $i18n->get ('to continue, or just ' .
                               'wait a second...'));
    print '</center>';
    print $cgi->end_html;
}

# override the default, since this op has security 'None' (see AdminAudit.pm)
sub auditType {
    return 'UserLogin';
}

# Heck, just use the default
#sub auditString {
#}

1;
