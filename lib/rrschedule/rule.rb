module RRSchedule
  class Rule
    attr_accessor :wday, :game_time, :ps

    def initialize(params)
      self.wday = params[:wday]
      self.game_time = params[:game_time]
      self.ps = params[:ps]
    end

    def wday=(wday)
      @wday = wday ? wday : 1
      raise "Rule#wday must be between 0 and 6" unless (0..6).include?(@wday)
    end

    #Array of available playing surfaces. You can pass it any kind of object
    def ps=(ps)
      @ps = Array(ps).empty? ? ["Field #1", "Field #2"] : Array(ps)
    end

    #Array of game times where games are played. Must be valid DateTime objects in the string form
    def game_time=(game_time)
      @game_time =  Array(game_time).empty? ? ["7:00 PM"] : Array(game_time)
      @game_time.collect! do |game_timeime|
        begin
          DateTime.parse(game_timeime)
        rescue
          raise "game times must be valid time representations in the string form (e.g. 3:00 PM, 11:00 AM, 18:20, etc)"
        end
      end
    end

    def <=>(other)
      self.wday == other.wday ?
      DateTime.parse(self.game_time.first.to_s) <=> DateTime.parse(other.game_time.first.to_s) :
      self.wday <=> other.wday
    end
  end
end
