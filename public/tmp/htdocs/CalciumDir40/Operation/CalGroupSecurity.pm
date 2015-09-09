# Copyright 2006-2006, Fred Steinberg, Brown Bear Software

# Set Calendar Group permissions for Users Groups

package CalGroupSecurity;
use strict;

use CGI (':standard');
use Calendar::GetHTML;
use Calendar::UserGroup;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

# Allowed if have perm in *all* calendars in specified group
sub authenticate {
    my $self = shift;
    my $user  = $self->getUser;
    my $group = $self->groupName;
#    return undef if (!defined $group);
    my $cals_in_group = $self->relevantCalendars;
    foreach my $cal_name (@$cals_in_group) {
        my $db   = Database->new ($cal_name);
        my $perm = Permissions->new ($db);
        $self->{_db_cache}  {$cal_name} = $db;
        $self->{_perm_cache}{$cal_name} = $perm;
        return undef unless $perm->permitted ($user, $self->{AuthLevel});
    }
    return 1;
}

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($save, $cancel) = $self->getParams (qw (Save Cancel));

    # if no calendar group, go home.
    if (!$self->isMultiCal) {
        print $self->redir ($self->makeURL ({Op    => 'Splash'}));
        return;
    }

    # if we've been cancel'ed, go back
    if ($cancel) {
        print $self->redir ($self->makeURL ({Op    => 'AdminPage',
                                             Group => $self->groupName}));
        return;
    }

    # Save everything away
    if ($save) {
        $self->_handle_save;
    }

    my @userGroups = UserGroup->getAll;

    my $message;

    print GetHTML->startHTML (title =>
                                  $i18n->get ('Permissions for User Groups'),
                              op    => $self);
    print GetHTML->AdminHeader (I18N    => $i18n,
                                goob    => $self->goobLabel  || '',
                                group   => $self->groupName  || '',
                                section => 'Permissions for User Groups');


    my $instructions = $i18n->get ('CalGroupSecurity_HelpString');
    if ($instructions eq 'CalGroupSecurity_HelpString') {
        ($instructions =<<"        FNORD") =~ s/^ +//gm;
            Use this page to set permissions for groups of
            users in a group of calendars.
        FNORD
    }
    print table ({width => '90%', align => 'center'}, Tr (td ($instructions)));

    print '<center>';
    print "<p>$message</p>" if $message;
    print '<br/>';

    my $masterPerm = Permissions->new (MasterDB->new);
    my @permValues = (qw (None View Add Edit Admin));
    my %permLabels = (None  => $i18n->get ('No Access'),
                      View  => $i18n->get ('View Only'),
                      Add   => $i18n->get ('Add Events'),
                      Edit  => $i18n->get ('Edit Events'),
                      Admin => $i18n->get ('Administer'));

    my @rows = ();
    my $calgroup_perms = MasterDB->get_cal_group_perms ($self->groupName);
    my ($thisRow, $thatRow) = ('thisRow', 'thatRow');
    foreach my $user_group (map  {$_->[0]}
             sort {lc($a->[1]) cmp lc($b->[1])}
             map  {[$_, $_->name]} @userGroups) { # sort by name
        my $ugroup_id = $user_group->id;
        my $perm = $calgroup_perms->{$ugroup_id} || 'None';
        $perm = 'Admin' if $masterPerm->groupPermitted ($user_group, 'Admin');
        my @radios = radio_group (-name     => "GroupRadio-$ugroup_id",
                                  -values   => \@permValues,
                                  -labels   => \%permLabels,
                                  -override => 1,
                                  -default  => "\u$perm");
        my $name  = $user_group->name;
        my $label = $name;
        if ($masterPerm->groupPermitted ($user_group, 'Admin')) {
            $label = qq (<span class="highlight">$name</span>);
        }
        ($thisRow, $thatRow) = ($thatRow, $thisRow);
            push @rows, Tr ({-class => $thisRow},
                            td ($label),
                            td ({-align => 'center'},
                                table (Tr (td ({-class    => 'PermLabels'},
                                               [@radios])))));
    }
    my $table = table ({-class       => 'alternatingTable',
                        -border      => 0,
                        -cellspacing => 0,
                        -cellpadding => 0},
                       Tr (
                       th ({-class => 'headerRow'},
                           ['<u>' . $i18n->get ('User Group Name')  . '</u>',
                            '<u>' . $i18n->get ('Permission Level') . '</u>'])),
                       @rows);

    print startform;
    print $table;

    print '<hr/>';
    print submit (-name  => 'Save',
                  -value => $i18n->get ('Set Permissions')); print '&nbsp;';
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Done'));
    print $self->hiddenParams;
    print endform;
    print '</center>';
    print end_html;
}

# Save pressed; save the new settings
sub _handle_save {
    my $self = shift;
    $self->{audit_formsaved}++;
    $self->{audit_orig} = MasterDB->get_cal_group_perms ($self->groupName);

    my @userGroups = UserGroup->getAll;
    my %settings_by_ugroup;
    foreach my $user_group (@userGroups) {
        my $user_group_id = $user_group->id;
        my $level = param ("GroupRadio-$user_group_id") || 'None';
        next if (lc $level eq 'none');
        $settings_by_ugroup{$user_group_id} = $level;
    }

    MasterDB->set_cal_group_perms ($self->groupName, \%settings_by_ugroup);
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    my $old_perms = $self->{audit_orig};
    my $new_perms = MasterDB->get_cal_group_perms ($self->groupName);

    my %ugroups = map {$_ => 1} (keys %$old_perms, keys %$new_perms);

    my $info;
    foreach my $group (sort keys %ugroups) {
        my $old = $old_perms->{$group} || 'none';
        my $new = $new_perms->{$group} || 'none';
        next if ($old eq $new);
        $info .= " [$_: $old -> $new]";
    }

    return unless $info;     # don't report if nothing changed
    return $line . $info;
}

1;
