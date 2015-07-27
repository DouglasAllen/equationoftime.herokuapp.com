# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# Email Subscription management
package AdminSubscriptions;
use strict;

use CGI;
use Calendar::GetHTML;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my ($saveDays, $saveEmail, $done, $enabled, $advanceDays) =
        $self->getParams (qw (SaveDays RemoveAddresses Done RemindersOn
                              DaysInAdvance));

    my $calName = $self->calendarName;
    my $db   = $self->db;
    my $cgi  = new CGI;
    my $i18n = $self->I18N;

    if ($done or !defined $calName) {
        my $op = $calName ? 'AdminPage' : 'Splash';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my $message;

    my $remindersOn = $self->prefs->RemindersOn;

    if ($saveDays) {
        $self->{audit_formsaved}++;

        $self->prefs->RemindersOn ($enabled);

        $advanceDays ||= '0';
        $advanceDays =~ s/\D/ /g; # remove non digits
        $advanceDays =~ s/ +/ /g; # compress spaces
        $advanceDays = join ' ',
                         sort {$b <=> $a}
                           grep {$_ <= 365 && $_ >= -365}
                             split ' ', $advanceDays;
        $self->prefs->RemindDays ($advanceDays);
        $self->db->setPreferences ($self->prefs);
    }

    if ($saveEmail) {
        $self->{audit_formsaved}++;

        # Remove selected addrs from 'All' list
        my @allSelected = $cgi->param ('AllEvents');
        if (@allSelected) {
            my @all = $self->prefs->getRemindAllAddresses;
            my %selected;
            @selected{map {lc $_} @allSelected} = 1;
            @all = grep {!exists $selected{lc($_)}} @all;
            $self->prefs->setRemindAllAddresses (@all);
        }

        # Remove selected addrs from category lists
        foreach my $param (keys %{$self->{params}}) {
            next unless ($param =~ /^Cat-(.*)$/);
            my $cat = $1;
            my @addrs = $cgi->param ($param);
            my $curr = $self->prefs->getRemindForCategory ($cat);
            my %selected;
            @selected{map {lc $_} @addrs} = 1;
            @addrs = grep {!exists $selected{lc($_)}} @$curr;
            $self->prefs->setRemindForCategory ($cat, \@addrs);
        }

        $self->db->setPreferences ($self->prefs);
    }

    print GetHTML->startHTML (title  => $i18n->get ('Email Subscriptions'),
                              op     => $self);
    print '<center>';
    print GetHTML->AdminHeader (I18N    => $i18n,
                                cal     => $calName,
                                section => 'Email Subscriptions');
    print '</center><br>';

    print $cgi->h3 ($message) if $message;

    print _setAll();

    my @categories = sort {lc ($a) cmp lc ($b)}
                       keys %{$self->prefs->getCategories (1)};
    my @catRows;
    my $catHash = $self->prefs->getRemindByCategory;
    foreach my $cat (@categories) {
        my $catEmails = $catHash->{$cat};
        $catEmails = ['<none>'] unless ($catEmails and @$catEmails);
        push @catRows, $cgi->Tr ($cgi->td ({-align => 'right'}, $cat),
                                 $cgi->td ({-align => 'center'},
                                           $cgi->scrolling_list
                                           (-name     => "Cat-$cat",
                                            -Values   => $catEmails,
                                            -size     => 5,
                                            -override => 1,
                                            -multiple => 1)),
                                 $cgi->td ({style => 'font-size: smaller;'},
                                   $cgi->a ({-href =>
                                    "javascript:SetAll(true,'Cat-$cat')"},
                                   'Select All') . '<br>' .
                                   $cgi->a ({-href =>
                                    "javascript:SetAll(false,'Cat-$cat')"},
                                   'Clear All'))
                                );
    }

    push @catRows, $cgi->Tr ($cgi->td (['&nbsp;', 'No categories defined']))
        unless @catRows;

    print $cgi->startform;

    print '<blockquote>';
    # allow turning them on/off
    print $cgi->checkbox (-name    => 'RemindersOn',
                          -checked => $remindersOn,
                          -value   => 1,
                          -label   => '');
    print '&nbsp;<b>' . $i18n->get ('Enable Subscriptions') . '</b> (',
          $i18n->get ('if disabled, users will not be able to ' .
                      'sign up for subscriptions.'), ')';
    print '<br><br>';

    my $numDays = $self->prefs->RemindDays || 3;
    my $advanceNotes = $i18n->get ('You can have mail sent any number of ' .
                                   'days in advance. Specify a ' .
                                   'space-separated list of days:');
    print $advanceNotes;
    print $cgi->table
        ($cgi->Tr ($cgi->td ('&nbsp;'),
                   $cgi->td ($cgi->b
                             ($i18n->get ('Days in advance to send mail: '))),
                   $cgi->td ($cgi->textfield (-name    => 'DaysInAdvance',
                                              -default => $numDays,
                                              -override => 1,
                                              -size => 8))));
    print '<small>For instance: ';
    print $cgi->ul ($cgi->li ($i18n->get
            ('To have mail sent 3 days in advance of events, just enter ' .
             '"3".')),
                    $cgi->li ($i18n->get
            ('To have mail sent 7 days in advance, and again 1 day in ' .
             'advance, enter "7 1".')),
                    $cgi->li ($i18n->get
            ('To have mail sent 10 days, 3 days, and 1 day in advance, ' .
             'enter "10 3 1".')));
    print '</small>';

    print $cgi->submit (-name  => 'SaveDays', -value => $i18n->get ('Save'));
    print '<hr width="50%">';

    print '</blockquote>';

    # Email Lists

    my @allEventEmails = sort {lc($a) cmp lc($b)}
                           $self->prefs->getRemindAllAddresses;
    @allEventEmails = ('<none>') unless (@allEventEmails);
    my $allEmails = $cgi->scrolling_list (-name     => 'AllEvents',
                                          -Values   => \@allEventEmails,
                                          -size     => 7,
                                          -override => 1,
                                          -multiple => 'true');

    print $cgi->table ($cgi->Tr ($cgi->td ($cgi->b ($i18n->get (
                                           'Addresses subscribed to All ' .
                                                              'Events:'))),
                                 $cgi->td ($allEmails)),
                       $cgi->Tr ($cgi->td ('&nbsp;'),
                                 $cgi->td ({style => 'font-size: smaller;'},
                                           $cgi->a ({-href =>
                                    "javascript:SetAll(true,'AllEvents')"},
                                   'Select All') . '&nbsp;&nbsp;' .
                                   $cgi->a ({-href =>
                                    "javascript:SetAll(false,'AllEvents')"},
                                   'Clear All'))),
#                       $cgi->Tr ($cgi->td ({-colspan => 3}, '<hr>')),
                       $cgi->Tr ($cgi->td ('&nbsp;')),
                       $cgi->Tr ($cgi->td ($cgi->b ($i18n->get (
                                            'Addresses subscribed by ' .
                                                              'Category:')))),
                       @catRows);

    my $removeAll = $i18n->get ('Remove selected addresses');
    print '<p>';
    print $cgi->submit (-name  => 'RemoveAddresses', -value => $removeAll);
    print '</p>';


    print '<hr>';
    print '&nbsp;';
    print $cgi->submit (-name => 'Done', -value => $i18n->get ('Done'));
    print '&nbsp;';
    print $cgi->reset  (-value => 'Reset');

    print $cgi->hidden (-name => 'Op',           -value => __PACKAGE__);
    print $cgi->hidden (-name => 'CalendarName', -value => $calName)
        if $calName;
    print $self->hiddenDisplaySpecs;

    print $cgi->endform;
    print $cgi->end_html;
}

sub _setAll {
    my $js = q {
        <script language="JavaScript">
        <!--
            function SetAll (setThem, listName) {
               theform=document.forms[0];
               theList = theform.elements[listName];
               for (i=0; i<theList.length; i++) {
                  theList.options[i].selected = setThem;
               }
            }
        //-->
        </script>
               }
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
