# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Select email addresses for setting form in another window

package EmailSelector;
use strict;
use CGI;

use Calendar::MasterDB;
use Calendar::User;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n  = $self->I18N;
    my $prefs = $self->prefs;
    my $cgi   = new CGI;

    print GetHTML->startHTML (title  => $i18n->get ('Select Email Addresses'),
                              op     => $self);

    print <<END_SCRIPT;
<script language="Javascript">
<!-- start
    function appendTo (item) {
        var aliasesObj = window.document.forms[0].Aliases;
        var userObj    = window.document.forms[0].UserAddresses;
        var aliases = new Array();
        var users   = new Array();
        if (aliasesObj) {
            for (var i=0; i<aliasesObj.length; i++) {
                if (aliasesObj.options[i].selected) {
                    aliases.push (aliasesObj.options[i].value);
                }
            }
        }
        if (userObj) {
            for (var i=0; i<userObj.length; i++) {
                if (userObj.options[i].selected) {
                    users.push (userObj.options[i].value);
                }
            }
        }
        var cur = window.opener.document.forms["EventEditForm"].elements[item];
        var fieldValues = cur.value.split (/[, ]/)
        var all = aliases.concat(users).concat (fieldValues);
        all.sort();

        // eliminate dupes
        var last = '';
        var uniques = new Array();
        for (var i=0; i<all.length; i++) {
            if (all[i] != last) {
                uniques.push (all[i]);
                last = all[i];
            }
        }
        window.opener.document.forms["EventEditForm"].elements[item].value =
            uniques.join (",");
    }

    function SetAll (on, item) {
        var theList = window.document.forms[0].elements[item];
        for (var i=0; i<theList.length; i++) {
            theList.options[i].selected = on;
        }
    }
 -->
</script>
END_SCRIPT

    my $which = $prefs->EmailSelector || 'all';
                    # one of 'none', 'all', 'aliases', 'users'

    my (@headers, @lists, @jsLinks);

    # (maybe) Get all email aliases
    if ($which =~ /all|aliases/i) {
        my @aliases = MasterDB->new->getPreferences->getMailAliasNames;
        @aliases = sort {lc ($a) cmp lc ($b)} @aliases;

        push @headers, $i18n->get ('Email Aliases');
        push @lists, $cgi->scrolling_list (-name     => 'Aliases',
                                           -Values   => \@aliases,
                                           -size     => 8,
                                           -multiple => 'true');
        push @jsLinks, ($cgi->a ({-href => "Javascript:SetAll(1,'Aliases')"},
                                 $cgi->font ({-size => -2},
                                             $i18n->get ('Select All'))) .
                        '&nbsp;&nbsp;' .
                        $cgi->a ({-href => "Javascript:SetAll(0, 'Aliases')"},
                                 $cgi->font ({-size => -2},
                                             $i18n->get ('Clear All'))));

    }

    # (maybe) Get map of all users --> email address
    if ($which =~ /all|users/) {
        my (%nameToMailMap, %mailToNameMap);
        foreach (User->getUsers) {
            next unless $_->email;
            $nameToMailMap{$_->name}  = $_->email;
            $mailToNameMap{$_->email} = $_->name;
        }
        my @userEmails = map {$nameToMailMap{$_}}
                             sort {lc ($a) cmp lc ($b)} keys %nameToMailMap;

        push @headers, $i18n->get ('Users');
        push @lists, $cgi->scrolling_list (-name     => 'UserAddresses',
                                           -Values   => \@userEmails,
                                           -labels   => \%mailToNameMap,
                                           -size     => 8,
                                           -multiple => 'true');
        push @jsLinks, ($cgi->a ({-href =>
                                     "Javascript:SetAll(1, 'UserAddresses')"},
                                 $cgi->font ({-size => -2},
                                             $i18n->get ('Select All'))) .
                        '&nbsp;&nbsp;' .
                        $cgi->a ({-href =>
                                     "Javascript:SetAll(0, 'UserAddresses')"},
                                 $cgi->font ({-size => -2},
                                             $i18n->get ('Clear All'))));
    }

    print $cgi->startform;
    print $cgi->table ({-align       => 'center',
                        -cellspacing => 5},
                       $cgi->Tr ($cgi->th (\@headers)),
                       $cgi->Tr ({align => 'center'}, $cgi->td (\@lists)),
                       $cgi->Tr ({align => 'center'}, $cgi->td (\@jsLinks)));

    print '<br>';
    print '<div align="center">';

    if ($which =~ /none/) {
        print $i18n->get ('Email address selection is disabled for this ' .
                          'calendar.');
    } else {
        print $i18n->get ('Add selected address to:') . '<br>';
        print $cgi->button (-value   => '"To"',
                            -onClick => "appendTo ('MailTo')");
        print '&nbsp;';
        print $cgi->button (-value   => '"CC"',
                            -onClick => "appendTo ('MailCC')");
        print '&nbsp;';
        print $cgi->button (-value   => '"BCC"',
                            -onClick => "appendTo ('MailBCC')");
        if (Defines->mailEnabled) {
            print '&nbsp;';
            print $cgi->button (-value   => '"Reminders"',
                                -onClick => "appendTo ('ReminderAddress')");
        }
    }

    print '<br><br>';
    print $cgi->button (-value   => 'Close Window',
                        -onClick => 'window.close()');
    print '</div>';
    print $cgi->endform;
    print $cgi->end_html;
}

sub auditString {
    return undef;      # don't bother auditing these
}


1;
