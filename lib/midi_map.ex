defmodule MidiMap do
  def inst(program) do
    case program do
      1 -> "sonic-pi-piano"
      33 -> "pluck_bass"
      25 -> "plucking"
      74 -> "flute2"
      50 -> "flute2"
      _ -> "pluck"
    end
  end
end
