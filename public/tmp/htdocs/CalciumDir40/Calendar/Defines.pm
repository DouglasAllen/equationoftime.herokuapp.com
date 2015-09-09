# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# A convenient place to store installation dependent things

package Defines;

use strict;
use vars qw ($version
             $license
             $calendar_root
             $maxCalendars
             $database_type);

BEGIN {
    $version           = '4.0.4';
    $license           = 'Demo';
    $maxCalendars      = 1;            # Do you really want to change this?
                                       # Perhaps you should upgrade your
                                       # license.
    $database_type     = 'Serialize';
}

# Return path to the base of the calendar tree
sub baseDirectory {
    my $classname = shift;
    return $calendar_root;
}

sub databaseType {
    my $classname = shift;
    return $database_type;
}

sub version {
    my $classname = shift;
    return $version;
}

sub has_feature {
    my ($class, $feature_name) = @_;
    return unless $feature_name;
    return $license =~ /$feature_name/i;
}

sub mailEnabled {
    my $classname = shift;
    return $license =~ /mail/i;
}

sub multiCals {
    my $classname = shift;
    return $license =~ /Pro/;
}

sub license {
    my $classname = shift;
    return $license;
}

sub maxCalendars {
    my $classname = shift;
    return $maxCalendars || 1;
}

sub isDemo {
    return $license =~ /Demo/i;
}

1;
