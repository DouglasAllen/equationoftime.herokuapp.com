# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Auditing Options
package AdminAuditing;
use strict;

use CGI (':standard');
use Calendar::GetHTML;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($save, $cancel, $sysset) = $self->getParams (qw (Save Cancel SysSet));

    my $db  = $self->db;
    my $cgi = new CGI;

    if ($cancel) {
        my $op = $self->isSystemOp ? 'SysAdminPage' : 'AdminPage';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my ($calendars, $preferences) = $self->getCalsAndPrefs;
    $db = $self->dbByName ($calendars->[0])
        if ($self->isMultiCal and $calendars->[0]);

    my @opTypes = qw (View Add AddTentative Edit Admin);
    if (Defines->mailEnabled) {
        push @opTypes, 'Subscribe';     # for user subscription requests
    }

    if ($self->isSystemOp and $sysset) {
        @opTypes = qw (SysAdmin UserLogin UserOptions);
    }

    my $override = 1;
    my $message = $self->adminChecks;

    if (!$message and $save) {
    CHECK_ERRORS: {
        $override = 0;

        my @changed;

        my (@setEmail, $setEmail);
        my $mailToggle = $self->getOnChangeName ('EmailAddresses');
        if (!$self->isMultiCal or
            ($self->{params}->{$mailToggle} eq 'change')) {
            push @changed, 'Email Address';
            $setEmail = 1;
            my $newEmail = $cgi->param ('EmailAddresses');
            $newEmail =~ s/,/ /g;
            $newEmail =~ s/\s+/ /g;
            @setEmail = split /\s/, $newEmail;
            push @setEmail, '' if (!@setEmail);
        }

        my $filename;
        my $filenameToggle = $self->getOnChangeName ('Filename');
        if (!$self->isMultiCal or
            ($self->{params}->{$filenameToggle} eq 'change')) {
            push @changed, 'Filename';
            $filename = $cgi->param ('Filename') || '';
            $filename =~ s/^\s+//;
            $filename =~ s/\s+$//;
            my $blah = $filename;
            $blah =~ s{[-\\/\.:]}{}g;
            if ($blah =~ /\W/) {
                $message = 'Error: only letters, digits, underscores, '
                         . 'periods, colons, and slashes '
                         . 'are allowed in the filename.';
                $filename = undef;
                last CHECK_ERRORS;
            } else {
                $filename ||= 'CalciumAuditLog';
            }
        }

        my (%setAuditing, %ignoreOp);
        foreach my $op (@opTypes) {
            my $name = "Checks-$op";
            my @boxes = $cgi->param ($name);
            my $theOp = ($op eq 'SysAdmin' ? 'Admin' : $op);
            $setAuditing{$theOp} = \@boxes;
            if ($self->isMultiCal) {
                my $togName = $self->getOnChangeName ($op);
                $ignoreOp{$op} = ($self->{params}->{$togName} eq 'ignore');
                push (@changed, $op) unless $ignoreOp{$op};
            } else {
                push (@changed, $theOp);
            }
        }

        $message = $self->getModifyMessage (cals => $calendars,
                                            mods => \@changed);

        last CHECK_ERRORS if (!@changed);

        # Save everything
        $self->{audit_formsaved}++;
        foreach (@$calendars) {
            my %orig;       # for auditing this op
            my $db = $self->dbByName ($_);

            if ($setEmail) {
                $orig{email} = [$db->auditingEmail];
                $db->auditingEmail (@setEmail);
            }
            if (defined $filename) {
                $orig{filename} = $db->auditingFile;
                $db->auditingFile ($filename);
            }

            foreach my $op (@opTypes) {
                my $theOp = ($op eq 'SysAdmin' ? 'Admin' : $op);
                next if $ignoreOp{$theOp};
                $orig{"type_$theOp"} = [$db->getAuditing ($theOp)];
                $db->setAuditing ($theOp, @{$setAuditing{$theOp}});
            }
            $self->{audit_info}->{defined ($_) ? $_ : ' MASTER '} = \%orig;
        }
    }
    }

    print GetHTML->startHTML (title => $i18n->get ('Auditing'),
                              op    => $self);

    print '<center>';
    if (!$self->isSystemOp) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $self->calendarName || '',
                                    goob    => $self->goobLabel    || '',
                                    group   => $self->groupName    || '',
                                    section => 'Auditing');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Auditing', $sysset ? 1 : undef);
    }

    print $cgi->h3 ($message) if $message;
    print '<br>';
    print '</center>';

    print startform;

    # If group, allow selecting any calendar we have Admin permission for
    my %onChange = ();
    if ($self->isMultiCal) {
        my ($calSelector, $message) = $self->calendarSelector;
        print $message if $message;

        foreach (qw /View Add AddTentative Edit Admin Subscribe
                     EmailAddresses Filename/) {
            $onChange{$_} = $self->getOnChange ($_);
        }
        print $calSelector if $calSelector;
    }



    my %opLabels = (View         => 'View Calendar',
                    Add          => 'Add Events',
                    AddTentative => 'Add Tentative Events',
                    Edit         => 'Edit/Delete Events',
                    Admin        => 'Calendar Administration',
                    Subscribe    => 'User Subscription Requests',
                    SysAdmin     => 'System Administration',
                    UserLogin    => 'User Login and Logout',
                    UserOptions  => 'User Options');

    my @checkValues = qw (file email);
    my %checkLabels = (file  => $i18n->get ('Log to File'),
                       email => $i18n->get ('Send Email'));

    my @rows;
    foreach my $op (@opTypes) {
        my $storedOp = ($op eq 'SysAdmin' ? 'Admin' : $op);
        my @types = $db->getAuditing ($storedOp);

        push @rows, Tr ($self->groupToggle (name => $op),
                        td ('&nbsp;'),
                        td ($i18n->get ($opLabels{$op})),
                        td ('&nbsp;'),
                        td (checkbox_group (-name   => "Checks-$op",
                                            -onChange => $onChange{$op},
                                            -override => $override,
                                            -Values => \@checkValues,
                                            -labels => \%checkLabels,
                                            -default => \@types)));
    }

    print table (@rows);

    my $filename = $db->auditingFile || 'CalciumAuditLog';
    my $mailRow = '';
    my $emailAddrs = join ' ', ($db->auditingEmail || '');
    $mailRow = Tr ($self->groupToggle (name => 'EmailAddresses'),
                   td ('&nbsp;'),
                   td (b ($i18n->get ('Email to') . ': ')),
                   td (textfield (-name => 'EmailAddresses',
                                  -default => $emailAddrs,
                                  -onChange => $onChange{EmailAddresses},
                                  -override => $override,
                                  -columns => 60)),
                   td ('<small>' .
                       $i18n->get ('Separate multiple addresses with ' .
                                   'spaces or commas.') .
                       '</small>'));

    print table (Tr ($self->groupToggle (name => 'Filename'),
                     td ('&nbsp;'),
                     td (b ($i18n->get ('Filename') . ': ')),
                     td (textfield (-name => 'Filename',
                                    -default => $filename,
                                    -onChange => $onChange{Filename},
                                    -override => $override,
                                    -columns => 60)),
                     td ('<small>' .
                         'Unless it specifies a full path, ' .
                         $i18n->get ('the file will be located in') . ' "' .
                         Defines->baseDirectory . '/data"</small>')),
                 $mailRow);

    my ($setAlljs, $setAllRow) = $self->setAllJavascript;
    print $setAlljs;
    print $setAllRow;

    print '<hr>';
    print submit (-name => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print '&nbsp;';
    print reset  (-value => 'Reset');

    print $self->hiddenParams;
    print hidden (-name => 'SysSet', -value => 1) if $sysset;

    print endform;
    print $self->helpNotes;
    print $cgi->end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->basicAuditString ($short);
    my $i18n = $self->I18N;

    my $cal = $self->currentCal;
    my $old = $self->{audit_info}->{defined $cal ? $cal : ' MASTER '};
    my $db  = $self->dbByName ($cal);

    my $info = '';

    my $oldFile = $old->{filename}  || '[]';
    my $newFile = $db->auditingFile || '[]';

    if ($oldFile ne $newFile) {
        $info .= "\n" unless $short;
        $info .= $i18n->get ('Filename') . ': ' . "$oldFile -> $newFile";
    }

    my $oldMail = $old->{email} || [];
    my @newMail = $db->auditingEmail;
    my $newMail = join ',', @newMail;
       $oldMail = join ',', @$oldMail;
    if ($oldMail ne $newMail) {
        $info .= "\n" unless $short;
        $info .= $i18n->get (' Email') . ': ' . "$oldMail -> $newMail";
    }

    foreach my $op (qw (View Add AddTentative Edit Admin Subscribe
                        SysAdmin UserLogin UserOptions)) {
        my $orig = join (',', @{$old->{"type_$op"} || []}) || 'none';
        my $new  = join (',', $db->getAuditing ($op))      || 'none';
        next if ($orig eq $new);
        $info .= "\n" unless $short;
        $info .= " [$op: $orig -> $new ] ";
    }

    return unless $info;
    return "$line $info";
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
