defmodule MidiInClient do
  def start_midi(synth) do
    GenServer.call(MidiIn, {:start_midi, "mio", synth, "note"})
  end

  def stop_midi(pid) do
    GenServer.call(MidiIn, {:stop_midi, pid})
  end
end
