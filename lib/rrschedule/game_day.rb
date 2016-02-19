module RRSchedule
  class GameDay
    attr_accessor :date, :games

    def initialize(date:, games: [])
      @date = date
      @games = games
    end
  end
end
