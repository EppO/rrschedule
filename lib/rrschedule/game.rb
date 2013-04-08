module RRSchedule
  class Game
    attr_accessor :team_a, :team_b, :playing_surface, :game_time, :game_date
    alias :ta :team_a
    alias :tb :team_b
    alias :ps :playing_surface
    alias :gd :game_date

    def initialize(params={})
      self.team_a = params[:team_a]
      self.team_b = params[:team_b]
      self.playing_surface = params[:playing_surface]
      self.game_time = params[:game_time]
      self.game_date = params[:game_date]
    end
  end
end
