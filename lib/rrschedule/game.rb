module RRSchedule
  class Game
    include Comparable

    attr_accessor :team_a, :team_b, :playing_surface, :game_time, :game_date

    def initialize(team_a:, team_b:, playing_surface: nil, game_date: nil, game_time: nil)
      @team_a           = team_a
      @team_b           = team_b
      @playing_surface  = playing_surface
      @game_date        = game_date
      @game_time        = game_time
    end

    def <=>(other)
      if game_time == other.game_time
        playing_surface <=> other.playing_surface
      else
        game_time <=> other.game_time
      end
    end

    def to_s
      "#{@team_a.to_s} vs #{@team_b.to_s} on playing surface #{@playing_surface} at #{@game_time.strftime("%I:%M %p") if @game_time}\n"
    end
  end
end
