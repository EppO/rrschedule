module RRSchedule
  class Team
    attr_accessor :name, :division, :games, :dummy
    attr_reader :game_times, :playing_surfaces

    def initialize(name:, division:, games: [], dummy: false)
      @name = name
      @division = division
      @games = games
      @dummy = dummy
      @game_times = Hash.new(0)
      @playing_surfaces = Hash.new(0)
    end
    
    def is_dummy?
      !!@dummy
    end
    
    def play_at(game_time, playing_surface)
      @game_times[game_time] += 1
      @playing_surfaces[playing_surface] += 1
    end
    
    def to_s
      @name
    end
    
    def games_against(other_team)
      (games + other_team.games).select { |game| 
        (game.team_a == self && game.team_b == other_team) || (game.team_a == other_team && game.team_b == self)
      }.uniq
    end
    
    def self.include_dummies?(teams)
      !!teams.find { |team| team.is_dummy? }
    end
  end
end