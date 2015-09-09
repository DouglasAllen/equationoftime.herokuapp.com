# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Delete all Events in a Date Range
package AdminDeleteEvents;
use strict;
use CGI;

use Calendar::Date;
use Calendar::GetHTML;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my ($save, $cancel) = $self->getParams (qw (Save Cancel));
    my ($calName) = $self->calendarName;

    my $preferences = $self->prefs;
    my $i18n        = $self->I18N;

    my $cgi = new CGI;

    if ($cancel) {
        print $self->redir ($self->makeURL({Op => 'AdminPage'}));
        return;
    }

    my $message;

    if ($save) {
        my ($fromYear, $fromMonth, $fromDay) =
                                        @{$self->{params}}{qw (FromYearPopup
                                                               FromMonthPopup
                                                               FromDayPopup)};
        my ($toYear, $toMonth, $toDay) =
                                        @{$self->{params}}{qw (ToYearPopup
                                                               ToMonthPopup
                                                               ToDayPopup)};
        my $errorMessage;
        if (!Date->valid ($fromYear, $fromMonth, $fromDay)) {
            $errorMessage = $i18n->get ('<br>Invalid <b>From</b> Date');
        }
        if (!Date->valid ($toYear, $toMonth, $toDay)) {
            $errorMessage = $i18n->get ('<br>Invalid <b>To</b> Date');
        }
        if ($errorMessage) {
            GetHTML->errorPage ($i18n,
                                header  => $i18n->get('Error deleting events'),
                                message => $errorMessage);
            $self->{audit_error} = 'bad date';
            return;
        }
        my $fromDate = Date->new ($fromYear, $fromMonth, $fromDay);
        my $toDate   = Date->new ($toYear, $toMonth, $toDay);

        my @categories = $cgi->param ('Categories');

        my $ids = $self->db->deleteEventsInRange (from => $fromDate,
                                                  to   => $toDate,
                                                  categories => \@categories);
        $self->{audit_formsaved}++;
        $self->{audit_count} = @$ids + 0;
        $self->{audit_from} = $fromDate;
        $self->{audit_to}   = $toDate;
        $self->{audit_cats} = \@categories;
        $message = $i18n->get ('Number of events deleted') . ': ' .
                   $self->{audit_count};
    }

    print GetHTML->startHTML (title  => $i18n->get ('Delete Events in a Range')
                                        . ": $calName",
                              op     => $self);
    print GetHTML->AdminHeader (I18N    => $i18n,
                                cal     => $calName,
                                section => 'Delete Events');
    print '<br>';

    print $cgi->h2 ({size => +2}, $message) if $message;

    my $headStyle = 'font-weight:bold';
    print qq (<span style="$headStyle">);
    print $i18n->get ('Delete events in this date range') . ':';
    print '</span>';
    print '<br><br>';

    my $script = <<'    END_JAVASCRIPT';
    :    <script language="JavaScript">
    :    <!-- start
    :    // Make sure dates are OK (or cancel pressed)
    :    function submitCheck (theForm, baseYear) {
    :        if (theForm.Cancel.pressed) {
    :            return true;
    :        }
    :        fromMonth = theForm.FromMonthPopup.selectedIndex;
    :        fromDay   = theForm.FromDayPopup.selectedIndex + 1;
    :        fromYear  = theForm.FromYearPopup.selectedIndex + baseYear;
    :        toMonth   = theForm.ToMonthPopup.selectedIndex;
    :        toDay     = theForm.ToDayPopup.selectedIndex + 1;
    :        toYear    = theForm.ToYearPopup.selectedIndex + baseYear;
    :        fromDate = new Date (fromYear, fromMonth, fromDay);
    :        toDate   = new Date (toYear,   toMonth,   toDay);
    :        gotMonth = fromDate.getMonth();
    :        gotDay   = fromDate.getDate();
    :        if (gotMonth != fromMonth || gotDay != fromDay) {
    :            alert ('From Date is invalid.');
    :            return false;
    :        }
    :        gotMonth = toDate.getMonth();
    :        gotDay   = toDate.getDate();
    :        if (gotMonth != toMonth || gotDay != toDay) {
    :            alert ('To Date is invalid.');
    :            return false;
    :        }
    :        if (fromDate.valueOf() > toDate.valueOf()) {
    :            alert ('To Date cannot be before From Date.');
    :            return false;
    :        }
    :        return true;
    :    }
    :    // End -->
    :    </script>
    END_JAVASCRIPT
    $script =~ s/^\s*:\s*//mg;
    print $script;

    my ($yearStart, $earliestDate);
    $yearStart = Date->new;
    $yearStart->month(1);
    $yearStart->day(1);
    $earliestDate = Date->new ($yearStart);
    $earliestDate->addYears(-10);

    print $cgi->startform (-onSubmit =>
                                  "return submitCheck(this, $earliestDate)");

    my $fromPopup = GetHTML->datePopup ($i18n,
                                        {name     => 'From',
                                         default  => $yearStart,
                                         start    => $earliestDate,
                                         numYears => 20});
    my $toPopup   = GetHTML->datePopup ($i18n,
                                        {name     => 'To',
                                         default  => Date->new - 1,
                                         start    => $earliestDate,
                                         numYears => 20});
    print $cgi->table ($cgi->Tr ($cgi->td ($cgi->b ($i18n->get ('From:'))),
                                 $cgi->td ($fromPopup)),
                       $cgi->Tr ($cgi->td ($cgi->b ($i18n->get ('To:'))),
                                 $cgi->td ($toPopup)));

    print '<hr align="left" width="25%"><br>';
    print qq (<span style="$headStyle">);
    print $i18n->get ('Only events in these categories:');
    print '</span><br><br>';
    print GetHTML->categorySelector (op   => $self,
                                     name => 'Categories');

    print '<br><br><hr>';
    print $cgi->submit (-name  => 'Save',
                        -value => $i18n->get ('Delete Events'));
    print '&nbsp;';
    print $cgi->submit (-name    => 'Cancel',
                        -value   => $i18n->get ('Cancel'),
                        -onClick => 'this.pressed = true');
    print '&nbsp;';
    print $cgi->reset  (-value => $i18n->get ('Reset'));

    print $cgi->hidden (-name => 'Op',          -value => 'AdminDeleteEvents');
    print $cgi->hidden (-name => 'CalendarName', -value => $calName);

    print $cgi->endform;

    print '<br>';
    print $cgi->span ({-style => $headStyle}, $i18n->get ('Notes') . ':');
    print '<ul>';
    print '<li>';
    print $i18n->get ('If you select one or more categories; only events ' .
                      'in any of the selected categories will be deleted.' );
    print '<br>';
    print $i18n->get ('Otherwise, <b>all</b> events between the specified ' .
                      'dates will be deleted.');
    print '</li>';
    print '<li>';
    print $i18n->get ('Repeating Events will be deleted if the repeat ' .
                      'period both starts and ends within the specified ' .
                      'range.');
    print '</li>';
    print '</ul>';


    print $cgi->end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};

    my $line = $self->SUPER::auditString ($short);
    return ($line . ' ' . $self->{audit_error}) if $self->{audit_error};

    $line .= " $self->{audit_from}-$self->{audit_to}; ";
    if (my @cats = @{$self->{audit_cats}}) {
        $line .= $self->I18N->get ('Categories') . ': ' .
                 join (',', @cats) . '; ';
    }
    $line .= "$self->{audit_count} events";
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
