defmodule Modsynth.Node do
  defstruct name: "",
    parameters: [],
    bus_type: :audio,
    node_id: 0,
    sc_id: 1001
  @type t :: %__MODULE__{name: String.t,
                         parameters: list,
                         bus_type: atom,
                         node_id: integer,
                         sc_id: integer
  }
end

defmodule Modsynth.Node_Param do
  defstruct node: %{},
    param_name: ""
  @type t :: %__MODULE__{node: Modsynth.Node,
                         param_name: String.t
  }
end

defmodule Modsynth.Connection do
  defstruct from_node_param: %Modsynth.Node_Param{},
    to_node_param: %Modsynth.Node_Param{},
    bus_type: :audio,
    bus_id: 0,
    desc: ""
  @type t :: %__MODULE__{from_node_param: Modsynth.Node_Param,
                         to_node_param: Modsynth.Node_Param,
                         bus_type: atom,
                         bus_id: integer,
                         desc: String.t
  }
end

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

      nodes = Enum.map(Map.keys(node_specs),
        fn k -> {k, get_module(synths, node_specs[k])} end)
      |> Enum.map(fn {k, node} -> %{node | node_id: k} end)

      connections = parse_connections(map_nodes_by_node_id(nodes), ms["connections"])
      {nodes, connections}
  end

  def map_nodes_by_node_id(nodes) do
    Enum.map(nodes, fn node ->
      %{node_id: node_id} = node
      {node_id, node}
    end)
    |> Enum.into(%{})
  end

  def map_nodes_by_name(nodes) do
    Enum.map(nodes, fn node ->
      %{name: name} = node
      {name, node}
    end)
    |> Enum.into(%{})
  end

  @doc """
  The order in which the synths are built matters to supercollider. In general, the
  closest to the output must be built first, the the next closest and so-on.

  This function does the proper ordering.
  """
  def reorder_nodes(connections, nodes) when is_list(nodes) do
    order = ["audio-out"] ++ List.flatten(reorder_nodes(connections, "audio-out"))
    |> Enum.take_while(fn x -> !is_nil(x) end)
    node_map = map_nodes_by_name(nodes)
    Enum.map(order, fn name -> node_map[name] end)
  end

  def reorder_nodes(connections, node) do
    nodes = for c when c.to_node_param.node.name == node <- connections do c.from_node_param.node.name end
    if length(nodes) > 0 do
      nodes ++ for innode <- nodes, do: reorder_nodes(connections, innode)
    end
  end

  def build_modules(nodes, connections) do
    node_map = reorder_nodes(connections, nodes)
    |> Enum.map(fn node -> %{node | sc_id: build_module(node)} end)
    |> map_nodes_by_node_id()

    #
    # Here, we have to replace all the nodes in the connections with the newly updated nodes. Seems really
    # dorky, but I'm not sure how to get around it. Maybe this is a place to consider using ets or dets to
    # hold the nodes which the connections have pointers to.
    #
    Enum.map(connections, fn cnct ->
      %Modsynth.Connection{cnct |
                           from_node_param: %Modsynth.Node_Param{cnct.from_node_param |
                                                                 node: node_map[cnct.from_node_param.node.node_id]},
                           to_node_param: %Modsynth.Node_Param{cnct.to_node_param |
                                                                 node: node_map[cnct.to_node_param.node.node_id]}}
    end)
    #
    # now, we can actually do the connections with the updated versions
    #
    |> Enum.map(fn connection -> connect_nodes(connection) end)
    |> Enum.filter(fn connection -> is_external_control(connection.from_node_param.node.name)  end)
    |> Enum.map(fn connection -> handle_midi_connection(connection) end)
  end

  def handle_midi_connection(%Modsynth.Connection{
        from_node_param: %Modsynth.Node_Param{
          node: node}}) when node.name == "midi-in" do
    MidiInClient.start_midi(node.sc_id)
    node
  end

  def handle_midi_connection(%Modsynth.Connection{
        from_node_param: %Modsynth.Node_Param{
          node: from_node},
        to_node_param: %Modsynth.Node_Param{
            node: to_node}}) when from_node.name == "cc-in" and to_node.name == "gain" do
    MidiInClient.register_cc(2, from_node.sc_id, "in")
    MidiInClient.register_cc(7, from_node.sc_id, "in")
    from_node
  end

  def parse_connections(nodes, connections) do
    Enum.map(connections,
      fn [from, to] ->
        from_node_param = parse_connection_name(nodes, from)
        to_node_param = parse_connection_name(nodes, to)
        %Modsynth.Connection{from_node_param: from_node_param,
                             to_node_param: to_node_param,
                             bus_type: from_node_param.node.bus_type,
                             desc: from_node_param.node.name <> "_to_" <> to_node_param.node.name}
      end)
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
    [_node_name, id_spec] = String.split(s, ":")
    [ids, param] = String.split(id_spec, "-", parts: 2)
    id = String.to_integer(ids)
    node = nodes[id]
    %Modsynth.Node_Param{node: node, param_name: param}
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

  def connect_nodes(connection) do
    Logger.info("connect_nodes(#{inspect(connection)}")
    %Modsynth.Connection{from_node_param: from, to_node_param: to, desc: desc} = connection
    bus = get_bus(from.node.bus_type, desc)
    set_control(from.node.sc_id, from.param_name, bus)
    set_control(to.node.sc_id, to.param_name, bus)
    %Modsynth.Connection{connection | bus_id: bus}
  end

  def get_module(synths, name) do
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
      %Modsynth.Node{name: synth_name, parameters: synth_params, bus_type: bus_type}
    else 0
    end
  end

  def build_module(node) do
    %Modsynth.Node{name: synth_name, parameters: synth_params} = node
    id = make_module(synth_name, synth_params)
    Logger.info("build_module: #{synth_name} id #{id}")
    id
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
  #################################################################################

  def make_connection({from_node, from_param}, {to_node, to_param}, bus_type, desc) do
    %Modsynth.Connection{
      from_node_param: %Modsynth.Node_Param{node: from_node, param_name: from_param},
      to_node_param: %Modsynth.Node_Param{node: to_node, param_name: to_param},
      bus_type: bus_type,
      desc: desc
    }
  end

  def t1(synths) do
    audio_out = get_module(synths, "audio-out") |> build_module
    amp = get_module(synths, "amp") |> build_module
    saw = get_module(synths, "saw-osc") |> build_module
    note_freq = get_module(synths, "note-freq") |> build_module
    note = get_module(synths, "const") |> build_module
    gain = get_module(synths, "const") |> build_module

    connect_nodes(make_connection({gain, "val"}, {amp, "gain"}, :control, "c_to_gain"))
    connect_nodes(make_connection({note, "val"}, {note_freq, "note"}, :control, "c_to_note"))
    connect_nodes(make_connection({note_freq, "freq"}, {saw, "in" }, :control,"note_to_saw"))
    connect_nodes(make_connection({saw, "sig"}, {amp, "in" }, :audio, "saw_to_gain"))
    connect_nodes(make_connection({amp, "out"}, {audio_out, "b1" }, :audio, "gain_to_audio"))
    set_control(gain, "in", 0.1)
    %{:note => note, :gain => gain}
  end

  def t2(synths) do
    {audio_out, _, _} = get_module(synths, "audio-out") |> build_module
    {amp, _, _} = get_module(synths, "amp") |> build_module
    {saw, _, _} = get_module(synths, "saw-osc") |> build_module
    {note_freq, _, _} = get_module(synths, "note-freq") |> build_module
    {midi_in, _, _} = get_module(synths, "midi-in-note") |> build_module
    midi_pid = MidiInClient.start_midi(midi_in)
    {gain, _, _} = get_module(synths, "cc-in") |> build_module
    :ok = MidiInClient.register_cc(2, gain, "in")
    :ok = MidiInClient.register_cc(7, gain, "in")

    connect_nodes(make_connection({gain, "val"}, {amp, "gain"}, :control, "c_to_gain"))
    connect_nodes(make_connection({midi_in, "out"}, {note_freq, "note"}, :control, "c_to_note"))
    connect_nodes(make_connection({note_freq, "freq"}, {saw, "freq" }, :control,"note_to_saw"))
    connect_nodes(make_connection({saw, "sig"}, {amp, "in" }, :audio, "saw_to_gain"))
    connect_nodes(make_connection({amp, "out"}, {audio_out, "b1" }, :audio, "gain_to_audio"))
    set_control(gain, "in", 0.1)
    %{:midi_pid => midi_pid, :gain => gain}
  end

  def t3(synths) do
    {audio_out, _, _} = get_module(synths, "audio-out") |> build_module
    {amp, _, _} = get_module(synths, "amp") |> build_module
    {saw, _, _} = get_module(synths, "saw-osc") |> build_module
    {midi_in, _, _} = get_module(synths, "midi-in") |> build_module
    midi_pid = MidiInClient.start_midi(midi_in)
    {gain, _, _} = get_module(synths, "cc-cont-in") |> build_module
    :ok = MidiInClient.register_cc(2, gain, "in")
    :ok = MidiInClient.register_cc(7, gain, "in")

    connect_nodes(make_connection({gain, "val"}, {amp, "gain"}, :control, "c_to_gain"))
    connect_nodes(make_connection({midi_in, "freq"}, {saw, "freq" }, :control,"note_to_saw"))
    connect_nodes(make_connection({saw, "sig"}, {amp, "in" }, :audio, "saw_to_gain"))
    connect_nodes(make_connection({amp, "out"}, {audio_out, "b1" }, :audio, "gain_to_audio"))
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
