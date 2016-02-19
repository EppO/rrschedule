module RRSchedule
  class Round
    attr_accessor :round, :cycle, :round_with_cycle, :games, :division, :teams
    attr_reader :round_with_cycle

    def initialize(division:, round:, cycle:, teams:, games: [])
      @round            = round
      @cycle            = cycle
      @round_with_cycle = cycle * (teams.size - 1) + round
      @division         = division
      @teams            = teams
      @games            = games
    end
    
    def process
      teams = @teams.dup
      while !teams.empty? do
        team_a = teams.shift
        team_b = teams.reverse!.shift
        teams.reverse!
        
        x = (@cycle % 2) == 0 ? [team_a, team_b] : [team_b, team_a]
        
        matchup = Game.new(team_a: x[0], team_b: x[1])
        @games << matchup
      end
      @games
    end

    def to_s
      str = "Division #{@division.to_s} - Round ##{@round.to_s}\n"
      str += "=====================\n"

      @games.each do |game|
        if [game.team_a, game.team_b].any? { |team| team.is_dummy? }
          str += bye(g)
        else
          str += game.team_a.to_s + " Vs " + game.team_b.to_s + "\n"
        end
      end
      str += "\n"
    end

    private

    def bye game
      bye_team = game.team_a.is_dummy? ? game.team_a.to_s : game.team_b.to_s
      "#{bye_team} has a BYE\n"
    end
  end
end
