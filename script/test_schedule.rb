$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rubygems'
require 'active_support/all'
require './lib/rrschedule.rb'
include RRSchedule

schedule1 = RRSchedule::Schedule.new(
              :teams => %w(T1 T2 T3 T4 T5 T6 T7 T8 T9 T10 T11 T12 T13 T14 T15 T16 T17 T18 T19 T20 T21 T22 T23 T24 T25 T26),
              :rules => [
                RRSchedule::Rule.new(
                  :wday => 3,
                  :gt => ["7:00 PM","9:00 PM"],
                  :ps => ["1","2","3","4","5","6"],
                )
              ],
              :shuffle => true,
              :start_date => Date.parse("2010/10/13")
            ).generate

puts schedule1.to_s

schedule2 = RRSchedule::Schedule.new(
              :teams => %w(T1 T2 T3 T4 T5 T6 T7 T8 T9 T10 T11 T12 T13),
              :rules => [
                RRSchedule::Rule.new(
                  :wday => 3,
                  :gt => ["7:00 PM"],
                  :ps => ["1","2","3","4"],
                )
              ],
              :cycles => 3,
              :shuffle => true,
              :start_date => Date.parse("2010/10/13")
            ).generate

puts schedule2.to_s

schedule3 = RRSchedule::Schedule.new(
              :teams => [
                %w(A1 A2 A3 A4 A5 A6 A7 A8 A9),
                %w(B1 B2 B3 B4 B5 B6 B7 B8 B9),
                %w(C1 C2 C3 C4 C5 C6 C7 C8 C9),
                %w(D1 D2 D3 D4 D5 D6 D7 D8 D9),
                %w(E1 E2 E3 E4 E5 E6 E7 E8 E9),
                %w(F1 F2 F3 F4 F5 F6 F7 F8 F9),
                %w(G1 G2 G3 G4 G5 G6 G7 G8 G9),
              ],

              :rules => [
                RRSchedule::Rule.new(
                  :wday => 1,
                  :game_time => ["7:00 PM"],
                  :playing_surfaces => ["1","2","3","4"],
                ),
                RRSchedule::Rule.new(
                  :wday => 3,
                  :game_times => ["7:00 AM","9:00 AM", "10:00 AM"],
                  :playing_surfaces => ["1","2","3","4","5","6","7","8"],
                )

              ],
              :cycles => 2,
              :start_date => Date.parse("2013/5/12"),
              :balanced_game_time => false,
              :balanced_playing_surface => true
            ).generate

puts schedule3.to_s
