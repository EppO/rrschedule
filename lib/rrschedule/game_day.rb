module RRSchedule
  class GameDay
    attr_accessor :date, :games

    def initialize(date:, games: [])
      @date = date
      @games = games
    end
    
    def self.next_game_day
      
    end
  end
end
