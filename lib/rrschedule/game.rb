module RRSchedule
  class Game
    include Comparable

    attr_accessor :team_a, :team_b, :playing_surface, :game_time, :game_date

    alias :ta :team_a
    alias :tb :team_b
    alias :gd :game_date

    def initialize(params={})
      @team_a           = params[:team_a]
      @team_b           = params[:team_b]
      @playing_surface  = params[:playing_surface]
      @game_time        = params[:game_time]
      @game_date        = params[:game_date]
    end

    def <=>(other)
      if game_time == other.game_time
        playing_surface <=> other.playing_surface
      else
        game_time <=> other.game_time
      end
    end
  end
end
