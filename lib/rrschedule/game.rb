module RRSchedule
  class Game
    include Comparable

    attr_accessor :division, :team_a, :team_b, :field, :game_time, :game_date

    def initialize(division:, team_a:, team_b:, field: nil, game_date: nil, game_time: nil)
      @division  = division
      @team_a    = team_a
      @team_b    = team_b
      @field     = field
      @game_date = game_date
      @game_time = game_time
    end

    # Use the rules to get the game time and field for that game
    #
    # rules - The rules to enforce
    #
    # Returns the duplicated String.
    def dispatch_game(rules)
      if @cur_rule.nil?
        @cur_rule = @rules.select {|r| r.wday >= @start_date.wday }.first || @rules.first
        @cur_rule_index = @rules.index(@cur_rule)
        reset_resource_availability
      end

      @cur_game_time = get_best_game_time(game)
      @cur_ps = get_best_field(game, @cur_game_time)
      @cur_date ||= next_game_date(@start_date, @cur_rule.wday)

      gamedate_check(game)
      @game_date = @cur_date
      @game_time = @cur_game_time
      @field     = @cur_ps

      #@schedule.push(game)

      update_team_stats(self, @cur_game_time, @cur_ps)
      update_resource_availability(@cur_game_time, @cur_ps)

      rule_filter
      game
    end
    
    def best_game_time
      game_time_left = @game_time_ps_avail.reject {|k,v| v.empty? }

      if @balance_game_times
        x = balance_game_times(game, game_time_left)
      else
        x = game_time_left.sort.first[0]
      end
      x
    end

    def balance_game_times(game_time_left)
      game_times = {}
      game_time_left.each_key do |game_time|
        game_times[game_time] = [ game.division.game_times(game.team_a, game_time) + game.division.game_times(game.team_b, game_time), rand(1000) ]
      end
      game_times.sort_by {|k,v| [v[0], v[1]] }.first[0]
    end

    def get_best_field(game_time)
      x = {}
      if @balance_fields
        x = balance_fields(game, game_time)
      else
        x = @game_time_ps_avail[game_time].first[0]
      end
      x
    end

    def balance_fields(game_time)
      fields = {}
      @game_time_ps_avail[game_time].each do |field|
        fields[field] = [ game.division.fields(game.team_a, field) + game.division.fields(game.team_b, field), rand(1000) ]
      end
      fields.sort_by{|k,v| [v[0],v[1]] }.first[0]
    end
    
    def reset_resource_availability
      @availability_slots = {}
      @cur_rule.game_times.each do |game_time|
        @availability_slots[game_time] = @cur_rule.fields.clone
      end
    end

    def update_resource_availability(game_time, field)
      @availability_slots[game_time].delete(field)
    end

    def <=>(other)
      if game_time == other.game_time
        field <=> other.field
      else
        game_time <=> other.game_time
      end
    end

    def to_s
      "#{@division.to_s}: #{@team_a.to_s} vs #{@team_b.to_s} on playing surface #{@playing_surface} at #{@game_time.strftime("%I:%M %p") if @game_time}\n"
    end

    def self.on_that_date(games, date)
      games.select{ |game| game.game_date == date }
    end

    def self.any_team_play?(games, team_a, team_b)
      games.any? { |game| [team_a, team_b].include?(game.team_a) || [team_a, team_b].include?(game.team_b) }
    end
  end
end
