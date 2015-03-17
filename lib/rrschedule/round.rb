module RRSchedule
  class Round
    attr_accessor :round, :cycle, :round_with_cycle, :games, :flight

    def initialize(args={})
      args = defaults.merge(args)
      @round = args[:round]
      @cycle = args[:cycle]
      @round_with_cycle = args[:round_with_cycle]
      @flight = args[:flight]
      @games = args[:games]
    end

    def defaults
      {
        games: []
      }
    end

    def to_s
      str = "FLIGHT #{@flight.to_s} - Round ##{@round.to_s}\n"
      str += "=====================\n"

      @games.each do |g|
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
