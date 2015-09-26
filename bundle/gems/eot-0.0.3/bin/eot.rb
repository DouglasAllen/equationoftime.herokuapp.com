#! /usr/bin/env ruby

module Cmd

  def self.get_lat_arg
    ARGV[0]
  end

  def self.get_lng_arg
    ARGV[1]
  end

  def self.get_date_arg
    ARGV[2].to_s
  end

  def self.parse_argv
    usage = "eot +-your latitude as float +-your longitude as float a date as yyyy-mm-nn"
    date_arg = self.get_date_arg.split("-").map {|ae| ae.to_i}
    lat_arg = self.get_lat_arg.to_f unless get_lat_arg.nil?
    lng_arg = self.get_lng_arg.to_f unless get_lng_arg.nil?
    begin
      Date.valid_date?(date_arg[0], date_arg[1],date_arg[2])
      date_new = Date.new date_arg[0], date_arg[1],date_arg[2]
      {date: date_new, lat: lat_arg, lng: lng_arg, usage: "ok"}
    rescue
      date_new = DateTime.now.to_time.utc.to_datetime
      {date: date_new, lat: 0.0, lng: 0.0, usage: usage}
    end
  end
end

require 'eot'
eot = Eot.new
if Cmd.parse_argv.fetch(:usage) == "ok"
  eot.date = Cmd.parse_argv.fetch(:date)
  eot.latitude = Cmd.parse_argv.fetch(:lat)
  eot.longitude = Cmd.parse_argv.fetch(:lng)
  eot.ajd = eot.date.jd
  eot.ma_ta_set
  puts "Sunrise = #{eot.sunrise_dt} at lat. #{eot.latitude}, lng. #{eot.longitude} "
  puts "Sunset = #{eot.sunset_dt} at lat. #{eot.latitude}, lng. #{eot.longitude}"
else
  p Cmd.parse_argv.fetch(:usage)
end

if __FILE__ == $PROGRAM_NAME
  Cmd.parse_argv
  #~ require 'eot'
  #~ eot = Eot.new
  #~ ARGV[0] = 0
  #~ ARGV[1] = 0
  #~ ARGV[2] = "2015-04-08"
  #~ eot.date = Cmd.parse_argv.fetch(:date)
  #~ p eot.date = Cmd.parse_argv.fetch(:date)
  #~ p eot.latitude = Cmd.parse_argv.fetch(:lat)
  #~ p eot.longitude = Cmd.parse_argv.fetch(:lng)
  #~ p eot.ajd = eot.date.jd
  #~ eot.ma_ta_set
  #~ puts "Sunrise = #{eot.sunrise_dt} at lat. #{eot.latitude}, lng. #{eot.longitude} "
  #~ puts "Sunset = #{eot.sunset_dt} at lat. #{eot.latitude}, lng. #{eot.longitude}"
end
