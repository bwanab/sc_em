defmodule MidiInClient do
  def start_midi(synth, param) do
    GenServer.call(MidiIn, {:start_midi, "mio", synth, param})
  end

  def register_cc(cc_num, cc, control) do
    GenServer.call(MidiIn, {:register_cc, cc_num, cc, control})
  end

  def stop_midi(pid) do
    GenServer.call(MidiIn, {:stop_midi, pid})
  end
end
