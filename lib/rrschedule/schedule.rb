module RRSchedule
  class Schedule
    attr_reader :flights, :rounds, :gamedays
    attr_accessor :teams,
                  :rules,
                  :cycles,
                  :start_date,
                  :exclude_dates,
                  :shuffle,
                  :group_flights,
                  :balanced_game_time,
                  :balanced_playing_surface

    def initialize(args={})
      args = defaults.merge(args)
      @gamedays                 = []
      @teams                    = args[:teams]
      @cycles                   = args[:cycles]
      @shuffle                  = args[:shuffle]
      @balanced_game_time       = args[:balanced_game_time]
      @balanced_playing_surface = args[:balanced_playing_surface]
      @exclude_dates            = args[:exclude_dates]
      @start_date               = args[:start_date]
      @group_flights            = args[:group_flights]
      @rules                    = args[:rules]
    end

    def defaults
      {
        teams:                    [],
        cycles:                   1,
        shuffle:                  true,
        balanced_game_time:       true,
        balanced_playing_surface: true,
        exclude_dates:            [],
        start_date:               Date.today,
        group_flights:            true,
        rules:                    []
      }
    end

    def process_round(teams)
      games = []
      while !teams.empty? do
        team_a = teams.shift
        team_b = teams.reverse!.shift
        teams.reverse!

        x = [team_a, team_b].shuffle

        matchup = { team_a: x[0], team_b: x[1] }
        games << matchup
      end
      games
    end

    def generate(params={})
      raise "You need to specify at least 1 team" if @teams.nil? || @teams.empty?
      raise "You need to specify at least 1 rule" if @rules.nil? || @rules.empty?

      arrange_flights
      init_stats

      @rounds = []

      @flights.each_with_index do |flight, flight_id|
        process_flight(flight, flight_id)
      end

      dispatch_games(@rounds)
      self
    end

    def process_flight(flight, flight_id)
      flight = flight.sort_by { rand } if @shuffle

      current_cycle = current_round = 0

      begin
        games = process_round(flight.clone)
        current_round += 1

        # Team rotation (the first team is fixed)
        flight = flight.insert(1, flight.delete_at(flight.size - 1))

        @rounds ||= []
        @rounds[flight_id] ||= []
        @rounds[flight_id] << Round.new(
          round: current_round,
          flight: flight_id,
          games: games.collect {|g|
            Game.new(
              team_a: g[:team_a],
              team_b: g[:team_b]
            )
          }
        )

        # have we completed a full round-robin for the current flight?
        if current_round == flight.size - 1
          current_cycle += 1
          current_round = 0 if current_cycle < @cycles
        end

      end until current_round == flight.size - 1 && current_cycle == @cycles
    end

    def total_games
      total = 0

      @flights.each do |teams|
        total += (teams.size / 2) * (teams.size - 1)
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

    def valid_round_robin?(flight_id=0)
      # each round-robin round should contain n-1 games where n is the number of
      # teams (:dummy included if odd)

      round_games = @cycles * (@flights[flight_id].size - 1)
      return false if @rounds[flight_id].size != round_games

      # check if each team plays the same number of games against each other
      @flights[flight_id].each do |t1|
        @flights[flight_id].reject{|t| t == t1 }.each do |t2|
          return false unless face_to_face(t1, t2).size == @cycles || [t1, t2].include?(:dummy)
        end
      end
      return true
    end

    private

    # A "flight" is a division where teams play round-robin against each other
    def arrange_flights
      @flights = Marshal.load(Marshal.dump(@teams)) #deep clone

      # If teams aren't in flights, we create a single flight and put all teams in it
      @flights = [@flights] unless @flights.first.respond_to?(:to_ary)

      @flights.each_with_index do |flight, i|
        raise ":dummy is a reserved team name. Please use something else" if flight.member?(:dummy)
        raise "at least 2 teams are required" if flight.size < 2
        raise "teams have to be unique" if flight.uniq.size < flight.size
        @flights[i] << :dummy if flight.size.odd?
      end
    end

    def flight_group(rounds)
      flat_games = []
      while rounds.flatten.size > 0 do
        @flights.each_with_index do |f, flight_index|
          r = rounds[flight_index].shift
          flat_games << r.games if r
        end
      end
      flat_games
    end

    def flat_flight(rounds)
      flat_games = []
      flight_index = round_index = 0
      game_count = 0
      while game_count < total_games
        if rounds[flight_index][round_index] != nil
          game = rounds[flight_index][round_index].games.shift
          if game
            flat_games << game
            game_count += 1
          end
        end

        round_empty = true
        @flights.each do |i|
          round_empty = round_empty && (rounds[i][round_index].nil? || rounds[i][round_index].games.empty?)
        end

        if flight_index == @flights.size - 1
          flight_index = 0
          round_index += 1 if round_empty
        else
          flight_index += 1
        end
      end
      flat_games
    end

    def dispatch_games(rounds)

      rounds_copy = Marshal.load(Marshal.dump(rounds)) # deep clone

      flat_games = @group_flights? flight_group(rounds_copy) : flat_flight(rounds_copy)

      flat_games.flatten!
      flat_games.each do |g|
        dispatch_game(g) unless [g.team_a, g.team_b].include?(:dummy)
      end

      group_schedule
    end

    def group_schedule
      s = @schedule.group_by{|fs| fs[:gamedate] }.sort
      s.each do |gamedate, gms|
        games = []
        gms.each do |gm|
          games << Game.new(
            team_a: gm[:team_a],
            team_b: gm[:team_b],
            playing_surface: gm[:playing_surface],
            game_time: gm[:game_time]
          )
        end
        @gamedays << Gameday.new(date: gamedate, games: games)
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

      @schedule ||= []

      # if one of the teams has already played on this gamedate, we change rule
      if @schedule.size > 0
        games_this_date = @schedule.select{|v| v[:gamedate] == @cur_date }

        if games_this_date.any? {|g| [game.team_a,game.team_b].include?(g[:team_a]) || [game.team_a,game.team_b].include?(g[:team_b]) }
          @cur_rule_index = (@cur_rule_index < @rules.size - 1) ? @cur_rule_index + 1 : 0
          @cur_rule = @rules[@cur_rule_index]
          reset_resource_availability
          @cur_game_time = get_best_game_time(game)
          @cur_ps = get_best_playing_surface(game,@cur_game_time)
          @cur_date = next_game_date(@cur_date += 1, @cur_rule.wday)
        end
      end

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

      # If we don't have any resources left, we change the rule
      rule_filter
    end

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
      dt += 1 until wday == dt.wday && !@exclude_dates.include?(dt)
      dt
    end

    def update_team_stats(game, game_time, playing_surface)
      @stats[game.team_a][:game_times][game_time] += 1
      @stats[game.team_a][:playing_surfaces][playing_surface] += 1
      @stats[game.team_b][:game_times][game_time] += 1
      @stats[game.team_b][:playing_surfaces][playing_surface] += 1
    end

    def get_best_game_time(game)
      x = {}
      game_time_left = @game_time_ps_avail.reject {|k,v| v.empty? }

      if @balanced_game_time
        game_time_left.each_key do |game_time|
          x[game_time] = [
            @stats[game.team_a][:game_times][game_time] + @stats[game.team_b][:game_times][game_time],
            rand(1000)
          ]
        end
        x.sort_by {|k,v| [v[0],v[1]] }.first[0]
      else
        game_time_left.sort.first[0]
      end
    end

    def get_best_playing_surface(game, game_time)
      x = {}

      if @balanced_playing_surface
        @game_time_ps_avail[game_time].each do |ps|
          x[ps] = [
            @stats[game.team_a][:playing_surfaces][ps] + @stats[game.team_b][:playing_surfaces][ps],
            rand(1000)
          ]
        end
        x.sort_by{|k,v| [v[0],v[1]] }.first[0]
      else
        @game_time_ps_avail[game_time].first[0]
      end
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

    #return matchups between two teams
    def face_to_face(team_a,team_b)
      res = []
      @gamedays.each do |gd|
        res << gd.games.select {|g| (g.team_a == team_a && g.team_b == team_b) || (g.team_a == team_b && g.team_b == team_a)}
      end
      res.flatten
    end

    # Count the number of times each team plays on a given playing surface and at what time. That way
    # we can balance the available playing surfaces/game times among competitors.
    def init_stats
      @stats = {}
      @teams.flatten.each do |t|
        @stats[t] = {game_times: {}, playing_surfaces: {}}
        all_game_times.each { |game_time| @stats[t][:game_times][game_time] = 0 }
        all_playing_surfaces.each { |ps| @stats[t][:playing_surfaces][ps] = 0 }
      end
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
