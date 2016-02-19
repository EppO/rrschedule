module RRSchedule
  class Division
    attr_accessor :name, :teams, :games, :rounds
    attr_reader :games_count

    def initialize(name:, teams: [])
      @name = name
      @teams = []
      raise "at least 2 teams are required" if teams.size < 2
      teams.each do |team_name|
        raise "teams have to be unique" if @teams.find { |team| team.name == team_name}
        @teams << Team.new(name: team_name, division: self)
      end
      @teams << Team.new(name: "dummy", division: self, dummy: true) if @teams.size.odd?
      @rounds = []
      @games_count = 0
    end
    
    def to_s
      @name
    end
    
    def process(cycles:, max_games:, shuffle:)
      @teams = @teams.sort_by { rand } if shuffle

      current_cycle = 0
      current_round = 1

      while current_round < @teams.size && current_cycle < cycles
        round = Round.new(division: self, round: current_round, cycle: current_cycle, teams: @teams)
        games = round.process
        @rounds << round
        
        @games_count += games.size
        current_round += 1

        # Team rotation (the first team is fixed)
        # Insert into the first flight position the flight with the last element removed
        @teams = @teams.insert(1, @teams.delete_at(@teams.size - 1))

        # have we completed a full round-robin for the current flight?
        if current_round == @teams.size
          current_cycle += 1
          current_round = 1 if current_cycle < cycles
        end
        
        break if @rounds.size == max_games
      end
      @rounds
    end
  end
end
