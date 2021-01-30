defmodule MidiMap do
  def inst(program) do
    case program do
      1 -> "sonic-pi-piano"
      25 -> "plucking"
      33 -> "pluck_bass"
      36 -> "pluck_bass"
      41 -> "flute2"
      50 -> "flute2"
      57 -> "sax"
      74 -> "flute2"
      _ -> "pluck"
    end
  end
end
