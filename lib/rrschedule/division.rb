require 'pp'

module RRSchedule
  class Division
    attr_accessor :name, :teams
    attr_reader :rounds

    def initialize(name:, teams: [])
      @name = name
      @teams = teams.dup
      raise "at least 2 teams are required" if @teams.size < 2
      raise "DummyTeam is a reserved Class name. Please use another Class name" if @teams.any? { |team| team.is_a? DummyTeam }
      @teams << DummyTeam.new if @teams.size.odd?
      @rounds = []
      @games = []
      @stats = {}
      @teams.each do |team|
        @stats[team] = { game_times: Hash.new(0), fields: Hash.new(0) }
      end
    end
    
    def to_s
      @name
    end

    def process(cycles:, max_games:, shuffle:)
      @teams = @teams.sort_by { rand } if shuffle

      current_cycle = 0
      current_round = 1

      while current_round < @teams.size && current_cycle < cycles
        round = Round.new(division: self, round: current_round, cycle: current_cycle, teams: @teams)
        @games << round.process
        @rounds << round
        
        current_round += 1

        # Team rotation (the first team is fixed)
        # Insert into the first flight position the flight with the last element removed
        @teams = @teams.insert(1, @teams.delete_at(@teams.size - 1))

        # have we completed a full round-robin for the current flight?
        if current_round == @teams.size
          current_cycle += 1
          current_round = 1 if current_cycle < cycles
        end
        
        break if @rounds.size == max_games
      end
      @rounds
    end
    
    def round_robin?(cycles)
      # each round-robin round should contain n-1 games where n is the number of
      # teams (:dummy included if odd)

      round_games = cycles * (@teams.size - 1)
      return false if @rounds.size != round_games

      # check if each team plays the same number of games against each other
      @teams.each do |team_a|
        @teams.reject { |same_team| same_team == team_a }.each do |team_b|
          return false unless games(team_a, team_b).size == cycles || DummyTeam.dummy?([ team_a, team_b ])
        end
      end
      return true
    end

    def games(team_a = nil, team_b = nil)
      if team_a
        if team_b
          # Team A vs Team B games
          @games.flatten.select { |game| 
            (game.team_a == team_a && game.team_b == team_b) || (game.team_a == team_b && game.team_b == team_a)
          }.uniq
        else
          # Team A games only
          @games.flatten.select { |game| (game.team_a == team_a) || (game.team_b == team_a) }.uniq
        end
      else
        # All games
        @games
      end
    end
    
    def game_times(team, game_time)
      @stats[team][:game_times][game_time]
    end

    def fields(team, field)
      @stats[team][:fields][field]
    end
    
    def update_stats(team, game_time, field)
      @stats[team][:game_times][game_time] += 1
      @stats[team][:fields][field]         += 1
    end
  end
end
