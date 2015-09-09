# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Change password, etc.

package UserOptions;
use strict;

use CGI (':standard');
use Calendar::GetHTML;
use Calendar::User;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($oldPass1, $newPass, $newPassAgain, $oldPass2, $email, $tzone,
        $defaultCal, $passButton, $emailButton, $tzoneButton,
        $defaultCalButton, $deleteConfirmButton, $delete_confirm,
        $nextOp, $isPopup) =
            $self->getParams (qw (OldPass1 NewPass NewPassAgain OldPass2
                                  Email Timezone DefaultCal PasswordButton
                                  EmailButton TZoneButton DefaultCalButton
                                  DeleteConfirmButton DeleteConfirm
                                  NextOp IsPopup));

    my $cgi = new CGI;
    my $user = User->getUser ($self->getUsername); # get from DB, ugh.

    $nextOp ||= 'Splash';

    my ($message, $cookie);

    my $isLocked = ($user && $user->isLocked);
    if ($isLocked) {
        $message = $i18n->get ('Note: this user is locked; ' .
                               'no changes allowed.');
        $message = "<b>$message</b>";
    }
    # if we've been passed the info, check it out
    elsif ($user and ($passButton or $emailButton)) {
        $self->{audit_formsaved}++;

        my $oldPass = $oldPass1 || $oldPass2;

        my $ok = $user->checkPassword ($oldPass);
        if (!$ok) {
            $message = "Sorry, that's not your correct password.";
            $message = 'You must enter your current password' if (!$oldPass);
            $message = $cgi->b ($cgi->font ({-color => 'red'},
                                            $i18n->get ($message)) .
                                '<br>' . $i18n->get ('Please try again.'));
            $self->{audit_error} = 'bad password';
        } elsif ($passButton and ($newPass ne $newPassAgain)) {
            $message = "<b><font color=red>" .
                       $i18n->get ("Sorry, the two versions of your new " .
                                   "password aren't the same.") .
                       "</font><br>" .
                       $i18n->get ('Please try again.') . "</b>";
            $self->{audit_action} = 'change password';
            $self->{audit_error} = 'bad passwords';
        } elsif ($passButton) {
            # Store the new password
            $user->setPassword ($newPass);
            $message = '<b>' . $i18n->get ('Congratulations') . ' ' .
                       $user->name . ', ' .
                       $i18n->get ('you have successfully changed your ' .
                                   'password.') . '</b>';
            $self->{audit_action} = 'change password';
        } elsif ($emailButton) {
            # Store the new address
            $user->setEmail ($email);
            $message = '<b>' . $i18n->get ('Congratulations') . ' ' .
                       $user->name . ', ' .
                       $i18n->get ('you have successfully changed your ' .
                                   'email address.') . '</b>';
            $self->{audit_action} = 'change email';
            $self->{audit_data}   = $email;
        }
    } elsif ($tzoneButton) {
        $self->{audit_formsaved}++;
        if ($user) {
            $user->setTimezone ($tzone);
            $message = '<b>' . $i18n->get ('Timezone changed for ') .
                               $user->name . '</b>';
        } else {
            # set cookie for anon user
            $cookie = $cgi->cookie (-name  => 'CalciumAnonOffset',
                                    -value => $tzone);
            $message = '<b>' . $i18n->get ('Timezone changed') . '</b>';
        }
        $self->{audit_action} = 'change timezone';
        $self->{audit_data}   = $tzone;
    } elsif ($user and $defaultCalButton) {
        $self->{audit_formsaved}++;
        undef $defaultCal if ($defaultCal eq ' - ');
        $user->setDefaultCalendar ($defaultCal);
        $message = '<b>' . $i18n->get ('Default calendar changed for ') .
                           $user->name . '</b>';
    } elsif ($user and $deleteConfirmButton) {
        $self->{audit_formsaved}++;
        undef $delete_confirm if ($delete_confirm eq 'none');
        $user->setConfirmDelete ($delete_confirm);
        $message = '<b>' . $i18n->get ('Delete Confirmation changed for ') .
                           $user->name . '</b>';
    }

    # Display the User Options form
    print GetHTML->startHTML (title  => $i18n->get ('User Options'),
                              cookie => $cookie,
                              op     => $self);

    my $ustring = '';
    if ($user) {
        $ustring = $i18n->get ('Username') . ': ' . $user->name
    }
    print GetHTML->PageHeader    ($i18n->get ('User Options'));
    print GetHTML->SectionHeader ($ustring);

    print "<br><center>$message</center>" if $message;

    if ($isLocked) {
        my $zone = $user->timezone || 0;
        $zone .= ' ' . $i18n->get ('hours');
        print '<p>';
        print table ({-align => 'center',
                      -cellpadding => 5,
                      -cellspacing => 5},
                     Tr (td (b ($i18n->get ('Email Address:'))),
                         td ($user->email || '')),
                     Tr (td (b ($i18n->get ('Timezone offset:'))),
                         td ($zone)),
                     Tr (td (b ($i18n->get ('Default Calendar:'))),
                         td ($user->defaultCalendar || ' - ')));
        print '</p>';
        print $cgi->end_html;
        return;
    }

    my $script = <<'    END_JAVASCRIPT';
    :    <script language="text/javascript">
    :    <!-- start
    :    // If PW blank, make sure they mean it
    :    function submitCheck (theForm) {
    :        if (!theForm.PasswordButton.pressed) {
    :            return true;
    :        }
    :        if (theForm.NewPass.value.length == 0) {
    :            return confirm ("Really set password to blank?");
    :        }
    :    }
    :    // End -->
    :    </script>
    END_JAVASCRIPT
    $script =~ s/^\s*:\s*//mg;
    print $script;
    print '<br/>';

    my $onSubmit = $user ? 'return submitCheck(this)' : '';
    print startform (-onSubmit => $onSubmit);

    # Anonymous users can only set time zone

    my @sections;

    if ($user) {
        my $pwlabel = $i18n->get ('Current Password: ');

        push @sections,
          table ({class => 'optsection'},
                 Tr (th {-colspan => 2},
                     $i18n->get ('Change your password:')),
                 Tr (td ($pwlabel),
                     td (password_field (-name      => 'OldPass1',
                                         -override  => 1,
                                         -maxlength => 40,
                                         -size      => 20))),
                 Tr (td ('&nbsp')),
                 Tr (td ($i18n->get ('New Password: ')),
                     td (password_field (-name      => 'NewPass',
                                         -override  => 1,
                                         -maxlength => 40,
                                         -size      => 20))),
                 Tr (td ($i18n->get ('Verify New Password: ')),
                     td (password_field (-name      => 'NewPassAgain',
                                         -override  => 1,
                                         -maxlength => 40,
                                         -size      => 20))),
                 Tr (td ({-colspan => 2, -align => 'center'},
                         submit (-name    => 'PasswordButton',
                                 -value   => $i18n->get ('Change Password'),
                                 -onClick => 'this.pressed = true'))));

        push @sections,
          table ({class => 'optsection'},
                 Tr (th {-colspan => 2},
                     $i18n->get ('Change your email address:')),
                 Tr (td ($pwlabel),
                     td (password_field (-name      => 'OldPass2',
                                         -override  => 1,
                                         -maxlength => 40,
                                         -size      => 20))),
                 Tr (td ($i18n->get ('Email Address:')),
                     td (textfield (-name      => 'Email',
                                    -default   => $user->email || '',
                                    -maxlength => 50,
                                    -size      => 30))),
                 Tr (td ({-colspan => 2, -align => 'center'},
                         submit (-name  => 'EmailButton',
                                 -value => $i18n->get ('Change Email Address')))
                    ));
    }

    my $default;
    if ($user) {
        $default = $user->timezone;
    } else {
        $default = $self->prefs->Timezone;
    }
    my $serverTime = time;
    my %labels = map {$_ => "$_ hours - " .
                          scalar localtime ($serverTime + $_ * 3600)}
                     (-23..23);
    push @sections,
      table ({class => 'optsection'},
             Tr (th ({-colspan => 2},
                     $i18n->get ('Change your time zone:'))),
             Tr (td ($i18n->get ('Current server time:')),
                 td (scalar localtime $serverTime)),
             Tr (td ($i18n->get ('Your offset from server') . ':'),
                 td (popup_menu (-name      => 'Timezone',
                                 -default   => $default || 0,
                                 -labels    => \%labels,
                                 -values    => [-23..23]))),
             Tr (td {-colspan => 2, -align => 'center'},
                 submit (-name  => 'TZoneButton',
                         -value => $i18n->get ('Change Time Zone'))));

    # Default Calendar
    if ($user) {
        # Get all calendars we can View
        my @calendars = MasterDB->getAllCalendars;
        my $name = $self->getUsername;
        my @calnames;
        foreach (@calendars) {
            my $perms = Permissions->new ($_);
            next unless $perms->permitted ($name, 'View');
            push @calnames, $_;
        }
        @calnames = sort {lc($a) cmp lc($b)} @calnames;
        unshift @calnames, ' - ';
        push @sections,
          table ({class => 'optsection'},
                 Tr (th ({-colspan => 2},
                         $i18n->get ('Change your Default Calendar:'))),
                 Tr (td ($i18n->get ('Default Calendar') . ':'),
                     td (popup_menu (-name      => 'DefaultCal',
                                     -default   => $user->defaultCalendar,
                                     -values    => \@calnames))),
                 Tr (td {-colspan => 2, -align => 'center'},
                     submit (-name  => 'DefaultCalButton',
                             -value => $i18n->get('Change Default Calendar'))));
    }

    # Event Delete Confirmation?
    if ($user) {
        my $confirm = $user->confirm_delete || 'none';
        my %labels = (none   => $i18n->get ('Never ask'),
                      all    => $i18n->get ('Any Event'),
                      repeat => $i18n->get ('Only Repeating Events'));
        push @sections,
          table ({class => 'optsection'},
                 Tr (th ({-colspan => 2},
                         $i18n->get ('Confirmation for Deleting Events'))),
                 Tr (td ($i18n->get ('Ask when deleting' . ':')),
                     td (popup_menu (-name => 'DeleteConfirm',
                                     -default => $confirm,
                                     -values  => [qw (none all repeat)],
                                     -labels  => \%labels))),
                 Tr (td {-colspan => 2, -align => 'center'},
                     submit (-name  => 'DeleteConfirmButton',
                             -value => $i18n->get ('Change Delete Confirmation')
                            )));
    }

    my @rows = map {Tr (td ($_))} @sections;
    print table (Tr (@rows));

    if (!$isPopup) {
        my $nextURL = $self->makeURL ({Op => $nextOp});
        print $cgi->center (a ({href => $nextURL},
                               $i18n->get ('Back to Calendar')));
    } else {
        my $nextURL = $self->makeURL ({Op => 'AdminPageUser'});
        print $cgi->center (a ({href => $nextURL},
                               $i18n->get ('Done')));
    }

    print hidden (-name => 'Op',     -value => 'UserOptions');
    print hidden (-name => 'NextOp', -value => $nextOp);
    print $self->hiddenDisplaySpecs;
    print hidden (-name => 'CalendarName', -value => $self->calendarName)
        if $self->calendarName;

    print endform;
    print $cgi->end_html;
}

# override the default, since this op has security 'None' (see AdminAudit.pm)
sub auditType {
    return 'UserOptions';
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    $line .= " $self->{audit_action}"        if $self->{audit_action};
    $line .= " error - $self->{audit_error}" if ($self->{audit_error});
    $line .= " $self->{audit_data}"          if ($self->{audit_data});
    $line;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    $css .= $self->cssString ('table', {padding            => '15px',
                                        margin             => '5px'});
    $css .= $self->cssString ('.optsection', {'background-color' => '#eeeeee',
                                              padding            => '15px',
                                              margin             => '5px'});
    return $css;
}

1;
