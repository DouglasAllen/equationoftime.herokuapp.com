# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Email settings

package SysMail;
use strict;

use CGI (':standard');

use Calendar::GetHTML;
use Calendar::Mail::MailSender;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($save, $saveAlias, $cancel, $test,
        $smtpHost, $from, $signature, $testTo) =
                   $self->getParams (qw (SaveSettings SaveAlias Cancel Test
                                         SMTPHost From Signature TestTo));
    my ($useAuth, $authType, $authID, $authPW) =
        $self->getParams (qw (UseSMTPAuth AuthType AuthID AuthPW));

    my $i18n  = $self->I18N;
    my $cgi   = new CGI;
    my $prefs = $self->prefs;

    my $message;

    if ($cancel or $self->calendarName) {
        print $self->redir ($self->makeURL ({Op => 'SysAdminPage'}));
        return;
    }

    if ($save) {
        $self->{audit_formsaved}++;
        $self->{audit_MailSMTP}      = $prefs->MailSMTP;
        $self->{audit_MailFrom}      = $prefs->MailFrom;
        $self->{audit_MailSignature} = $prefs->MailSignature;
        $self->{audit_SMTPAuth}      = $prefs->SMTPAuth;
        $self->{audit_SMTPAuthType}  = $prefs->SMTPAuthType;
        $self->{audit_SMTPAuthID}    = $prefs->SMTPAuthID;
        $self->{audit_SMTPAuthPW}    = $prefs->SMTPAuthPW;

        $signature =~ s/\r\n/\n/g if defined $signature;

        my %newPrefs;
        $newPrefs{MailSMTP}      = $smtpHost  if defined $smtpHost;
        $newPrefs{MailFrom}      = $from      if defined $from;
        $newPrefs{MailSignature} = $signature if defined $signature;
        $newPrefs{SMTPAuth}      = $useAuth || 0;
        $newPrefs{SMTPAuthType}  = $authType if defined $authType;
        $newPrefs{SMTPAuthID}    = $authID   if defined $authID;
        $newPrefs{SMTPAuthPW}    = $authPW   if defined $authPW;

        $self->db->setPreferences (\%newPrefs);
        $prefs = $self->prefs ('force');
    }

    if ($saveAlias) {
        $self->{audit_formsaved}++;
        my $newAlias   = $self->{params}->{NewAliasName};
        my $newAddress = $self->{params}->{NewAliasAddress};

        # first, add new one
        if (defined $newAlias and $newAlias ne '') {
            $message = $self->_checkName ($newAlias);
            unless ($message) {
                my @addrs = split '[, ]+', $newAddress;
                $prefs->setMailAlias ($newAlias, @addrs) if defined $newAlias;
            }
        }

        # then, get deletes and changes to existing
        foreach (keys %{$self->{params}}) {
            next unless /^AliasValue-(.*)/;
            my $aliasName = $1;
            $prefs->deleteMailAlias ($aliasName), next
                if $self->{params}->{"Delete-$aliasName"};

            my @addrs = split '[, ]+',
                              $self->{params}->{"AliasValue-$aliasName"};
            $prefs->setMailAlias ($aliasName, @addrs);
        }

        $self->db->setPreferences ($prefs);
    }

    $smtpHost  ||= $prefs->MailSMTP;
    $from      ||= $prefs->MailFrom;
    $signature ||= $prefs->MailSignature;
    $useAuth   ||= $prefs->SMTPAuth;
    $authType  ||= $prefs->SMTPAuthType;
    $authID    ||= $prefs->SMTPAuthID;
    $authPW    ||= $prefs->SMTPAuthPW;

    # send a test message, maybe
    if ($test) {
        my %args = (To   => $testTo,
                    From => $from,
                    SMTP => $smtpHost);
        my $mailer = MailSender->new (%args);
        my $text = $i18n->get ('This test message was sent from Calcium.');
        my %sig = (text => '', html => '');
        if ($signature) {
            $signature =~ s/\r//g;
            $sig{text} = "\n\n$signature\n";
            ($sig{html} = $signature) =~ s/[\n]/<br>/g;
        }
        my %contents = (text => $text . $sig{text},
                        html => '<!doctype html public ' .
                                '"-//w3c//dtd html 4.0 transitional//en">' .
                                "\n\n" .
                                "<html><body><p>$text</p><p>$sig{html}</p>");
        my $ok = $mailer->send ($i18n->get ('Test Message'), \%contents);
        if ($ok) {
            $message = $i18n->get ('Test Mail sent without obvious errors');
        } else {
            $message = $i18n->get ('Test Mail had errors!') . '<br>&nbsp; ' .
                       $mailer->error;
        }
    }

    # And display (or re-display) the form
    print GetHTML->startHTML (title  => $i18n->get ('Email Settings'),
                              op     => $self,
                              onLoad => 'authClicked()');

    print <<END_SCRIPT;
 <script language="JavaScript">
 <!--
    function authClicked () {
        cbox = document.forms[0].UseSMTPAuth;
        cbox.form.AuthType.disabled = !cbox.checked;
        cbox.form.AuthID.disabled   = !cbox.checked;
        cbox.form.AuthPW.disabled   = !cbox.checked;
    }
-->
 </script>
END_SCRIPT

    print GetHTML->SysAdminHeader ($i18n, 'Email Settings', 1);
    print '<br>';

    print $cgi->h3 ($message) if $message;

    print $cgi->startform;

    print table (Tr (td (b ($i18n->get ('SMTP Host') . ': ')),
                     td (textfield (-name    => 'SMTPHost',
                                    -default => $smtpHost,
                                    -size    => 40)),
                     td (font ({size => -2},
                               $i18n->get ('The name of your SMTP server ' .
                                           '(e.g. ' .
                                           'mail.domainname.com). You can ' .
                                           'leave this blank to use the ' .
                                           'same machine Calcium is running ' .
                                           'on.')))),
                 Tr (td (b ($i18n->get ('From Address') . ': ')),
                     td (textfield (-name    => 'From',
                                    -default => $from,
                                    -size    => 40)),
                     td (font ({size => -2},
                               $i18n->get ('Email address for the "From:" ' .
                                           'field of mail sent from ' .
                                           'Calcium <b>-Required-</b>')))),
                 Tr (td ('&nbsp;')),
                 Tr (td (b ($i18n->get ('Signature Text') . ': ')),
                     td (textarea  (-name => 'Signature',
                                    -rows => 4,
                                    -cols => 50,
                                    -default => $signature)),
                     td (font ({size => -2},
                               $i18n->get ('Specify text to append to the ' .
                                           'end of every message sent ' .
                                           '(optional)')))),

                 Tr (td (b ($i18n->get ('Authenticated SMTP') . ': ')),
                     td ({-colspan => 2},
                         table (Tr (td ({-colspan => 5},
                                        checkbox (-name    => 'UseSMTPAuth',
                                                  -checked => $useAuth,
                                                  -label  =>'Use SMTP/Auth',
                                          -onClick => 'authClicked (this)'))),
                                Tr (td ({-width => 20}, '&nbsp;'),
                                    td ('Auth Type:'),
                          td (popup_menu (-name    => 'AuthType',
                                          -default => $authType,
                                          -values  => [qw/PLAIN LOGIN
                                                          CRAM-MD5/])),
                                    td ('Login:'),
                          td (textfield (-name => 'AuthID',
                                         -default => $authID,
                                         -size    => 20)),
                                    td ('Password:'),
                          td (password_field (-name => 'AuthPW',
                                              -default => $authPW,
                                              -size    => 20))))),
                    ));
    print '<br><center>';
    print submit (-name  => 'SaveSettings',
                  -value => $i18n->get ('Save Settings'));
    print '</center>';
    print hidden (-name => 'Op', -value => 'SysMail');

    # Email Alias stuff
    my @rows;
    my @alias = sort {lc($a) cmp lc($b)} $self->prefs->getMailAliasNames;
    foreach (@alias) {
        push @rows, Tr (td ({-align => 'center'},
                            checkbox (-name    => "Delete-$_",
                                      -checked => undef,
                                      -label   => '')),
                        td ($_),
                        td (textfield (-name     => "AliasValue-$_",
                                       -size     => 35,
                                       -override => 1,
                                       -default  => join ', ',
                                            $self->prefs->getMailAlias ($_))));
    }

    print "<hr width='95%'><center>";
    print h3 ($i18n->get ('Email Aliases'));
    print table ({-border  => 2, -cellpadding => 3},
                 Tr (th {-bgcolor => "#cccccc"},
                     [map {$i18n->get ($_)} (@rows ? 'Delete?' : '&nbsp;',
                                             'Alias', 'Addresses')]),
                 @rows,
                 Tr (td ({-bgcolor => "#eeeeee"},
                         [$i18n->get ('Add New Alias:'),
                          textfield (-name     => 'NewAliasName',
                                     -size     => 10,
                                     -override => 1,
                                     -default  => ''),
                          textfield (-name     => 'NewAliasAddress',
                                     -size     => 35,
                                     -override => 1,
                                     -default  => '')])));
    print '<br>';
    print submit (-name  => 'SaveAlias',
                  -value => $i18n->get (@rows ? 'Add/Modify/Delete Aliases'
                                              : 'Add Alias'));
    print '</center>';

    my $user = User->getUser ($self->getUsername);
    my $address = $user ? $user->email : '';

    print "<hr width='95%'><br>";

    print $i18n->get ('If you want to try sending a test message, enter an ' .
                      'email address here and press the button!');
    print '<br><small>',
          $i18n->get ('<b>Note:</b> Before testing, you should Save changes ' .
                      'made above.');
    print '</small>';

    print table (Tr (td (b ($i18n->get ('Send test mail to: '))),
                     td (textfield (-name    => 'TestTo',
                                    -default => $address,
                                    -size    => 40))));
    print '<center>';
    print submit (-name  => 'Test',
                  -value => $i18n->get ('Send Test Email'));
    print '</center>';

    print "<hr>";
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Done'));

    print $cgi->endform;

    print $cgi->end_html;
}

sub _checkName {
    my $self = shift;
    my $name = shift;

    my $i18n = $self->I18N;

    my $message;

    # Strip leading, trailing whitespace
    $name =~ s/^\s+//;
    $name =~ s/\s+$//;

    if ($name =~ /\W/) {
        $message = $i18n->get ('<font color="red">Error:</font> only '.
                               'letters, digits, and the underscore ' .
                               'are allowed in Mail Alias names.');
    } elsif ($name eq '') {
        $message = $i18n->get ('Error: cannot have blank Alias name');
    } elsif (grep {lc($name) eq lc($_)} $self->prefs->getMailAliasNames) {
        $message = $i18n->get ('<font color="red">Error:</font> ' .
                               'Alias already exists:') . " $name";
    }
    return $message;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    my $info;

    foreach (qw /MailSMTP MailFrom MailSignature
                 SMTPAuth SMTPAuthType SMTPAuthID SMTPAuthPW/) {
        my $old = $self->{"audit_$_"} || "''";
        my $new = $self->prefs->$_()  || "''";
        next if ($old eq $new);
        $info .= " [$_ $old -> $new]";
    }

    return unless $info;
    return $line . $info;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
