# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Delete a Calendar

package DeleteCalendar;
use strict;

use CGI (':standard');
use Calendar::GetHTML;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($cancel, $delete, @deleteList) =
                        $self->getParams (qw (Cancel Delete DeleteChecks));

    my $cgi = new CGI;

    # if we've been cancel'ed, go back
    if ($cancel or $self->calendarName) {
        print $self->redir ($self->makeURL ({Op => 'SysAdminPage'}));
        return;
    }

    # if we're passed the info and told to delete, delete the cals
    if ($delete and @deleteList) {
        @deleteList = $cgi->param ('DeleteChecks');  # else only get first one
        foreach (@deleteList) {
            # Remove this calendar from any other calendars 'include' list!
            Database->removeFromIncludeLists ($_);
            MasterDB->deleteCalendar ($_);
        }

        $self->{audit_formsaved}++;
        $self->{audit_deleted} = \@deleteList;
    }

    # and redisplay, to possibly delete another
    print GetHTML->startHTML (title => $i18n->get ('Delete a Calendar'),
                              op    => $self);
    print GetHTML->SysAdminHeader ($i18n, 'Delete a Calendar', 1);
    print '<br>';

    print startform;

    print '<center>';
    print $i18n->get ('Select one or more calendars to delete.') . '<br>';
    print $i18n->get ('<b>Be careful</b> - you will not get an ' .
                      '"are you sure?" prompt!');
    print '</center><br>';

    my @cals = sort {lc($a) cmp lc($b)} MasterDB->getAllCalendars;
    my %labels;
    foreach (@cals) {
        my $db = Database->new ($_);
        $labels{$_} = " $_ - " . $db->description;
    }

    print checkbox_group (-name      => 'DeleteChecks',
                          -override  => 1,
                          '-values'  => \@cals,
                          -labels    => \%labels,
                          -linebreak => 'true');
    print '<hr>';

    print submit (-name     => 'Delete',
                  -value    => $i18n->get ('Delete Checked Calendars'),
                  -override => 1);
    print '&nbsp;';
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Done'));
    print '&nbsp;';
    print hidden (-name => 'Op',     -value => 'DeleteCalendar');
    print reset  (-value => 'Reset');

    print endform;
    print $cgi->end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    $line = "$line " . join ",", @{$self->{audit_deleted}};
    return $line;
}

1;
