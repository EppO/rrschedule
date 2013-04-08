module RRSchedule
  class Round
    attr_accessor :round, :games,:flight

    def initialize(params={})
      self.round = params[:round]
      self.flight = params[:flight]
      self.games = params[:games] || []
    end

    def to_s
      str = "FLIGHT #{@flight.to_s} - Round ##{@round.to_s}\n"
      str += "=====================\n"

      self.games.each do |g|
        if [g.team_a,g.team_b].include?(:dummy)
          str+= g.team_a == :dummy ? g.team_b.to_s : g.team_a.to_s + " has a BYE\n"
        else
          str += g.team_a.to_s + " Vs " + g.team_b.to_s + "\n"
        end
      end
      str += "\n"
    end
  end
end
