module RRSchedule
  class Schedule
    attr_reader   :divisions, :rounds, :gamedays
    attr_accessor :teams,
                  :rules,
                  :cycles,
                  :start_date,
                  :end_date,
                  :exclude_dates,
                  :shuffle,
                  :group_divisions,
                  :balanced_game_time,
                  :balanced_playing_surface,
                  :max_games

    def initialize(teams: [], cycles: 1, shuffle: true, max_games: Float::INFINITY, rules: [], 
                   balance_game_time: true, balance_playing_surface: true,  group_divisions: true, 
                   start_date: Date.today, end_date: nil, include_dates: [], exclude_dates: [])
      @gamedays                 = []
      @schedule                 = []
      @rounds                   = {}
      @divisions                = []
      @teams                    = teams
      @cycles                   = cycles
      @shuffle                  = shuffle
      @balanced_game_time       = balance_game_time
      @balanced_playing_surface = balance_playing_surface
      @exclude_dates            = exclude_dates
      @include_dates            = include_dates
      @start_date               = start_date
      @end_date                 = end_date
      @group_divisions          = group_divisions
      @rules                    = rules
      @max_games                = max_games
    end

    def generate(params={})
      raise "You need to specify at least 1 team" if @teams.nil? || @teams.empty?
      raise "You need to specify at least 1 rule" if @rules.nil? || @rules.empty?

      # A "division" is a group of teams where teams play round-robin against each other
      # If teams aren't in divisions, we create a single division and put all teams in it
      division_teams = @teams.first.respond_to?(:to_ary) ? teams : [ @teams ]
      division_teams.each_with_index do |teams, index|
        @divisions << Division.new(name: "Division ##{index + 1}", teams: teams)
      end

      @divisions.each do |division|
        @rounds[division.name] = division.process(cycles: @cycles, max_games: @max_games, shuffle: shuffle)
      end

      dispatch_games(@rounds)
      self
    end

    def total_games
      total = 0

      @divisions.each do |division|
        total += (division.teams.size / 2) * (division.teams.size - 1)
      end
      total
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

    def valid_round_robin?(division)
      # each round-robin round should contain n-1 games where n is the number of
      # teams (:dummy included if odd)

      round_games = @cycles * (division.teams.size - 1)
      return false if @rounds[division.name].size != round_games

      # check if each team plays the same number of games against each other
      division.teams.each do |t1|
        division.teams.reject{|t| t == t1 }.each do |t2|
          return false unless t1.games_against(t2).size == @cycles || Team.include_dummies?([t1, t2])
        end
      end
      return true
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
        dispatch_game(g) unless Team.include_dummies?([g.team_a, g.team_b])
      end

      group_schedule
    end

    def group_schedule
      s = @schedule.group_by{|fs| fs[:gamedate] }.sort
      s.each do |gamedate, gms|
        games = []
        gms.each do |gm|
          game = Game.new(
            team_a: gm[:team_a],
            team_b: gm[:team_b],
            playing_surface: gm[:playing_surface],
            game_time: gm[:game_time]
          )
          games << game
        end
        @gamedays << GameDay.new(date: gamedate, games: games)
      end
    end

    def any_games_this_date(game, games_this_date)
      games_this_date.any? {|g| [game.team_a,game.team_b].include?(g[:team_a]) || [game.team_a,game.team_b].include?(g[:team_b]) }
    end

    # if one of the teams has already played on this gamedate, we change the rule
    def gamedate_check(game)
      if @schedule.size > 0
        games_this_date = @schedule.select{|v| v[:gamedate] == @cur_date }

        if any_games_this_date(game, games_this_date)
          @cur_rule_index = (@cur_rule_index < @rules.size - 1) ? @cur_rule_index + 1 : 0
          @cur_rule = @rules[@cur_rule_index]
          reset_resource_availability
          @cur_game_time = get_best_game_time(game)
          @cur_ps = get_best_playing_surface(game, @cur_game_time)
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
      @cur_ps = get_best_playing_surface(game, @cur_game_time)
      @cur_date ||= next_game_date(@start_date, @cur_rule.wday)

      gamedate_check(game)

      @schedule.push(
        {
          team_a: game.team_a,
          team_b: game.team_b,
          gamedate: @cur_date,
          playing_surface: @cur_ps,
          game_time: @cur_game_time
        }
      )
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

    def update_team_stats(game, game_time, playing_surface)
      game.team_a.games << game
      game.team_a.play_at(game_time, playing_surface)
      game.team_b.games << game
      game.team_b.play_at(game_time, playing_surface)
    end

    def get_best_game_time(game)
      game_time_left = @game_time_ps_avail.reject {|k,v| v.empty? }

      if @balanced_game_time
        x = balance_game_times(game, game_time_left)
      else
        x = game_time_left.sort.first[0]
      end
      x
    end

    def balance_game_times(game, game_time_left)
      x = {}
      game_time_left.each_key do |game_time|
        x[game_time] = [ game.team_a.game_times[game_time] + game.team_b.game_times[game_time], rand(1000) ]
      end
      x.sort_by {|k,v| [v[0],v[1]] }.first[0]
    end

    def get_best_playing_surface(game, game_time)
      x = {}
      if @balanced_playing_surface
        x = balance_playing_surfaces(game, game_time)
      else
        x = @game_time_ps_avail[game_time].first[0]
      end
      x
    end

    def balance_playing_surfaces(game, game_time)
      x = {}
      @game_time_ps_avail[game_time].each do |ps|
        x[ps] = [ game.team_a.playing_surfaces[ps] + game.team_b.playing_surfaces[ps], rand(1000) ]
      end
      x.sort_by{|k,v| [v[0],v[1]] }.first[0]
    end

    def reset_resource_availability
      @game_time_ps_avail = {}
      @cur_rule.game_times.each do |game_time|
        @game_time_ps_avail[game_time] = @cur_rule.playing_surfaces.clone
      end
    end

    def update_resource_availability(cur_game_time,cur_ps)
      @game_time_ps_avail[cur_game_time].delete(cur_ps)
    end

    # returns an array of all available game times / playing surfaces, all rules included.
    def all_game_times
      @rules.collect{|r| r.game_times }.flatten.uniq
    end

    def all_playing_surfaces
      @rules.collect {|r| r.playing_surfaces }.flatten.uniq
    end
  end

end
