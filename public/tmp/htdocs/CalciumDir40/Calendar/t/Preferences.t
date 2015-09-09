#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 50;
use lib '../../../../CalciumDir311';
use lib '../..';
use Calendar::Preferences;
use Calendar::MasterDB;
use Calendar::CustomField;

# Constructor, accessors
my $obj = Preferences->new;
ok ($obj && $obj->isa ('Preferences'), 'simple new()');

ok ($obj->get_custom_fields (system => undef),
    'get_custom_fields returns something');

my $field = CustomField->new (id         => 33,
                              name       => 'test',
                              input_type => 'textfield',
                              default    => 'hello',
                              required   => 1,
                              label      => 'Hello Label: ');

$obj->set_custom_field ($field);

my $fields_lr = $obj->get_custom_fields (system => undef);
my ($retrieved) = grep {$_->name eq $field->name} @$fields_lr;
ok ($field->sameAs ($retrieved), "set/get sameAs field");

my $field2 = CustomField->new (id         => 44,
                               name       => 'another test',
                               input_type => 'checkbox',
                               default    => undef,
                               required   => 1,
                               label      => 'CBox Label: ');
ok (!$field2->sameAs ($field), "different fields !sameAs");

