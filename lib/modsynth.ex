defmodule Modsynth do
  require Logger
  import ScClient

  def init() do
    load_synths(Application.get_env(:sc_em, :remote_synth_dir))
    get_synth_vals(Application.get_env(:sc_em, :local_synth_dir))
  end

  @doc """
  read a stored modsynth circuit spec file, create the modules and make the connections

  returns a list of the external controls other than midi in or audio in
  """
  def read_file(synths, fname) do
      {:ok, d} = File.read(fname)
      {:ok, ms} = Jason.decode(d)
      node_specs = Enum.map(ms["nodes"],
        fn x -> parse_node_name(x["w"]) end) |> Enum.into(%{})

      nodes = Enum.map(Enum.sort(Map.keys(node_specs), :desc),
        fn k -> {k, build_module(synths, node_specs[k])} end)
        |> Enum.into(%{})

      connections = Enum.map(ms["connections"],
        fn [from, to] ->
          {from_name, from_node_param, from_bus_type} = parse_connection_name(nodes, from)
          {to_name, to_node_param, _} = parse_connection_name(nodes, to)
          #
          # Note: side effect!
          #
          connect_nodes(from_node_param, to_node_param, from_bus_type, from_name <> "_to_" <> to_name)
          {from_node_param, to_node_param, from_bus_type, from_name <> "_to_" <> to_name}
        end)
      Enum.filter(connections, fn {_fnp, _tnp, _bus, name} -> is_external_control(name)  end)
      |> Enum.map(fn {{id, control}, _, _, name} -> {name, id, control} end)
  end

  def parse_node_name(s) do
    [node, id] = String.split(s, ":")
    {String.to_integer(id), node}
  end


  @doc """
  in:
  nodes - a map indexed by the node id (e.g. "amp:7" the node is an amp the id is the 7),
  s - the connection definition (e.g. "amp:5-out", node is amp, id is 5 and the param to connect is "out")

  returns a tuple containing {node_name, {node, param}, output_bus_type}
  """
  def parse_connection_name(nodes, s) do
    [node_name, id_spec] = String.split(s, ":")
    [ids, param] = String.split(id_spec, "-", parts: 2)
    id = String.to_integer(ids)
    {node, params, bus_type} = nodes[id]
    {node_name, {node, param}, bus_type}
  end

  def is_external_control(name) do
    String.starts_with?(name, "const")
    || String.starts_with?(name, "slider")
    || String.starts_with?(name, "cc-cont-in")
    || String.starts_with?(name, "cc-in")
    || String.starts_with?(name, "midi-in")
  end

  @doc """
  Reads the synthdef files from the specified directory to obtain their names and parameter specifications

  returns a list of synth specifications as a map indexed by the module name name => {parameters, out_bus_type}}
  e.g. "saw-osc" => {[["ib", 55.0], ["ob", 65.0]], :audio}
  """
  def get_synth_vals(dir) do
    File.ls!(dir)
    |> Enum.map(fn fname -> get_one_synth_vals(dir <> "/" <> fname) end)
    |> Enum.into(%{})
  end

  def get_one_synth_vals(fname) do
    synth = ReadSynthDef.read_file(fname) |> Map.get(:synth_defs) |> List.first
    synth_name = synth.name
    synth_vals = synth.parameter_vals
    synth_parameters = Enum.map(synth.parameter_names, fn {parm, order} -> [parm, Enum.at(synth_vals, order)]; end)
    synth_out_type = case Enum.find(synth.ugens, fn x -> x.ugen_name == "Out" end).calc_rate do
                       1 -> :control
                       2 -> :audio
                     end
    {synth_name, {synth_parameters, synth_out_type}}
  end

  def get_bus(ct, name)  when ct == :audio do
    get_audio_bus(name)
  end

  def get_bus(ct, name)  when ct == :control do
    get_control_bus(name)
  end

  def connect_nodes({n1, outc}, {n2, inc}, ct, name) do
    Logger.info("connect_nodes(#{inspect({n1, outc})}, #{inspect({n2, inc})}, #{ct}, #{name}")
    bus = get_bus(ct, name)
    set_control(n1, outc, bus)
    set_control(n2, inc, bus)
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
      "slider-ctl" -> "const"
      _ -> name
                 end

    if synth_name != "" do
      {synth_params, bus_type} = synths[synth_name]
      id = make_module(synth_name, synth_params)
      Logger.info("build_module: #{synth_name} id #{id}")
      {id, synth_params, bus_type}
    else 0
    end
  end

  @doc """
  special purpose for "const" controls
  """
  def ctl(id, val) do
    set_control(id, "val", val)
  end

  #################################################################################
  # test functions, should probably be in another module
  #################################################################################

  def t1(synths) do
    {audio_out, _, _} = build_module(synths, "audio-out")
    {amp, _, _} = build_module(synths, "amp")
    {saw, _, _} = build_module(synths, "saw-osc")
    {note_freq, _, _} = build_module(synths, "note-freq")
    {note, _, _} = build_module(synths, "const")
    {gain, _, _} = build_module(synths, "const")

    connect_nodes({gain, "val"}, {amp, "gain"}, :control, "c_to_gain")
    connect_nodes({note, "val"}, {note_freq, "note"}, :control, "c_to_note")
    connect_nodes({note_freq, "freq"}, {saw, "in" }, :control,"note_to_saw")
    connect_nodes({saw, "sig"}, {amp, "in" }, :audio, "saw_to_gain")
    connect_nodes({amp, "out"}, {audio_out, "b1" }, :audio, "gain_to_audio")
    set_control(gain, "in", 0.1)
    %{:note => note, :gain => gain}
  end

  def t2(synths) do
    {audio_out, _, _} = build_module(synths, "audio-out")
    {amp, _, _} = build_module(synths, "amp")
    {saw, _, _} = build_module(synths, "saw-osc")
    {note_freq, _, _} = build_module(synths, "note-freq")
    {midi_in, _, _} = build_module(synths, "midi-in-note")
    midi_pid = MidiInClient.start_midi(midi_in)
    {gain, _, _} = build_module(synths, "cc-in")
    :ok = MidiInClient.register_cc(2, gain, "in")
    :ok = MidiInClient.register_cc(7, gain, "in")

    connect_nodes({gain, "val"}, {amp, "gain"}, :control, "c_to_gain")
    connect_nodes({midi_in, "out"}, {note_freq, "note"}, :control, "c_to_note")
    connect_nodes({note_freq, "freq"}, {saw, "freq" }, :control,"note_to_saw")
    connect_nodes({saw, "sig"}, {amp, "in" }, :audio, "saw_to_gain")
    connect_nodes({amp, "out"}, {audio_out, "b1" }, :audio, "gain_to_audio")
    set_control(gain, "in", 0.1)
    %{:midi_pid => midi_pid, :gain => gain}
  end

  def t3(synths) do
    {audio_out, _, _} = build_module(synths, "audio-out")
    {amp, _, _} = build_module(synths, "amp")
    {saw, _, _} = build_module(synths, "saw-osc")
    {midi_in, _, _} = build_module(synths, "midi-in")
    midi_pid = MidiInClient.start_midi(midi_in)
    {gain, _, _} = build_module(synths, "cc-cont-in")
    :ok = MidiInClient.register_cc(2, gain, "in")
    :ok = MidiInClient.register_cc(7, gain, "in")

    connect_nodes({gain, "val"}, {amp, "gain"}, :control, "c_to_gain")
    connect_nodes({midi_in, "freq"}, {saw, "freq" }, :control,"note_to_saw")
    connect_nodes({saw, "sig"}, {amp, "in" }, :audio, "saw_to_gain")
    connect_nodes({amp, "out"}, {audio_out, "b1" }, :audio, "gain_to_audio")
    set_control(gain, "in", 0.1)
    %{:midi_pid => midi_pid, :gain => gain}
  end

  def tt() do
    #MidiIn.start(0,0)
    synths = init()
    Process.sleep(2000)
    t3(synths)
  end


  def trf(file) do
    synths = init()
    read_file(synths, file)
  end

  def tpm() do
    {:ok, input} = PortMidi.open(:input, "mio")
    PortMidi.listen(input, self())
    t_rec()
  end

  def t_rec() do
    receive do
      # {_input, [{{status, note, _vel}, _timestamp}]} -> Logger.info("#{Integer.to_string(status)} #{note}")
      {_input, messages} -> Logger.info("#{inspect(messages)}")
    end
    t_rec()
  end

end
