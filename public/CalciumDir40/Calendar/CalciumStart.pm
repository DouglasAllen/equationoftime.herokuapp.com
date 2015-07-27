# Copyright 1999-2006, Fred Steinberg, Brown Bear Software
use strict;
package CalciumStart;

# Everything starts from here.

use strict;
use CGI::Carp;
use 5.004;
use CGI 2.42;
use Calendar::User;
use Calendar::Audit;
use Calendar::GetHTML;
use Operation::OperationFactory;

sub go {
    $|++;

    # Parse the CGI params into a hash
    my %params;
    my $cgi = new CGI;
    foreach my $name ($cgi->param) {
        $params{$name} = $cgi->param($name); # note! no multi-valued params!
    }

    # Check pathinfo for calendar name
    my $pathinfo = $cgi->path_info;
    if ($pathinfo and !defined $params{CalendarName}) {
        # fixed for borken servers; some give entire url
        $pathinfo =~ s{^.*/(.)}{$1}; # delete up to last slash with something
                                     #   after it
        $pathinfo =~ s{/$}{};        # and delete slash if at end of line,
                                     # so e.g. cgi-bin/calcium/Default/ works
        $params{CalendarName} = $pathinfo unless ($pathinfo =~ /\W/);
    }

    $params{Op} ||= ($params{'CalendarName'} ? 'ShowIt' : 'Splash');
    my $operation = $params{Op};

    # If we're testing a cookie, see if it worked
    if ($params{TestCookie}) {
        my $ok = $cgi->cookie ('-name' => $params{TestCookie});
        if (!defined ($ok)) {
            warn "Couldn't set cookie: $params{TestCookie}\n";
            my $i18n = I18N->new (Preferences->new (MasterDB->new)->Language);
            my $string = $i18n->get ('Calcium_CookieFailed');
            if ($string eq 'Calcium_CookieFailed') {
                $string =<< "                FNORD";
                    <center>Couldn't set the login cookie!</center><br>
                    You can't login to Calcium unless cookies work on your
                    browser. Please check your browser settings and make sure
                    cookies are enabled, then try again.<br><hr>
                FNORD
            }
            GetHTML->errorPage ($i18n,
                                header    => 'Cookie Failed',
                                message   => $string,
                                backCount => -2);
            die "\n";
        }
    }

    # Get the user, if they've already logged in (undef otherwise)
    my $user = User->new ($cgi);

    # Create the Operation (which sets the language, too)
    my $object;
    eval {$object = OperationFactory->create ($operation, \%params, $user)};
    unless ($object) {
        my $message = $@ || 'unknown error';
        _errorExit ($message);
    }

    # Check permission, and do it.
    if ($object->authenticate) {
        eval {$object->perform};
        _errorExit ($@) if ($@);
        $object->audit;
    } else {
        my $desired = $operation->mungeParams (%params);
        my $login  = $object->makeURL ({Op            => 'UserLogin',
                                        DesiredOp     => $operation,
                                        DesiredParams => $desired});
        my $splash  = $object->makeURL ({Op           => 'Splash',
                                         CalendarName => undef});
        my $username = $user && $user->name;
        my $message;
        my $i18n = I18N->new (Preferences->new (MasterDB->new)->Language);
        my $string = $i18n->get ('Calcium_NoPermission');
        require Operation::UserLogin;
        my $login_form = UserLogin->login_form ($object, $operation, $desired);
        if ($string eq 'Calcium_NoPermission') {
            $message = $username
                         ? "Sorry $username, you don't have permission to "
                         : "Sorry, you must log in before you can ";
            $message .=  "<b>$object->{AuthLevel}</b>" .
                         ($params{CalendarName}
                               ? " the <b>$params{CalendarName}</b> calendar."
                               : ' the Calendar System.');
            if ($params{PopupWin}) {
                GetHTML->errorPage ($i18n,
                                    header  => $i18n->get('Permission Denied'),
                                    message => $message,
                                    button  => $i18n->get ('Close'),
                                    onClick => 'window.close()',
                                    backCount => undef);
                return;
            }
            $message .= "<blockquote>$login_form</blockquote>"
                     .  "or go to the <a href=$splash> Calcium home page</a>, "
                     .  'or ';
        } else {
            $message = $i18n->get ('Calcium_NoPermission');
            $message .= "<blockquote>$login_form</blockquote>";
            $message .= "<br><a href=$splash>" .
                         $i18n->get ('Calcium home page') . '</a>';
        }
        GetHTML->errorPage ($i18n,
                            header  => $i18n->get ('Permission Denied'),
                            message => $message);
    }
}

sub _errorExit {
    my $message = shift;
    my $i18n = I18N->new (Preferences->new (MasterDB->new)->Language);
    if ($ENV{HTTP_HOST}         ||
        $ENV{GATEWAY_INTERFACE} ||
        $ENV{USER_AGENT}        ||
        $ENV{REQUEST_METHOD}) {
        GetHTML->errorPage ($i18n,
                            header  => "Sorry...something is not right",
                            message => $message);
    }
    die "Calcium error: $message\n";
}

1;
