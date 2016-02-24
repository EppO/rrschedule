module RRSchedule
  class Rule
    attr_accessor :wday, :game_times, :fields

    def initialize(wday: 1, game_times: [ "7:00 PM" ], fields: [ "Field #1" ])
      self.wday       = wday
      self.game_times = Array(game_times)
      self.fields     = Array(fields)
    end

    def wday=(wday)
      @wday = wday ? wday : 1
      raise "Rule#wday must be between 0 and 6 (given #{@wday})" unless (0..6).include?(@wday)
    end

    #Array of game times where games are played. Must be valid DateTime objects in the string form
    def game_times=(game_times)
      @game_times = game_times.collect do |game_time|
        begin
          DateTime.parse(game_time)
        rescue
          raise "game times must be valid time representations in string form (e.g. 3:00 PM, 11:00 AM, 18:20, etc)"
        end
      end
    end

    def <=>(other)
      if self.wday == other.wday
        DateTime.parse(self.game_times.first.to_s) <=> DateTime.parse(other.game_times.first.to_s)
      else
        self.wday <=> other.wday
      end
    end
  end
end
