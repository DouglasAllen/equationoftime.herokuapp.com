# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Audit.pm

use strict;

package Audit;

# Pass in nothin'
sub new {
    my $class = shift;
    my ($self);
    $self = {};
    bless $self, $class;
    $self;
}

sub perform {
    my $self   = shift;
    my ($op, $db) = @_;
    my $string = $op->auditString ('short');
    return unless defined $string;
    # default is to just spit short string to the error log
    warn "Audit: $string\n";
}

############################################
package AuditLogFile;
use vars ('@ISA');
@ISA = ('Audit');

sub perform {
    my $self   = shift;
    my ($op, $db) = @_;
    my $string = $op->auditString ('short');
    return unless defined $string;

    my $filename = $db->auditingFile;
    return unless $filename;

    # if filename doesn't start with dir-traversing chars, put in 'data' dir
    if ($filename !~ m{^(          # filename starts with...
                        [/\\]      # ...forward or back slash
                       |[a-zA-Z]:  # ...or DOS drive name (e.g. D:)
                        )}x) {
        $filename = Defines->baseDirectory . '/data/' . $filename;
    }
    $filename =~ /^(.+)$/;    # untaint
    $filename = $1;           #         it
    my $ok = open AUDITFILE, ">>$filename";
    if (!$ok) {
        warn "Couldn't append to $filename: $!\n";
        return;
    }

    print AUDITFILE "$string\n";
    close AUDITFILE;
}

############################################
package AuditMail;
use vars ('@ISA');
@ISA = ('Audit');

sub perform {
    my $self   = shift;
    my ($op, $db) = @_;

    my $string = $op->auditString;
    return unless defined $string;

    my $opType = ref ($op);
    my $toList = join ', ', $db->auditingEmail;
    return unless $toList;

    my $masterPrefs = MasterDB->new->getPreferences;
    my $from = $op->prefs->MailFrom      || $masterPrefs->MailFrom;
    my $sig  = $op->prefs->MailSignature || $masterPrefs->MailSignature;
    require Calendar::Mail::MailSender;
    my $mailer = MailSender->new (To   => $toList,
                                  From => $from,
                                  SMTP => $masterPrefs->MailSMTP);
    my $ok = $mailer->send ($op->I18N->get ('Calcium Event') . ": $opType",
                            $string . "\n\n" . ($sig || ''));
    warn $mailer->error unless $ok;
}

############################################

package AuditFactory;

sub create {
    my $class = shift;
    my $type = shift;
    my $self = (($type eq 'file')  &&  AuditLogFile->new) ||
               (($type eq 'email') &&  AuditMail->new)    ||
               Audit->new;
    $self;
}

1;
