module RRSchedule
  class Schedule
    attr_reader   :divisions, :rounds, :gamedays, :stats
    attr_accessor :teams,
                  :rules,
                  :cycles,
                  :start_date,
                  :end_date,
                  :exclude_dates,
                  :shuffle,
                  :group_divisions,
                  :balance_game_times,
                  :balance_fields,
                  :max_games

    def initialize(teams: [], cycles: 1, shuffle: true, max_games: Float::INFINITY, rules: [], 
                   balance_game_times: true, balance_fields: true, group_divisions: true, 
                   start_date: Date.today, end_date: nil, include_dates: [], exclude_dates: [])
      # Defaults
      @teams              = teams
      @cycles             = cycles
      @shuffle            = shuffle
      @balance_game_times = balance_game_times
      @balance_fields     = balance_fields
      @exclude_dates      = exclude_dates
      @include_dates      = include_dates
      @start_date         = start_date
      @end_date           = end_date
      @group_divisions    = group_divisions
      @rules              = rules
      @max_games          = max_games
      
      # Init
      clear
    end

    def generate
      raise "You need to specify at least 1 team" if @teams.nil? || @teams.empty?
      raise "You need to specify at least 1 rule" if @rules.nil? || @rules.empty?

      # A "division" is a group of teams where teams play round-robin against each other
      # If teams aren't in divisions, we create a single division and put all teams in it
      division_teams = @teams.first.respond_to?(:to_ary) ? @teams : [ @teams ]
      division_teams.each_with_index do |teams, index|
        @divisions << Division.new(name: "Division ##{index + 1}", teams: teams)
      end

      @divisions.each do |division|
        @rounds[division.name] = division.process(cycles: @cycles, max_games: @max_games, shuffle: shuffle)
      end

      dispatch_games(@rounds)
      self
    end
    
    def clear
      @schedule           = []
      @divisions          = []
      @rounds             = {}
      @gamedays           = []
    end

    def total_games
      total = 0

      @divisions.each do |division|
        total += (division.teams.size / 2) * (division.teams.size - 1) * @cycles
      end
      total
    end
    
    def games
      @divisions.map { |division| division.games }.flatten
    end

    def to_s
      res = "#{@gamedays.size.to_s} gamedays\n"

      @gamedays.each do |gd|
        res << gd.date.strftime("%Y-%m-%d") + "\n"
        res << "==========\n"
        gd.games.sort.each do |g|
          res << g.to_s
        end
        res << "\n"
      end
      res
    end

    private
    
    def flight_group(rounds)
      flat_games = []
      division_round = Hash.new(0)
      rounds.values.flatten.each do |round|
        @divisions.each do |division|
          round = rounds[division.name][division_round[division.name]]
          flat_games << round.games if round
          division_round[division.name] += 1
        end
      end
      flat_games
    end

    def check_round_empty(rounds, round_index)
      round_empty = true
      @divisions.each do |division|
        round_empty = round_empty && (rounds[i][round_index].nil? || rounds[i][round_index].games.empty?)
      end
      round_empty
    end

    def flat_flight(rounds)
      flat_games = []
      flight_index = 0
      round_index = 0
      game_count = 0

      while game_count < total_games
        unless rounds[flight_index][round_index].nil?
          game = rounds[flight_index][round_index].games.shift
          if game
            flat_games << game
            game_count += 1
          end
        end

        if flight_index == @divisions.size - 1
          flight_index = 0
          round_index += 1 if check_round_empty(rounds, round_index)
        else
          flight_index += 1
        end
      end
      flat_games
    end

    def dispatch_games(rounds)
      flat_games = @group_divisions ? flight_group(rounds) : flat_flight(rounds)

      flat_games.flatten!
      flat_games.each do |g|
        dispatch_game(g) unless DummyTeam.dummy?([g.team_a, g.team_b])
      end

      group_schedule
    end

    def group_schedule
      s = @schedule.group_by{|fs| fs.game_date }.sort
      s.each do |gamedate, games|
        @gamedays << GameDay.new(date: gamedate, games: games)
      end
    end

    # if one of the teams has already played on this gamedate, we change the rule
    def gamedate_check(game)
      if @schedule.size > 0
        games_this_date = Game.on_that_date(@schedule, @cur_date)

        if Game.any_team_play?(games_this_date, game.team_a, game.team_b)
          @cur_rule_index = (@cur_rule_index < @rules.size - 1) ? @cur_rule_index + 1 : 0
          @cur_rule = @rules[@cur_rule_index]
          reset_resource_availability
          @cur_game_time = get_best_game_time(game)
          @cur_ps = get_best_field(game, @cur_game_time)
          @cur_date = next_game_date(@cur_date += 1, @cur_rule.wday)
        end
      end
    end

    def dispatch_game(game)
      if @cur_rule.nil?
        @cur_rule = @rules.select {|r| r.wday >= @start_date.wday }.first || @rules.first
        @cur_rule_index = @rules.index(@cur_rule)
        reset_resource_availability
      end

      @cur_game_time = get_best_game_time(game)
      @cur_ps = get_best_field(game, @cur_game_time)
      @cur_date ||= next_game_date(@start_date, @cur_rule.wday)

      gamedate_check(game)
      game.game_date = @cur_date
      game.game_time = @cur_game_time
      game.field     = @cur_ps

      @schedule.push(game)

      update_team_stats(game, @cur_game_time, @cur_ps)
      update_resource_availability(@cur_game_time, @cur_ps)

      rule_filter
    end

    # If we don't have any resources left, we change the rule
    def rule_filter
      x = @game_time_ps_avail.reject{|k,v| v.empty? }
      if x.empty?
        if @cur_rule_index < @rules.size - 1
          last_rule = @cur_rule
          @cur_rule_index += 1
          @cur_rule = @rules[@cur_rule_index]
          # Go to the next date (except if the new rule is for the same weekday)
          @cur_date = next_game_date(@cur_date += 1, @cur_rule.wday) if last_rule.wday != @cur_rule.wday
        else
          @cur_rule_index = 0
          @cur_rule = @rules[@cur_rule_index]
          @cur_date = next_game_date(@cur_date += 1, @cur_rule.wday)
        end
        reset_resource_availability
      end
    end

    # get the next gameday
    def next_game_date(dt, wday)
      dt += 1 until (wday == dt.wday && !@exclude_dates.include?(dt)) || @include_dates.include?(dt)
      dt
    end

    def update_team_stats(game, game_time, field)
      game.division.update_stats(game.team_a, game_time, field)
      game.division.update_stats(game.team_b, game_time, field)
    end

    def get_best_game_time(game)
      game_time_left = @game_time_ps_avail.reject {|k,v| v.empty? }

      if @balance_game_times
        x = balance_game_times(game, game_time_left)
      else
        x = game_time_left.sort.first[0]
      end
      x
    end

    def balance_game_times(game, game_time_left)
      game_times = {}
      game_time_left.each_key do |game_time|
        game_times[game_time] = [ game.division.game_times(game.team_a, game_time) + game.division.game_times(game.team_b, game_time), rand(1000) ]
      end
      game_times.sort_by {|k,v| [v[0], v[1]] }.first[0]
    end

    def get_best_field(game, game_time)
      x = {}
      if @balance_fields
        x = balance_fields(game, game_time)
      else
        x = @game_time_ps_avail[game_time].first[0]
      end
      x
    end

    def balance_fields(game, game_time)
      fields = {}
      @game_time_ps_avail[game_time].each do |field|
        fields[field] = [ game.division.fields(game.team_a, field) + game.division.fields(game.team_b, field), rand(1000) ]
      end
      fields.sort_by{|k,v| [v[0],v[1]] }.first[0]
    end

    def reset_resource_availability
      @game_time_ps_avail = {}
      @cur_rule.game_times.each do |game_time|
        @game_time_ps_avail[game_time] = @cur_rule.fields.clone
      end
    end

    def update_resource_availability(cur_game_time,cur_ps)
      @game_time_ps_avail[cur_game_time].delete(cur_ps)
    end

    # returns an array of all available game times / fields, all rules included.
    def all_game_times
      @rules.collect{|r| r.game_times }.flatten.uniq
    end

    def all_fields
      @rules.collect {|r| r.fields }.flatten.uniq
    end
  end

end
