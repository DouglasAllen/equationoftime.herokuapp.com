# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# Email subscription/notification options

package OptionSubscribe;
use strict;

use CGI;
use Calendar::GetHTML;
use Calendar::Subscribe;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($save, $cancel, $email, $subType) =
                        $self->getParams (qw (Save Cancel EmailAddress
                                              SubscribeBy));
    my $cgi     = new CGI;
    my @subCats = $cgi->param ('Categories');

    my $i18n    = $self->I18N;
    my $calName = $self->calendarName;

    if ($cancel or !$calName) {
        print $self->redir ($self->makeURL ({Op => 'AdminPageUser'}));
        return;
    }

    print GetHTML->startHTML (title  => $i18n->get ('Email Notification'),
                              class  => 'OptionSubscribe',
                              op     => $self);
    print GetHTML->PageHeader ($i18n->get ('Email Notification'));
    print GetHTML->SectionHeader ($calName);
    print '<br>';

    my $disabled = !$self->prefs->RemindersOn;

    my $message;
    if ($save and !$disabled) {
        $message = $self->_handleSave ($email, $subType, \@subCats);
    } elsif ($disabled) {
        $message = $i18n->get ('Subscriptions are disabled for this calendar;'
                               . ' no changes allowed.');
    }

    print '<center>' . $cgi->h3 ($message) . '</center>' if $message;

    print $cgi->startform (-name => 'SubscribeForm');

    if (!$email) {
        my $user = User->getUser ($self->getUsername); # must re-get from DB
        $email = $user ? $user->email : '';
    }

    # Get current settings if we've got an email address
    my ($radioDefault, @catDefaults);
    if ($email) {
        my $catHash = $self->prefs->getRemindByCategory;
        while (my ($cat, $addrs) = each %$catHash) {
            if (grep {lc ($email) eq lc ($_)} @$addrs) {
                push @catDefaults, $cat;
            }
        }
        if (grep {lc ($email) eq lc ($_)}
                 $self->prefs->getRemindAllAddresses) {
            $radioDefault = 'All';
        } elsif (@catDefaults) {
            $radioDefault = 'ByCategory';
        }
    }

    print '<b>Email Address: </b>';
    print $cgi->textfield (-name      => 'EmailAddress',
                           -default   => $email,
                           -size      => 20,
                           -maxlength => 100);
    print '<br><br><hr width="50%">';

    my $all     = $i18n->get ('<b>Every</b> event in the calendar');
    my $byCat   = $i18n->get ('All events in <b>these categories</b>:');
    my $byEvent = $i18n->get ("Only events I've <b>specifically " .
                              'requested</b>');
    my $nothing = $i18n->get ('<b>None</b> - remove all existing ' .
                              'subscriptions in this calendar for this ' .
                              'email address');

    my @buttons = $cgi->radio_group (-name    => 'SubscribeBy',
                                     -default => $radioDefault || 'ByEvent',
                                     -Values  => ['All',     'ByCategory',
                                                  'ByEvent', 'None'],
                                     -labels  => {'All'        => '',
                                                  'ByCategory' => '',
                                                  'ByEvent'    => '',
                                                  'None'       => ''});

    my @categories = sort {lc ($a) cmp lc ($b)}
                       keys %{$self->prefs->getCategories (1)};
    my $cats = $cgi->scrolling_list (-name   => 'Categories',
                                     -Values => \@categories,
                                     -default => \@catDefaults,
                                     -size   => 5,
                                     -multiple => 'true',
                                     -onChange =>
                                    'this.form.SubscribeBy[1].checked = true');

    print _setAll();

    print '<br>';
    print $cgi->b ($i18n->get ('Subscribe to which events:'));
    print $cgi->table ({cellspacing => 10},
                       $cgi->Tr ($cgi->td ($buttons[0]),
                                 $cgi->td ({-colspan => 2}, $all)),
                       $cgi->Tr ($cgi->td ($buttons[1]),
                                 $cgi->td ($byCat),
                                 $cgi->td ({align => 'center'},
                                            $cats . '<br>' .
                                 $cgi->span ({style => 'font-size: smaller;'},
                                 $cgi->a ({-href => "javascript:SetAll(true)"},
                                              $i18n->get ('Select All'))
                                             . '&nbsp;&nbsp;' .
                                $cgi->a ({-href => "javascript:SetAll(false)"},
                                         $i18n->get ('Clear All'))))),
                       $cgi->Tr ($cgi->td ($buttons[2]),
                                 $cgi->td ({-colspan => 2}, $byEvent)),
                       $cgi->Tr ($cgi->td ($buttons[3]),
                                 $cgi->td ({-colspan => 2}, $nothing)),
                      );


    my @days = sort {$b <=> $a} split (/\s/, $self->prefs->RemindDays || '3');
    my $dayString = $days[0];
    $dayString = reverse join ', ', @days;
    $dayString =~ s/,/dna /;
    $dayString = reverse $dayString;
    if ($dayString eq '1') {
        $dayString .= ' ' . $i18n->get ('day');
    } else {
        $dayString .= ' ' . $i18n->get ('days');
    }
    print '<center><b>';
    print $i18n->get ('Email Notifications for this calendar are sent') . ' ' .
          $dayString . ' ' .
          $i18n->get ('before events are scheduled to occur.');
    print '</b></center>';

    print '<hr>';
    print $cgi->submit (-name  => 'Save',  -value => $i18n->get ('Save'))
        unless $disabled;
    print '&nbsp;';
    print $cgi->submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print $cgi->hidden (-name => 'Op',     -value => __PACKAGE__);
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
            function SetAll (setThem) {
               theform=document.SubscribeForm;
               for (i=0; i<theform.Categories.length; i++) {
                  theform.Categories.options[i].selected = setThem;
               }
               if (setThem) {
                  theform.SubscribeBy[1].checked = true;
               }
            }
        //-->
        </script>
               }
}

sub _handleSave {
    my ($self, $email, $type, $catList) = @_;
    my $i18n = $self->I18N;

    my $error = '<font color="red">' . $self->I18N->get ('Error') . ':</font>';
    return ("$error " . $i18n->get ('You must enter an email address!'))
        unless ($email);

    my $message;

    if ($type eq 'All') {
        my @all = $self->prefs->getRemindAllAddresses;
        return if (grep {lc ($email) eq lc ($_)} @all);
        push @all, $email;
        $self->prefs->setRemindAllAddresses (@all);
        $message = $i18n->get ('will be reminded of all events');
        $message = "$email $message";
    }
    elsif ($type eq 'ByCategory') {
        # First, remove from "All" in case it's there
        Subscribe::removeFromAll ($self->prefs, $email);

        # for each category, add/remove email address depending on what is
        #  selected.

        # Remove from any not selected
        Subscribe::removeFromCategory ($self->prefs, [$email], $catList);

        my $catHash = $self->prefs->getRemindByCategory;

        # Add to any that are selected
        foreach my $cat (@$catList) {
            my $addrs = $catHash->{$cat} || [];
            next if (grep {lc ($email) eq lc ($_)} @$addrs);
            push @$addrs, $email;
            $catHash->{$cat} = $addrs;
        }
        $self->prefs->setRemindByCategory ($catHash);

        $message = $i18n->get
                          ('will be reminded of events in these categories');
        $message = "$email $message: ";
        $message .= '<br>';
        $message .= join ', ', @$catList;
    }
    elsif ($type eq 'ByEvent') {
        Subscribe::removeFromAll ($self->prefs, $email);
        Subscribe::removeFromCategory ($self->prefs, [$email]);
        $message = $i18n->get ('will be reminded only for requested events');
        $message = "$email $message";
    }
    elsif ($type eq 'None') {
        Subscribe::removeCompletely ($self->db, $self->prefs, $email);
        $message = $i18n->get ('will receive no email reminders');
        $message = "$email $message";
    }
    else {
        return "$error " . $i18n->get ('Bad option; try again.');
    }

    $self->{audit_formsaved}++;
    $self->{audit_address} = $email;
    $self->{audit_type}    = $type;
    $self->{audit_catList} = $catList;

    $self->db->setPreferences ($self->prefs);
    return $message;
}

# Override the 'View' default
sub auditType {
    return 'Subscribe';
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);
    my $email = $self->{audit_address} || '';
    my $type  = $self->{audit_type}    || '';
    my $cats  = $self->{audit_catList} || [];
    if ($short) {
        my $clist = join ', ', @$cats;
        return $line . " $email, $type" . $clist || '';
    }

    my $text = "Email: $email\nType:  $type\n";
    if ($type =~ /category/i) {
        my $clist = join ', ', @$cats;
        $text .= "Categories: $clist\n";
    }
    return "$text\n$line";
}

1;
