defmodule Modsynth do
  import ScClient


  def init() do
    load_synths(Application.get_env(:sc_em, :remote_synth_dir))
    get_synth_vals(Application.get_env(:sc_em, :local_synth_dir))
  end

  def get_synth_vals(dir) do
    File.ls!(dir)
    |> Enum.map(fn fname -> get_one_synth_vals(dir <> "/" <> fname) end)
    |> Enum.into(%{})
  end

  def get_one_synth_vals(fname) do
    synth = ReadSynthDef.readFile(fname) |> Map.get(:synth_defs) |> List.first
    synth_name = synth.name
    synth_vals = synth.parameter_vals
    synth_parameters = Enum.map(synth.parameter_names, fn {parm, order} -> [parm, Enum.at(synth_vals, order)]; end)
    {synth_name, synth_parameters}
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

  def build_module(synths, name) do
    make_module(name, synths[name])
  end

  @doc """
  special purpose for "const" controls
  """
  def ctl(id, val) do
    set_control(id, "val", val)
  end

  def t1(synths) do
    audio_out = build_module(synths, "audio-out")
    amp = build_module(synths, "amp")
    saw = build_module(synths, "saw-osc")
    note_freq = build_module(synths, "note-freq")
    note = build_module(synths, "const")
    gain = build_module(synths, "const")
    connect_nodes(gain, amp, :control, "gain", "c_to_gain", "ob")
    connect_nodes(note, note_freq, :control, "note", "c_to_note", "ob")
    connect_nodes(note_freq, saw, :control, "ib" ,"note_to_saw", "ob")
    connect_nodes(saw, amp, :audio, "ib" , "saw_to_gain", "ob")
    connect_nodes(amp, audio_out, :audio, "ib1" , "gain_to_audio", "ob")
    set_control(gain, "val", 0.1)
    %{:note => note, :gain => gain}
  end
end
