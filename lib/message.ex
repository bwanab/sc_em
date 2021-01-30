defmodule MidiMessage do
  @derive Jason.Encoder
  defstruct type: :noteon, val: %{}
end
