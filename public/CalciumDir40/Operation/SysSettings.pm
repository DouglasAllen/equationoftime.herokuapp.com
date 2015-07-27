# Copyright 2005-2006, Fred Steinberg, Brown Bear Software

# Some miscellaneous System-level settings

package SysSettings;
use strict;

use CGI (':standard');
use Calendar::GetHTML;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($save, $cancel, $instance_name) =
                $self->getParams (qw (Save Cancel InstName));

    my $i18n  = $self->I18N;
    my $prefs = $self->prefs;

    if ($cancel or $self->calendarName) {
        print $self->redir ($self->makeURL ({Op => 'SysAdminPage'}));
        return;
    }

    if ($save) {
        $self->{audit_formsaved}++;
        $self->{audit_oldname} = $prefs->InstName || ' - ';
        $self->{audit_newname} = $instance_name   || ' - ';
        $self->db->setPreferences ({InstName => $instance_name});
        $prefs = $self->prefs ('force');
    }

    print GetHTML->startHTML (title => $i18n->get ('System Settings'),
                              op    => $self);
    print GetHTML->SysAdminHeader ($i18n, 'Settings', 1);
    print '<br>';

    print startform;

    $instance_name = $prefs->InstName;

    print '<center>';
    print table (Tr (td (b ($i18n->get ('Installation Name: '))),
                     td (textfield (-name     => 'InstName',
                                    -default  => $instance_name || '',
                                    -size     => 25))));

    print p ($i18n->get ('This is the name to display instead of "Calcium"'));

    print '</center>';
    print '<hr>';
    print submit (-name  => 'Save',
                  -value => $i18n->get ('Save'));
    print '&nbsp;';
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Done'));
    print '&nbsp;';
    print hidden (-name => 'Op', -value => __PACKAGE__);

    print endform;
    print end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    $line .= " $self->{audit_oldname} -> $self->{audit_newname}";
    return $line;
}

1;
