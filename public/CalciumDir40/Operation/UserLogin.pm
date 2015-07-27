# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Put up the login screen, redirect on success.
# On success, redirect to:

#     -specified operation, if any
#     -else, to default calendar, if defined
#     -else, to calendar w/same name as the user, if exists
#     -else, to Splash screen

package UserLogin;
use strict;

use CGI (':standard');
use Calendar::GetHTML;
use Calendar::User;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($submit, $username, $password, $desiredOp, $desiredParams) =
            $self->getParams (qw (Submit Username Password
                                  DesiredOp DesiredParams));
    my $cgi = new CGI;
    my $message;

    my $instance_name = Preferences->new (MasterDB->new)->InstName || 'Calcium';

    $desiredOp ||= 'ShowIt';
    $desiredOp = 'Splash' if ($desiredOp eq 'UserLogin');

    # if we've been passed the info, check it out
    if ($username) {
        my $ok = User->checkPassword ($username, $password);
        if ($ok) {
            $message = "ok!";
        } elsif (defined $ok) {
            $message = "<b>" . $i18n->get ("Sorry, that's not the correct " .
                                           "password for") .
                       " '$username'.</b>";
        } else {
            $message = "<b>" . $i18n->get ("Sorry, but I don't believe the " .
                                           "user exists:") .
                       " '$username'</b>";
        }

        $self->{audit_formsaved}++;
        $self->{audit_username} = $username;
        $self->{audit_success}  = $ok;

        if ($ok) {
            # Get user from db
            my $user = User->getUser ($username);

            # Write the cookie out
            my ($cookie, $cookieName) = User->makeNewCookie ($cgi, $username);

            my %params = $self->unmungeParams ($desiredParams);
            if ($desiredOp eq 'Splash') {
                $params{CalendarName} = undef;
            } else {
                $params{CalendarName} ||= $user->defaultCalendar
                    if $user;
                $params{CalendarName} ||= $username;
                my $db;
                eval {$db = Database->new ($params{CalendarName})};
                if ($@ or !$db or !$$db->{Imp}->dbExists) {
                    $params{CalendarName} = undef;
                    $desiredOp = 'Splash';
                }
            }
            my $url = $self->makeURL ({Op         => $desiredOp,
                                       TestCookie => $cookieName,
                                       %params});
            print GetHTML->startHTML (cookie  => $cookie,
                                      op      => $self,
                                      Refresh => "1; URL=$url",
                                      title   => $i18n->get ('Welcome!'));
            print '<center>';
            print $cgi->h1 ($i18n->get ('Welcome to'),
                            "$instance_name, $username!");
            print $cgi->p ($i18n->get ('Click') . ' ' .
                           $cgi->a ({href => $url}, $i18n->get ('here')) . ' '.
                           $i18n->get ('to continue, or just wait ' .
                                       'a second...'));
            print '</center>';
            print $cgi->end_html;
            return;
        }
    }

    # Display the login form
    print GetHTML->startHTML (title  => $i18n->get ('Login'),
                              op     => $self,
                              onLoad => "document.forms[0].Username.focus()");
    print GetHTML->PageHeader ("$instance_name " . $i18n->get ('Login'));
    print GetHTML->SectionHeader ('&nbsp;');

    print $message if $message;
    print "<p>";
    print $i18n->get ('Please enter your username and password:');
    print "</p>";
    print $self->login_form ($self, $desiredOp, $desiredParams);
    print $cgi->end_html;
}

sub login_form {
    my ($class, $op, $desiredOp, $desiredParams) = @_;
    my $i18n = $op->I18N;

    my $html = startform;

    $html .= table (Tr (td (b ($i18n->get ('Name') . ': ')),
                        td (textfield (-name      => 'Username',
                                       -tabindex  => 0,
                                       -maxlength => 40,
                                       -size      => 20)),
                        td ({-rowspan => 2}, '&nbsp;' .
                            submit (-name     => 'Submit',
                                    -value    => $i18n->get ('Login')))),
                    Tr (td (b ($i18n->get ('Password') . ': ')),
                        td (password_field (-name      => 'Password',
                                            -tabindex  => 0,
                                            -override  => 1,
                                            -maxlength => 40,
                                            -onChange =>
                                            "JavaScript:this.form.submit()",
                                            -size      => 20))));

    $html .= $op->hiddenDisplaySpecs;
    $html .= hidden (-name => 'Op', -value => 'UserLogin', -override => 1);
    $html .= hidden (-name => 'CalendarName',  -value => $op->calendarName||'');
    $html .= hidden (-name => 'DesiredOp',     -value => $desiredOp);
    $html .= hidden (-name => 'DesiredParams', -value => $desiredParams)
                                                           if $desiredParams;
    $html .= endform;
    return $html;
}

# override the default, since this op has security 'None' (see AdminAudit.pm)
sub auditType {
    return 'UserLogin';
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    return unless $self->{audit_username};
    return $line . " $self->{audit_username} - " .
            ($self->{audit_success} ? "Succeeded" : "FAILED");
}

1;
