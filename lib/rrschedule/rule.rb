module RRSchedule
  class Rule
    attr_accessor :wday, :game_times, :playing_surfaces

    def initialize(params)
      self.wday = params[:wday]
      self.game_times = params[:game_times]
      self.playing_surfaces = params[:playing_surfaces]
    end

    def wday=(wday)
      @wday = wday ? wday : 1
      raise "Rule#wday must be between 0 and 6" unless (0..6).include?(@wday)
    end

    #Array of available playing surfaces. You can pass it any kind of object
    def playing_surfaces=(ps)
      @playing_surfaces = Array(ps).empty? ? ["Field #1", "Field #2"] : Array(ps)
    end

    #Array of game times where games are played. Must be valid DateTime objects in the string form
    def game_times=(gt)
      @game_times =  Array(gt).empty? ? ["7:00 PM"] : Array(gt)
      @game_times.collect! do |game_time|
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
