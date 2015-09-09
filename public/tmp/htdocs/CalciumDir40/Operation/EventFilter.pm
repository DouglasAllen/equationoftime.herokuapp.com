# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Event Filter Window

package EventFilter;
use strict;
use CGI;

use Calendar::GetHTML;
use Calendar::Javascript;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($cancel, $isPopup) = $self->getParams (qw /Cancel IsPopup/);

    if ($cancel) {
        print $self->redir ($self->makeURL ({Op => 'AdminPageUser'}));
        return;
    }

    my $calName = $self->calendarName;
    my $prefs   = $self->prefs;
    my $i18n    = $self->I18N;

    my $cgi = new CGI;

    my (%included, $cookie);
    my $includes = $prefs->getIncludedCalendarInfo ('all');

    # If not submitted, get the excluded cals from the cookie.
    unless ($self->{params}->{DoIt}) {
        map {$included{$_}++} keys %$includes;

        my $incOnly = $self->getParams ('IncludeOnly');
        if ($incOnly) {
            my @calNames = split /-/, $incOnly;
            my %onlyThese = map {$_ => 1} @calNames;
            foreach (keys %included) {
                delete $included{$_} if !exists $onlyThese{$_};
            }
        } else {
            my $excluded = $cgi->cookie ("EventFilter-$calName") || '';
            foreach (split ',', $excluded) {
                delete $included{$_};
            }
        }
    } else {
        # OK, we expect a list of calendar name values specified as params
        # with keys 'Quick0', 'Quick1', etc. Those values are the cals we
        # want to include.
        foreach (keys %{$self->{params}}) {
            next unless /^Quick[\d]+/;
            my $name = $self->{params}->{$_};
            $included{$name}++; # e.g. $included{MyCal}++
        }

        # Get a hash of only the calendars we *don't* want;
        my %excluded;
        foreach (keys %$includes) {
            $excluded{$_}++ unless $included{$_};
        }
        $cookie = $cgi->cookie (-name  => "EventFilter-$calName",
                                -Value => join ',', keys %excluded);

        $self->{audit_formsaved}++;
        my @cals = keys %included;
        $self->{audit_included} = \@cals;

    }

    # Then redisplay the form, setting the cookie
    my %headHash = (cookie => $cookie);
    if ($cookie and !$isPopup) {
        my $url = $self->makeURL ({Op => 'ShowIt'});
        $headHash{Refresh} = "0; URL=$url" unless $isPopup;
    }

    print GetHTML->startHTML (title  => $i18n->get ('Included Event Filter'),
                              op     => $self,
                              %headHash);
    print '<center>';
    print GetHTML->PageHeader ($i18n->get ('Included Event Filter'));
    print GetHTML->SectionHeader ($calName);
    print '<br>';
    print $cgi->startform;

    # Display all availble for inclusion
    my %displayNames;
    foreach (keys %$includes) {
        ($displayNames{$_} = $_) =~ s/^ADDIN //;
    }

    # Add Ins come last
    sub _sort {
        my ($a, $b) = (@_);
        return -1 if ($a !~ /^ADDIN/ and $b =~ /^ADDIN/);
        return  1 if ($a =~ /^ADDIN/ and $b !~ /^ADDIN/);
        return lc($a) cmp lc($b);
    }

    if (keys %$includes) {
        my $bg = $prefs->color ('EventBG');
        my $fg = $prefs->color ('EventFG');
        my $i=0;
        print $cgi->table ({-border => 1, -cellpadding => 3,
                            -bgcolor => '#bbbbbb'},
                           $cgi->th ({-class => 'SectionHeader'},
                                     [$i18n->get ('Event Source'),
                                      $i18n->get ('Display?')]),
                           map {$cgi->Tr
                                    ($cgi->td ({-bgcolor =>
                                            ($includes->{$_}->{'BG'} || $bg)},
                                               '<font color=' .
                                            ($includes->{$_}->{'FG'} || $fg)
                                               . '>' . $displayNames{$_}),
                                     $cgi->td ({-align => 'center'},
                                               $cgi->checkbox (
                                                  -checked => $included{$_},
                                                  -name    => 'Quick' . $i++,
                                                  -value   => $_,
                                                  -label   => '')))
                                } (sort {_sort ($a, $b)} keys %$includes));

        print q {
            <script language="JavaScript">
            <!--
                function SetAll (setThem) {
                   theform=document.forms[0];
                   for (i=0; i<theform.elements.length; i++) {
                       if (theform.elements[i].type=='checkbox') {
                           theform.elements[i].checked=setThem;
                       }
                   }
                }
            //-->
            </script>
                };
        print '<small>';
        print $cgi->a ({-href => "javascript:SetAll(true)"},
                       $i18n->get ('Set All'));
        print '&nbsp;&nbsp;&nbsp;';
        print $cgi->a ({-href => "javascript:SetAll(false)"},
                       $i18n->get ('Clear All'));
        print '</small>';
    } else {
        print $i18n->get ('This calendar has no Included Calendars ' .
                          'or Add-Ins.');
    }

    print '<br><hr width="80%">';

    my $doIt;
    if (%$includes) {
        $doIt = $cgi->submit (-name  => 'DoIt',
                              -Value => $i18n->get ('Filter Now'));
        print $doIt . '&nbsp;';
    }

    print $cgi->submit (-name  => 'Cancel',
                        -value => $i18n->get ('Done'));

    print '&nbsp;&nbsp;&nbsp;';
    print $cgi->reset (-name => $i18n->get ('Reset'));

    print '</center>';

    print $cgi->hidden (-name  => 'Op',           -value => 'EventFilter');
    print $cgi->hidden (-name  => 'CalendarName', -value => $calName);
    print $self->hiddenDisplaySpecs;

    print $cgi->endform;

    # only need to redisplay if we've set a cookie here
    if ($cookie and $isPopup) {
        my $link = $self->makeURL ({Op      => 'ShowIt',
                                    IsPopup => undef});
        print Javascript->SetLocation;
        print "\n<script language=\"JavaScript\"><!-- \n";
        print "SetLocation (self.opener, '$link')";
        print "\n// --></script>\n";
    }

    print $cgi->end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line =  $self->SUPER::auditString ($short);
    $line .= ' ' . join ' ', @{$self->{audit_included}};
}

1;
