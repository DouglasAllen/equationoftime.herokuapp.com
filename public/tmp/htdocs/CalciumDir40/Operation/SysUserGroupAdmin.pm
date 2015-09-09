# Copyright 2000-2006, Fred Steinberg, Brown Bear Software

# View/Set Users in a group

package SysUserGroupAdmin;
use strict;
use CGI (':standard');
use Calendar::User;
use Calendar::UserGroup;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($groupID, $groupName, $userName, $save, $cancel) =
                 $self->getParams (qw (GroupID GroupName UserName
                                       Save Cancel));
    my $i18n  = $self->I18N;
    my $prefs = $self->prefs;

    # If both specified, decide based on button pressed to get here
    if (defined $userName and defined $groupName) {
        undef $userName  if param ('ByGroup');
        undef $groupName if param ('ByUser');
    }

    my $theUser;
    if (defined $userName) {
        $theUser = User->getUser ($userName);
    }

    if (!$theUser and defined $groupName) {
        # lookup ID for group name
        my $group = UserGroup->getByName ($groupName);
        $groupID = $group->id if ($group);
    }

    if ($cancel or $self->calendarName or (!$groupID and !$theUser)) {
        print $self->redir ($self->makeURL ({Op => 'SysUserGroups'}));
        return;
    }

    if (defined $groupID) {
        my $theGroup = UserGroup->getGroup ($groupID);
        $groupName = $theGroup->name;
    }

    my %allUsers = map {$_->name => $_} User->getUsers;
    my @allUserNames = sort {lc ($a) cmp lc ($b)} User->getUserNames;

    if ($save) {
        $self->{audit_formsaved}++;
        my $items_in_list = param ('InGroupListMembers');
        my @selectedItems = split ';', $items_in_list;
        my %selected = map {$_ => 1} @selectedItems;

        # If modifying users for a group:
        #   modify each user, if their membership for this group changed
        if ($groupID) {
            foreach my $name (@allUserNames) {
                my $user = $allUsers{$name};
                # If user doesn't exist, create it; could happen for LDAP
                $user ||= User->create (name => $name);

                my @groups = $user->groupIDs;
                my $inGroup = grep {$groupID == $_} @groups;
                if ($selected{$name} and !$inGroup) {
                    $user->addToGroup ($groupID);
                }
                elsif (!$selected{$name} and $inGroup) {
                    $user->removeFromGroup ($groupID);
                }
            }
        }

        # If modifying groups for a user:
        if ($theUser) {
            my @allGroups = UserGroup->getAll;
            my %nameToID = map {$_->name => $_->id} @allGroups;
            my @groupIDs = map {$nameToID{$_}} @selectedItems;
            $theUser->setGroups (@groupIDs);
        }

        %allUsers = map {$_->name => $_} User->getUsers;
    }

    my $title;
    my (@in_group, @not_in_group);
    my ($head, $in_title, $not_in_title, $add_label, $remove_label);

    if ($theUser) {
        $title   = 'Groups for a User';
        $head    = $i18n->get ('User') . ": $userName";
        $in_title     = $i18n->get ('Groups this user is in');
        $not_in_title = $i18n->get ('Groups this user is NOT in');
        $add_label    = $i18n->get ('<-- Add Group');
        $remove_label = $i18n->get ('Remove Group -->');
        my @allGroups = UserGroup->getAll;
        my %idToName = map {$_->id => $_->name} @allGroups;
        my @users_groups = $theUser->groupIDs;
        foreach my $group (@allGroups) {
            if (grep {$_ == $group->id} @users_groups) {
                push @in_group, $group->name;
            }
            else {
                push @not_in_group, $group->name;
            }
        }
    } else {
        $title   = 'User Group Members';
        $head    = $i18n->get ('Group') . ": $groupName";
        $in_title     = $i18n->get ('Users in the Group');
        $not_in_title = $i18n->get ('Users NOT in the Group');
        $add_label    = $i18n->get ('<-- Add User to Group');
        $remove_label = $i18n->get ('Remove from Group -->');
        # Get users in this group
        foreach my $user_name (@allUserNames) {
            my $user = $allUsers{$user_name};
            my @ids = $user ? $user->groupIDs : ();
            if (grep {$_ == $groupID} @ids) {
                push @in_group, $user_name;
            }
            else {
                push @not_in_group, $user_name;
            }
        }
    }

    # And display (or re-display) the form
    print GetHTML->startHTML (title => $i18n->get ($title));
    print GetHTML->SysAdminHeader ($i18n, $title, 1);

    print _list_finagler_js();

    print startform;

    print '<center>';
    print h2 ($head);

    # Two lists; one of all users, another of those presently in the group.
    # (Or, all groups, groups for this user.)
    print table (Tr (th ({-align => 'center'},
                         [$in_title, '&nbsp;', $not_in_title])),
                 Tr ({-align => 'center'},
                     td (scrolling_list (-name     => "InThisGroup",
                                         -id       => 'InGroupList',
                          -Values   => [sort {lc $a cmp lc $b} @in_group],
                          -size     => 10,
                          -multiple => 'true')),
                     td ({align => 'center'},
                         submit (-value   => $add_label,
                                 -onClick => 'add_to_group();return false;')
                         . '<br/><br/>' .
                         submit (-value   => $remove_label,
                             -onClick => 'remove_from_group(); return false;')),
                     td (scrolling_list (-name     => 'NotInGroup',
                                         -id       => 'NotInGroupList',
                          -Values   => [sort {lc $a cmp lc $b} @not_in_group],
                          -size     => 10,
                          -multiple => 'true'))));

    my $in_group_field = join ';', @in_group;
    print hidden (-name  => 'InGroupListMembers',
                  -id    => 'InGroupListMembers',
                  -value => $in_group_field);

    print '<br/>';
    print '</center>';

    print '<hr>';
    print submit (-name    => 'Save',
                  -onclick => 'set_in_group_param()',
                  -value   => $i18n->get ('Save'));
    print '&nbsp;';
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Done'));
    print '&nbsp;';
    print hidden (-name => 'Op',       -value => __PACKAGE__);
    print hidden (-name => 'GroupID',  -value => $groupID)
        if (defined $groupID);
    print hidden (-name => 'UserName', -value => $userName)
        if (defined $userName);

    print endform;

    my (@help_strings, %help);
    $help{general} = <<HELP_STRING;
        Select one or more items in either list, then press the "Add"
        or "Remove" button to move them. Be sure to press the
        "Save" button to save your changes.
HELP_STRING

    $help{multiple} = <<HELP_STRING;
        You can select/move multiple items at once; try control-clicking or
        shift-clicking on list items.
HELP_STRING

    foreach my $name (qw /general multiple/) {
        my $string_name = "SysUserGroupAdmin_HelpString_$name";
        my $string = $i18n->get ($string_name);
        if ($string eq $string_name) {
            $string = $help{$name};
        }
        push @help_strings, $string;
    }

    print '<br/><br/><div class="AdminNotes">';
    print span ({-class => 'AdminNotesHeader'},
                 $i18n->get ('Notes') . ':');
    print ul (li (\@help_strings));
    print '</div>';

    print end_html;
}

sub _list_finagler_js {
    return <<END_JS;
<script type="text/javascript"><!--
function add_to_group () {
  var in_list     = document.getElementById ('InGroupList');
  var not_in_list = document.getElementById ('NotInGroupList');
  move_list_item (not_in_list, in_list);
}
function remove_from_group () {
  var in_list     = document.getElementById ('InGroupList');
  var not_in_list = document.getElementById ('NotInGroupList');
  move_list_item (in_list, not_in_list);
}
function move_list_item (from_list, to_list) {
  var selected_items = new Array;
  for (var i=0; i<from_list.length; i++) {
    if (from_list[i].selected) {
      selected_items.push (i);
    }
  }
  for (var i=selected_items.length-1; i>=0; i--) {
     var old_opt = from_list[selected_items[i]];
     var new_opt = new Option (old_opt.value,old_opt.value);
     to_list.options[to_list.length] = new_opt;
     from_list[selected_items[i]] = null;
//breaks IE     to_list.options[to_list.length] = from_list[selected_items[i]];
  }
  var sort_array = new Array;
  for (var i=0; i<to_list.length; i++) {
    sort_array[i] = to_list[i].text;
  }
  sort_array.sort();
  for (var i=0; i<to_list.length; i++) {
    to_list[i] = new Option (sort_array[i], sort_array[i]);
  }
}
function set_in_group_param () {
  var in_list         = document.getElementById ('InGroupList');
  var in_list_members = document.getElementById ('InGroupListMembers');
  var member_string = '';
  for (var i=0; i<in_list.length; i++) {
    member_string += in_list[i].value + ';';
  }
  in_list_members.value = member_string;
}
// --></script>
END_JS
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
    my $summary =  $self->SUPER::auditString ($short);
}

1;
