module RRSchedule
  class Round
    attr_accessor :round, :games, :flight

    def initialize(params={})
      self.round = params[:round]
      self.flight = params[:flight]
      self.games = params[:games] || []
    end

    def to_s
      str = "FLIGHT #{@flight.to_s} - Round ##{@round.to_s}\n"
      str += "=====================\n"

      self.games.each do |g|
        if [g.team_a, g.team_b].include?(:dummy)
          str += bye(g)
        else
          str += team_a_name + " Vs " + team_b_name + "\n"
        end
      end
      str += "\n"
    end

    private

    def bye game
      bye_team = game.team_a == :dummy ? game.team_a.to_s : game.team_b.to_s
      "#{bye_team} has a BYE\n"
    end
  end
end
