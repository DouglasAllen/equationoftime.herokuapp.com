# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Rename a Calendar

package RenameCalendar;
use strict;

use CGI (':standard');

use Calendar::GetHTML;
use Calendar::User;
use Operation::CreateCalendar;   # just for checking validty of name 

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($save, $cancel, $oldName, $newName) =
                $self->getParams (qw (Save Cancel OldName NewName));

    my $i18n = $self->I18N;
    my $cgi  = new CGI;
    my ($message, $badName);


    # if we've been cancel-ed, go back
    if ($cancel or $self->calendarName) {
        print $self->redir ($self->makeURL ({Op => 'SysAdminPage'}));
        return;
    }

    # if we're passed the info and told to, try renaming
    if ($oldName or $newName or $save) {
        ($message, $badName) = CreateCalendar->checkName ($newName, $i18n);
        $self->{audit_error} = $badName ? 'illegal name'
                                        : ($message ? 'already exists' : '');
        unless ($message) {
            if (MasterDB->renameCalendar ($oldName, $newName)) {
                $message = $i18n->get ('Successfully renamed the calendar!');
                $message .= '<br>' . $i18n->get ('Old Name:') . " $oldName";
                $message .= '<br>' . $i18n->get ('New Name:') . " $newName";
            } else {
                $message = "Error: couldn't rename the calendar!";
                $message .= '<br>' . $i18n->get ('Old Name:') . " $oldName";
                $message .= '<br>' . $i18n->get ('New Name:') . " $newName";
                $self->{audit_error} = 'failed';
            }
        }
        $self->{audit_formsaved}++;
        $self->{audit_oldname} = $oldName || '';
        $self->{audit_newname} = $newName || '';
    }

    # And display (or re-display) the form
    print GetHTML->startHTML (title => $i18n->get ('Rename Calendar'),
                              op    => $self);
    print GetHTML->SysAdminHeader ($i18n, 'Rename Calendar', 1);
    print '<br>';

    print '<center>' . $cgi->h3 ($message) . '</center>' if $message;

    print $cgi->startform;

    my @existingNames = sort {lc($a) cmp lc($b)} MasterDB->getAllCalendars;

    my $color = $badName ? 'red' : '';

    print table (Tr (td (b ($i18n->get ('Calendar to rename: '))),
                    td (popup_menu (-name   => 'OldName',
                                    -Values => \@existingNames))),
                Tr ((td (b ($i18n->get ('New Name:'))),
                     td (textfield (-name     => 'NewName',
                                    -size     => 20)),
                     td (font ({size => -2, color => $color},
                               $i18n->get ('Any combination of letters, ' .
                                           'digits, and underscores'))))));

    print '<hr>';
    print submit (-name  => 'Save',
                  -value => $i18n->get ('Rename Calendar'));
    print '&nbsp;';
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Done'));
    print '&nbsp;';
    print hidden (-name => 'Op', -value => 'RenameCalendar');
    print reset  (-value => 'Reset');

    print $cgi->endform;
    print $cgi->end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    $line .= " $self->{audit_oldname} -> $self->{audit_newname}" .
               ($self->{audit_error} ? " $self->{audit_error}" : '');
    return $line;
}

1;
