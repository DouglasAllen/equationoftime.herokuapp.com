# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# MailSender.pm - generic interface to some mailing situation
#                 if local 'sendmail' binary found, use that; otherwise, use
#                 Mail::Sendmail or (Mail::Sender if AUTH needed)

use strict;
package MailSender;
use Calendar::MasterDB;

my @locations = qw (/usr/sbin/sendmail /usr/bin/sendmail /usr/lib/sendmail);

sub new {
    my $package = shift;
    my %args = (To   => '',
                From => 'Calcium',
                SMTP => 'localhost',
                AuthType => undef,     # if this specified,
                AuthID   => undef,     #       then we use
                AuthPW   => undef,     #           Mail::Sender
             'X-Mailer' => 'Calcium web calendar; http://www.brownbearsw.com',
                @_);
    my $self = \%args;

    # Grab authentication options from Master prefs
    my $prefs = MasterDB->new->getPreferences;
    if ($prefs->SMTPAuth) {
        $self->{AuthType} = $prefs->SMTPAuthType;
        $self->{AuthID}   = $prefs->SMTPAuthID;
        $self->{AuthPW}   = $prefs->SMTPAuthPW;
    }

    bless $self, $package;
    $self;
}

# $hashOrMessage is either a scalar, which will be used as message body, or
# a ref to a hash, containing one or more of 'text', 'html', 'attachment'
# keys for multipart mail. Handles only single attachment!
sub send {
    my $self = shift;
    my ($subject, $hashOrMessage) = @_;
    my $message = $hashOrMessage unless (ref $hashOrMessage);

    my $textBlurb = "\n\n----\nSent from Calcium Web Calendar - " .
                    "Demo version.    http://www.brownbearsw.com\n";
    my $htmlBlurb = '<br><p align="center">Sent from Calcium Web Calendar - ' .
                    'Demo version. <a href="http://www.brownbearsw.com">' .
                    '<b>http://www.BrownBearSW.com</b></a></p>';

    if (ref $hashOrMessage) {
        my $textPart = $hashOrMessage->{text} || '';
        my $htmlPart = $hashOrMessage->{html} || '';

        if ($htmlPart) {
            # insert newlines in HTML part (where these is already a
            # space), since some mailers gag on long lines
            my $i = 128;
            while ($i < length($htmlPart)) {
                my $x = index ($htmlPart, ' ', $i);
                last if ($x < $i);
                substr ($htmlPart, $x, 0) = "\n";
                $i = $x + 128;
            }
        }

        my $mixedContentType;
        if ($textPart and $htmlPart) {
            my $bound = 'UrsusHorribilis-2-' . time;
            $self->{'Content-type'} =
                               "multipart/alternative; boundary=\"$bound\"";
            $self->{'MIME-Version'} = "1.0";
            my $x = "--$bound\n";
            $x .= "Content-type: text/plain; charset=us-ascii;\n";
            $x .= "Content-transfer-encoding: 7bit\n\n";
            $x .= $textPart;
            $x .= $textBlurb if (Defines->isDemo);
            $x .= "\n\n--$bound\n";
            $x .= "Content-type: text/html; charset=us-ascii;\n";
            $x .= "Content-transfer-encoding: 7bit\n\n";
            $x .= $htmlPart;
            $x .= $htmlBlurb if (Defines->isDemo);
            $x .= "\n\n--$bound--\n\n";
            $message = $x;
            $mixedContentType = "multipart/alternative; boundary=\"$bound\"";
        } elsif ($textPart) {
            $message  = $textPart;
            $message .= $textBlurb if (Defines->isDemo);
            $mixedContentType = "text/plain; charset=us-ascii";
        } elsif ($htmlPart) {
            $self->{'Content-type'} = "text/html; charset=us-ascii";
            $message  = $htmlPart;
            $message .= $htmlBlurb if (Defines->isDemo);
            $mixedContentType = "text/html; charset=us-ascii";
        }

        # If attaching, wrap message in multipart/mixed
        if (my $attach = $hashOrMessage->{attachment}) {
            my $bound = 'UrsusHorribilis-1-' . time;
            $self->{'Content-type'} =
                               "multipart/mixed; boundary=\"$bound\"";
            $self->{'MIME-Version'} = "1.0";
            my $x = "--$bound\n";

            $x .= "Content-type: $mixedContentType\n";
            $x .= "Content-transfer-encoding: 7bit\n"
                unless ($mixedContentType =~ /multipart/);
            $x .= "\n$message\n";

            $attach->{type}        ||= 'text/calendar';
            $attach->{encoding}    ||= '7bit';
            $attach->{disposition} ||= 'attachment; filename=CalciumEvent.ics';
            $x .= "\n--$bound\n";
            $x .= "Content-type: $attach->{type}\n";
            $x .= "Content-Transfer-Encoding: $attach->{encoding}\n";
            $x .= "Content-Disposition: $attach->{disposition}\n";
            $x .= "\n$attach->{contents}\n";
            $x .= "\n--$bound--\n\n";
            $message = $x;
        }
    } else {
        $message .= $textBlurb if (Defines->isDemo);
    }

    my %params;
    foreach (qw (To From CC BCC MIME-Version Content-type X-Mailer)) {
        $params{$_} = $self->{$_} if $self->{$_};     # allowed headers
    }

    $params{smtp}    = $self->{SMTP};
    $params{Subject} = $subject || $self->{subject};
    $params{body}    = $message || $self->{message};

    # if any address has no @, try expanding our built-in Aliases
    my $prefs = MasterDB->new->getPreferences;
    foreach my $field (qw (To CC BCC)) {
        my $addrs = $params{$field};
        next unless defined $addrs;
        my @addrs = split /[, ]+/, $addrs;
        foreach (@addrs) {
            next if /@/;
            $_ = join (',', $prefs->getMailAlias ($_)) || $_;
        }
        $params{$field} = join ',', @addrs;
    }

#DEBUGGING
# $params{body} .= "Originally-To: $params{To}";
# $params{To}    = 'fred@localhost';

    # look for sendmail binary
    my $sendmail;
    foreach (@locations) {
        $sendmail = $_ if -x;
        last if $sendmail;
    }

    # didn't find it, use Mail::Sendmail or Mail::Sender
    if (!defined $sendmail or $self->{AuthType}) {
        unless ($self->{AuthType}) {
            # note that sendmail is not sendmail, it's just called sendmail.
            require Mail::Sendmail;
            $params{'X-Mailer'} .=" (Mail::Sendmail $Mail::Sendmail::VERSION)";
            my $ok = Mail::Sendmail::sendmail (%params);
            $self->{error} = $Mail::Sendmail::error unless ($ok);
            $self->{log}   = $Mail::Sendmail::log;
            return $ok;         # returns true if ok
        }
        require Mail::Sender;
        my $sender = Mail::Sender->new;
        $Mail::Sender::NO_X_MAILER = 1;
        my %args = (from    => $params{From},
                    to      => $params{To},
                    cc      => $params{CC},
                    bcc     => $params{BCC},
                    subject => $params{Subject},
                    msg     => $params{body},
                    headers => 'X-Mailer: ' . $params{'X-Mailer'} .
                               " (Mail::Sender $Mail::Sender::VERSION)");
        if (my $ctype = $params{'Content-type'}) {
            $args{headers} .= "\nContent-type: $ctype";
            $args{headers} .= "\nMIME-Version: 1.0";
        }
        $args{smtp}    = $params{smtp} || 'localhost';
        $args{auth}    = $self->{AuthType};
        $args{authid}  = $self->{AuthID} if $self->{AuthID};
        $args{authpwd} = $self->{AuthPW} if $self->{AuthPW};

        my $ok = $sender->MailMsg (\%args);
        $self->{error} = $Mail::Sender::Error unless (ref $ok);
        return (ref $ok);
    }

    # found it, use sendmail
    my $headers;
    foreach (qw (To From CC BCC Subject MIME-Version Content-type X-Mailer)) {
        $headers .= "$_: $params{$_}\n" if $params{$_};
    }

    # Specify envelope from, so errors bounce to the right place
    my $envFrom = $params{From} ? "-f $params{From}" : '';
    $envFrom =~ s(')(\\')g;
    $envFrom = "'$envFrom'";
    $envFrom =~ /(.*)/;
    $envFrom = $1;
    my $ok = open (SENDMAIL, "|$sendmail -oi -t $envFrom");

    if ($ok) {
        print SENDMAIL <<"END_MAIL";
$headers
$params{body}
END_MAIL
        close SENDMAIL;
    } else {
        $self->{error} = "Can't run $sendmail: $!\n";
    }

    my $to = '';
    $to .= "To $params{To} " if $params{To};
    $to .= "CC $params{CC} " if $params{CC};
    $to .= "BCC $params{BCC} " if $params{BCC};
    $self->{log}   = "Sent message $to";
    $ok;         # returns true if ok
}

sub error {
    $_[0]->{error};
}
sub log {
    $_[0]->{log};
}

1;
