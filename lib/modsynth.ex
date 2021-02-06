defmodule Modsynth do
  require Logger
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

  def connect_nodes(n1, n2, ct, c, name, ob) do
    bus = get_bus(ct, name)
    set_control(n1, ob, bus)
    set_control(n2, c, bus)
    bus
  end

  def build_module(synths, name) do
    synth_name = case name do
      "cc-cont-in" -> "cc-in"
      "cc-disc-in" -> "cc-in"
      "doc-node" -> ""
      "midi-in2" -> "midi-in"
      "piano-in" -> "midi-in"
      "rand-pent" -> ""
      "slider-ctl" -> ""
      _ -> name
                 end
    if synth_name != "" do
      id = make_module(synth_name, synths[name])
      Logger.info("build_module: #{synth_name} id #{id}")
      id
    else 0
    end
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

  def t2(synths) do
    midi_in = build_module(synths, "midi-in")
    midi_pid = MidiInClient.start_midi(midi_in)
    amp = build_module(synths, "amp")
    audio_out = build_module(synths, "audio-out")
    saw = build_module(synths, "saw-osc")
    note_freq = build_module(synths, "note-freq")
    gain = build_module(synths, "const")
    connect_nodes(midi_in, note_freq, :control, "note", "c_to_note", "ob")
    connect_nodes(gain, amp, :control, "gain", "c_to_gain", "ob")
    connect_nodes(note_freq, saw, :control, "ib" ,"note_to_saw", "ob")
    connect_nodes(saw, amp, :audio, "ib" , "saw_to_gain", "ob")
    connect_nodes(amp, audio_out, :audio, "ib1" , "gain_to_audio", "ob")
    set_control(gain, "val", 0.1)
    %{:midi_pid => midi_pid, :gain => gain}
  end

end
