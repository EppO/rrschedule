module RRSchedule
  class Gameday
    attr_accessor :date, :games

    def initialize(params)
      self.date = params[:date]
      self.games = params[:games] || []
    end
  end
end
