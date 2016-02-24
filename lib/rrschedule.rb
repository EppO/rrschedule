require "rrschedule/division"
require "rrschedule/round"
require "rrschedule/dummy_team"
require "rrschedule/game"
require "rrschedule/game_day"
require "rrschedule/rule"
require "rrschedule/schedule"

module RRSchedule
  def self.generate(teams: [], cycles: 1, shuffle: true, max_games: Float::INFINITY, rules: [], 
                    balance_game_times: true, balance_fields: true, group_divisions: true, 
                    start_date: Date.today, end_date: nil, include_dates: [], exclude_dates: [])
    Schedule.new(teams: teams, cycles: cycles, shuffle: shuffle, max_games: max_games, 
                 rules: rules, balance_game_times: balance_game_times, 
                 balance_fields: balance_fields, group_divisions: group_divisions, 
                 start_date: start_date, end_date: end_date, 
                 include_dates: include_dates, exclude_dates: exclude_dates).generate
  end
end