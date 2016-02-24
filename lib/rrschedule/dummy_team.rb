module RRSchedule
  class DummyTeam
    def self.dummy?(teams)
      teams.any? { |team| team.is_a? DummyTeam }
    end
  end
end