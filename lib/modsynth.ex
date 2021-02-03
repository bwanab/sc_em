defmodule Modsynth do
  import ScClient


  def init() do
    load_synths("/home/bill/Dropbox/music/supercollider/synthdefs/modsynth")
  end

  def get_bus(ct, name)  when ct == :audio do
    get_audio_bus(name)
  end

  def get_bus(ct, name)  when ct == :control do
    get_control_bus(name)
  end

  @doc """
  the signiture is as control_points in synths.clj, but for now
  I'm hardcoding the bus numbers as name
  """
  def connect_nodes(n1, n2, ct, c, name, ob) do
    bus = get_bus(ct, name)
    set_control(n1, ob, bus)
    set_control(n2, c, bus)
    bus
  end


  def t1() do
    audio_out = make_module("audio-out", ["ib1", 1, "ib2", 2])
    amp = make_module("amp", ["ib", 1, "gain", 2, "ob", 3])
    saw = make_module("saw-osc", ["ib", 1, "ob", 2])
    note_freq = make_module("note-freq", ["note", 1, "ob", 2])
    note = make_module("const", ["val", 50, "ob", 2])
    gain = make_module("const", ["val", 0.3, "ob", 2])
    connect_nodes(gain, amp, :control, "gain", "c_to_gain", "ob")
    connect_nodes(note, note_freq, :control, "note", "c_to_note", "ob")
    connect_nodes(note_freq, saw, :control, "ib" ,"note_to_saw", "ob")
    connect_nodes(saw, amp, :audio, "ib" , "saw_to_gain", "ob")
    connect_nodes(amp, audio_out, :audio, "ib1" , "gain_to_audio", "ob")
    %{:note => note, :gain => gain}
  end
end
