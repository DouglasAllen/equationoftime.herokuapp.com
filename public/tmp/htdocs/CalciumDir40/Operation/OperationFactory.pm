# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package OperationFactory;
use strict;

use Calendar::Defines;
use Operation::Operation;

my %Operations = (AddEvent            => 'Add',
                  AddEventExternal    => 'None',
                  AdminAddIns         => 'Admin',
                  AdminAddInsAdmin    => 'Admin',
                  AdminAuditing       => 'Admin',
                  AdminCategories     => 'Admin',
                  AdminColors         => 'Admin',
                  AdminColorsAlternate => 'Admin',
                  AdminCSS            => 'Admin',
                  AdminCustomFields   => 'Admin',
                  AdminDeleteEvents   => 'Admin',
                  AdminDisplay        => 'Admin',
                  AdminEditForm       => 'Admin',
                  AdminExport         => 'View',
                  AdminFonts          => 'Admin',
                  AdminGeneral        => 'Admin',
                  AdminHeader         => 'Admin',
                  AdminImport         => 'Add',
                  AdminInclude        => 'Admin',
                  AdminMail           => 'Admin',
                  AdminPage           => 'Admin',
                  AdminPageUser       => 'View',
                  AdminRSS            => 'Admin',
                  AdminSecurity       => 'Admin',
                  AdminSubscriptions  => 'Admin',
                  AdminTemplates      => 'Admin',
                  AdminTimePeriods    => 'Admin',
                  ApproveEvents       => 'Edit',
                  CalGroupSecurity    => 'Admin',
                  CreateCalendar      => 'Admin',
                  ColorPalette        => 'None',
                  DayView             => 'View',
                  DeleteCalendar      => 'Admin',
                  EmailSelector       => 'Add',
                  EditEvent           => 'Edit',
                  EventEditDelete     => 'Edit',
                  EventFilter         => 'View',
                  EventNew            => 'Add',
                  EventReplace        => 'Edit',
                  FreeTimeSearch      => 'View',
                  iCalSubscribe       => 'View',
                  MiniCal             => 'View',
                  OptionSubscribe     => 'View',
                  OptioniCal          => 'View',
                  PopupCal            => 'None',
                  PopupWindow         => 'View',
                  PrintView           => 'View',
                  RenameCalendar      => 'Admin',
                  RSS                 => 'View',
                  SearchForm          => 'View',
                  SearchPerform       => 'View',
                  SelectCalendar      => 'None',
                  ShowDay             => 'View',
                  ShowIt              => 'View',
                  ShowMultiAddEvent   => 'None', # perms checked in there
                  Splash              => 'None',
                  SysAdminPage        => 'Admin',
                  SysGroups           => 'Admin',
                  SysGroupAdmin       => 'Admin',
                  SysLDAP             => 'Admin',
                  SysMail             => 'Admin',
                  SysMailReminder     => 'Admin',
                  SysMaintenance      => 'Admin',
                  SysSecurity         => 'Admin',
                  SysSettings         => 'Admin',
                  SysUserGroups       => 'Admin',
                  SysUserGroupAdmin   => 'Admin',
                  SysUsers            => 'Admin',
                  SysUserSecurity     => 'Admin',
                  TextFilter          => 'View',
                  TripleSync          => 'None', # perms checked in there
                  UserLogin           => 'None',
                  UserLogout          => 'None',
                  UserOptions         => 'None',
                  vCalEventExport     => 'View'
                 );

# Create a new Operation, not a new OperationFactory
sub create {
    my $factoryClassName = shift;
    my ($className, $paramHash, $user) = @_;
    $className =~ /^(\w+)$/;    # untaint
    $className = $1;            #         it
    my $type = $Operations{$className};
    die "Unknown operation: '$className'\n" unless $type;
    eval "require Operation::$className";
    die ("Couldn't read/parse file 'Operation/$className.pm' " .
         "(or another file it uses)\n") if $@;
    my $newObject = $className->new ($paramHash, $type, $user);
    $newObject;
}

sub getOpType {
    my $classname = shift;
    my $opName = shift;
    die "Bad Operation '$opName' to getOpType()\n" unless $Operations{$opName};
    return $Operations{$opName};
}

1;
