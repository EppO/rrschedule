require 'spec_helper'

describe RRSchedule::Schedule do
  let(:teams)        { %w(1 2 3 4 5 6) }
  let(:games_times)  { "7:00PM" }
  let(:fields)       { %w(one two) }
  let(:rules)        { [ RRSchedule::Rule.new(wday: 3, game_times: games_times, fields: fields) ] }
  let(:extra_args)   { {} }
  
  subject(:schedule) { RRSchedule::Schedule.new(teams: teams, rules: rules, **extra_args) }
  
  before(:each) { schedule.generate }
  
  context "new instance without params" do
    it "has default values for some options" do
      bare_schedule = RRSchedule::Schedule.new
      expect(bare_schedule.cycles).to eq(1)
      expect(bare_schedule.shuffle).to be(true)
      expect(bare_schedule.start_date).to eq(Date.today)
      expect(bare_schedule.exclude_dates).to eq([])
    end
  end
  
  context "without teams" do
    it "raises an exception" do
      no_teams_schedule = RRSchedule::Schedule.new(rules: rules)
      expect { no_teams_schedule.generate}.to raise_error("You need to specify at least 1 team")
    end
  end
  
  context "with one single division" do
    it "wraps teams into a single division" do
      expect(schedule.divisions.size).to eq(1)
      expect(schedule.divisions.first.teams.size).to eq(teams.size)
    end
  
    it "does not modify the original array" do
      expect(schedule.teams).to eq(teams)
    end
    
    context "with odd number of teams" do
      let(:teams) { %w(1 2 3 4 5) }

      it "adds a dummy competitor in the created division" do
        expect(schedule.divisions.size).to eq(1)
        expect(schedule.divisions.first.teams.size).to eq(teams.size + 1)
        expect(RRSchedule::DummyTeam.dummy?(schedule.divisions.first.teams)).to be(true)
      end

      it "does not include a dummy team in the original array" do
        expect(schedule.teams).to eq(teams)
        expect(RRSchedule::DummyTeam.dummy?(schedule.teams)).to eq(false)
      end

      context "with extra available resources" do
        let(:rules) { [ RRSchedule::Rule.new(wday: 1, game_times: ["7:00PM", "9:00PM"], fields: %w(one two three four)) ] }
      
        it "has a maximum of (teams/2) games per day" do
          expect(schedule.gamedays).to satisfy { |gamedays| gamedays.all? { |game_day| game_day.games.size <= (schedule.teams.size / 2) } }
        end

        it "has no teams that play more than once the same day" do
          expect(schedule.gamedays).to satisfy { |gamedays| gamedays.all? { |game_day|
              teams_playing_this_day = game_day.games.collect { |game| [ game.team_a, game.team_b ]}.flatten
              teams_playing_this_day.size == teams_playing_this_day.uniq.size
            }
          }
        end
      end
    end
  end
  
  context "with multiple divisions" do
    let(:teams)         { [ %w(A1 A2 A3 A4 A5 A6 A7 A8),
                            %w(B1 B2 B3 B4 B5 B6 B7 B8),
                            %w(C1 C2 C3 C4 C5 C6 C7 C8),
                            %w(D1 D2 D3 D4 D5 D6 D7 D8) ] }
                           
    let(:game_times)    { ["7:00PM", "9:00PM"] }
    let(:extra_args)    {  { start_date: Date.parse("2016/02/24"), 
                             exclude_dates: [ Date.parse("2016/03/02"), Date.parse("2016/03/16") ],
                             cycles: 2 } }

    it "generates separate round-robins" do
      expect(schedule.divisions.size).to eq(4)
      expect(schedule.divisions).to satisfy { |divisions| divisions.all? { |division| division.round_robin?(schedule.cycles) }}
    end
  
    it "has a correct total number of games" do
      expect(schedule.total_games).to eq(schedule.gamedays.collect { |game_day| game_day.games.size }.inject { |x,sum| x + sum })
    end
    
    it "starts at the good date" do
      expect(schedule.gamedays.first.date).to eq(Date.parse("2016/02/24"))
    end
    
    it "does not have games for a date that is excluded" do
      expect(schedule.gamedays.collect{ |gd| gd.date }).not_to include(Date.parse("2016/03/02"), Date.parse("2016/03/21"))
    end
    
    context "with extra rules" do
      let(:teams) { super() << %w(E1 E2 E3 E4 E5 E6 E7 E8) }
                      
      let(:rules) { super() << RRSchedule::Rule.new(wday: 4, game_times: "7:00PM", fields: fields) }
      
      it "uses both days defined in the rules" do
        expect(schedule.gamedays.map { |game_day| game_day.date.wday }.uniq ).to match_array([3, 4])
      end
    end
  end

  ######## RULES #######
  context "with one single game time and one single field" do
    let(:rules) { [ RRSchedule::Rule.new(wday: 1, game_times: "7:00PM", fields: "The Field") ] }

    it "creates automatically an array for game times and fields" do
      expect(schedule.rules.first.game_times).to match_array([ DateTime.parse("7:00PM") ])
      expect(schedule.rules.first.fields).to match_array([ "The Field" ])
    end
  end

  context "with no rules specified" do
    it "raises an exception" do
      no_rule_schedule = RRSchedule::Schedule.new(teams: teams, **extra_args)
      expect { no_rule_schedule.generate }.to raise_error("You need to specify at least 1 rule")
    end
  end

  context "multiple rules on the same weekday" do
    let(:start_date)            { Date.parse("2016/02/25") }
    let(:teams)                 { [ %w(a1 a2 a3 a4 a5 a6 a7 a8), %w(b1 b2 b3 b4 b5 b6 b7 b8) ] }
    let(:rules)                 { [ RRSchedule::Rule.new(wday: 4, game_times: ["7:00PM"], fields: %w(field1 field2)),
                                    RRSchedule::Rule.new(wday: 4, game_times: ["9:00PM"], fields: %w(field1 field2 field3)) ] }
    let(:extra_args)            { { start_date: start_date } }
    let(:max_games_per_gameday) { rules.inject(0) { |result, rule| result + rule.fields.size * rule.game_times.size }}

    it "schedules games on the same day" do
      # Check all resources are used but the last gameday
      games_per_gameday = schedule.gamedays.map { |gameday| [ gameday.date.to_s, gameday.games.size ] }
      expect(games_per_gameday[0..-2]).to satisfy { |games| games.all? { |game| game[1] == max_games_per_gameday } }
      
      # Check the balance of games for the last gameday
      games_played_before_last_gameday = games_per_gameday[0..-2].inject(0) { |games_count, games| games_count + games[1] }
      total_games = teams.inject(0) { |total, division| total + (division.size / 2) * (division.size - 1) * schedule.cycles }
      games_left_on_last_gameday = total_games - games_played_before_last_gameday
      expect(games_per_gameday[-1][1]).to eq(games_left_on_last_gameday)
    end

    it "schedules games depending the available game times and fields" do
      current_date = schedule.start_date
      # We don't check the last one because it might not be full (round-robin over)
      schedule.gamedays[0..-2].each do |gameday|
        expect(gameday.date).to eq(current_date)
        expect(gameday.games.select { |game| game.game_time == DateTime.parse("7:00PM") && game.field.to_s == "field1" }.size).to eq(1)
        expect(gameday.games.select { |game| game.game_time == DateTime.parse("7:00PM") && game.field.to_s == "field2" }.size).to eq(1)
        expect(gameday.games.select { |game| game.game_time == DateTime.parse("9:00PM") && game.field.to_s == "field1" }.size).to eq(1)
        expect(gameday.games.select { |game| game.game_time == DateTime.parse("9:00PM") && game.field.to_s == "field2" }.size).to eq(1)
        expect(gameday.games.select { |game| game.game_time == DateTime.parse("9:00PM") && game.field.to_s == "field3" }.size).to eq(1)
        current_date += 7
      end
      # Check if the last gameday is using one of the resources
      expect(schedule.gamedays[-1].games.map { |game| { game_time: game.game_time, field: game.field } }).to satisfy do |games| 
        games.all? { |game| [ "7:00PM", "9:00PM" ].include?(game[:game_time].strftime("%l:%M%p").strip) && [ "field1", "field2", "field3" ].include?(game[:field]) }
      end
    end
  end

  context "with an end date" do
    let(:start_date)     { Date.parse("2016/02/22") }
    let(:end_date)       { Date.parse("2016/04/24") }
    let(:included_dates) { [ Date.parse("2016/03/18"), Date.parse("2016/04/15") ] }
    let(:excluded_dates) { [ Date.parse("2016/03/16"), Date.parse("2016/04/13") ] }
    let(:rules)          { [ RRSchedule::Rule.new(wday: 3, game_times: [ "7:00PM", "9:00PM" ], fields: [ "one" ]) ]  }
    let(:extra_args)     { { start_date: start_date, end_date: end_date, 
                             include_dates: included_dates, exclude_dates: excluded_dates, cycles: 2 } }
    let(:gamedays_dates) { schedule.gamedays.map { |gameday| gameday.date } }
    
    it "does not include excluded dates" do
      expect(gamedays_dates).not_to include(*excluded_dates)
    end
    
    it "does have games explicitely included" do
      expect(gamedays_dates).to include(*included_dates)
    end

    it "starts at the correct date" do
      expect(gamedays_dates.first).to eq(Date.parse("2016/02/24"))
    end
    
    it "ends at the correct date" do
      expect(gamedays_dates.last).to eq(Date.parse("2016/06/01"))
    end
  end
  
  context "with a maximum of games" do
    let(:teams)      { [ %w(A1 A2 A3 A4 A5 A6 A7 A8), %w(B1 B2 B3 B4 B5 B6 B7 B8) ] }
    let(:extra_args) { { cycles: 3, max_games: 20 } }
                             
    it "does not have more than max games" do
      schedule.divisions.each do |division|
        division.teams.each do |team|
          expect(division.games(team).size).to eq(20)
        end
      end
    end
  end
end