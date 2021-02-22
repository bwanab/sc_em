defmodule Modsynth.Node do
  defstruct name: "",
    parameters: [],
    bus_type: :audio,
    node_id: 0,
    val: nil,
    control: false,
    sc_id: 1001
  @type t :: %__MODULE__{name: String.t,
                         parameters: list,
                         bus_type: atom,
                         node_id: integer,
                         val: float,
                         control: atom,
                         sc_id: integer
  }
end

defmodule Modsynth.Node_Param do
  defstruct node_id: 0,
    param_name: ""
  @type t :: %__MODULE__{node_id: integer,
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
  alias Modsynth.Node
  alias Modsynth.Node_Param
  alias Modsynth.Connection

  @doc """
  play an instrument definition file. There are several in the examples directory.
  """
  def play(fname) do
    ScClient.group_free(1)
    MidiInClient.stop_midi()
    init()
    |> read_file(fname)
    |> build_modules
  end

  def look(fname) do
    init()
    |> read_file(fname)
    |> visualize
  end

  def visualize({nodes, connections}) do
    terminal_node = List.first(reorder_nodes(connections, nodes))
    params = Enum.reduce(terminal_node.parameters, "", fn [name, _], acc -> name <> " " <> acc  end)
    build_visualization(terminal_node, connections, "to #{params}")
    # |> unroll_tree(0)
  end

  def build_visualization(node, connections, params) do
    connects_from = Enum.filter(connections, fn c -> c.to_node_param.node.node_id == node.node_id end)
    |> Enum.uniq_by(fn c -> c.from_node_param.node.node_id end)
    [{node.name, node.node_id, params}] ++ Enum.map(connects_from, fn c ->
      connect_points = "from #{c.from_node_param.param_name} to #{c.to_node_param.param_name}"
      build_visualization(c.from_node_param.node, connections, connect_points)
    end)
  end


  @blank "                                         "
  @doc """
  A really crappy ciruit display :(
  """
  def unroll_tree([fst|rest], n) when length(rest) == 0 do
    label = "#{String.slice(@blank, 0..(4*(10 - n))-10)} #{inspect(fst)} #{n}"
    Logger.info(label)
    n
  end

  def unroll_tree([fst|rest], n) do
    Enum.map(rest, fn t -> unroll_tree(t, n+1) end)
    unroll_tree([fst], n+1)
    n+1
  end

  def init() do
    MidiIn.start(0,0)
    ScClient.group_free(1)
    ScClient.load_synths(Application.get_env(:sc_em, :remote_synth_dir))
    Process.sleep(2000)  # should be a better way to do this!
    get_synth_vals(Application.get_env(:sc_em, :local_synth_dir))
  end

  def atom_or_nil(s) when is_nil(s) do nil end
  def atom_or_nil(s) do String.to_atom(s) end

  @doc """
  read a stored modsynth circuit spec file, create the modules and make the connections

  returns a list of the external controls other than midi in or audio in
  """
  def read_file(synths, fname) do
      {:ok, d} = File.read(fname)
      {:ok, ms} = Jason.decode(d)

      node_specs = Enum.map(ms["nodes"],
        fn x -> {x["id"], Enum.map(x,
                    fn {k, v} -> {String.to_atom(k), if k == "control" do atom_or_nil(v) else v end} end) |> Enum.into(%{})} end)
      |> Enum.into(%{})

      nodes = Enum.map(Map.keys(node_specs),
        fn k -> {k, get_module(synths, node_specs[k].name), node_specs[k]} end)
        |> Enum.map(fn {k, node, specs} -> {k, %{node | node_id: k, val: specs.val,
                                                control: specs.control}} end)
        |> Enum.into(%{})
      connections = parse_connections(nodes, ms["connections"])
      {nodes, connections}
  end

  def map_nodes_by_node_id(nodes) do
    Enum.map(nodes, fn node ->
      %{node_id: node_id} = node
      {node_id, node}
    end)
    |> Enum.into(%{})
  end

  @doc """
  The order in which the synths are built matters to supercollider. In general, the
  closest to the output must be built first, the the next closest and so-on.

  This function does the proper ordering.
  """
  def reorder_nodes(connections, nodes) when is_list(nodes) do
    audio_out = Enum.find(nodes, fn node -> node.name == "audio-out" end).node_id
    order = [audio_out] ++ List.flatten(reorder_nodes(connections, audio_out))
    |> Enum.reject(&is_nil/1) |> Enum.reverse |> Enum.uniq |> Enum.reverse   # remove_nils and dups
    node_map = map_nodes_by_node_id(nodes)
    Enum.map(order, fn id -> node_map[id] end)
  end

  def reorder_nodes(connections, node_id) do
    nodes = for c when c.to_node_param.node_id == node_id <- connections do c.from_node_param.node_id end
    if length(nodes) > 0 do
      nodes ++ for innode <- nodes, do: reorder_nodes(connections, innode)
    end
  end


  def build_modules({nodes, connections}) do
    node_map = reorder_nodes(connections, Map.values(nodes))
    |> Enum.map(fn node -> %{node | sc_id: build_module(node)} end)
    |> map_nodes_by_node_id()
    #
    # now, we can actually do the connections with the updated versions
    #
    connections
    |> Enum.map(fn connection -> connect_nodes(node_map, connection) end)
    |> Enum.filter(fn connection -> is_external_control(node_map[connection.from_node_param.node_id].name)  end)
    |> Enum.map(fn connection -> handle_midi_connection(node_map, connection) end)
    |> Enum.map(fn connection ->
      from_node = node_map[connection.from_node_param.node_id]
      {connection.desc, from_node.sc_id, Enum.at(from_node.parameters, 0), connection.to_node_param.param_name, from_node.control}
    end)
  end

  def handle_midi_connection(nodes, connection) do
    %Connection{
        from_node_param: %Node_Param{
          node_id: node_id}} = connection
    node = nodes[node_id]
    Logger.info("handle_midi_connection: #{node.name}")
    cond do
      node.control == :note ->
        # Logger.info("handle_midi_connection: #{node.sc_id}")
        param_name = node.parameters |> List.first |> List.first
        MidiInClient.start_midi(node.sc_id, param_name, &ScClient.set_control/3)
      node.control == :gain ->
        MidiInClient.register_cc(2, node.sc_id, "in")
        MidiInClient.register_cc(7, node.sc_id, "in")
        # ScClient.set_control(node.sc_id, "in", 0.1) # don't want to start too loud
      true -> 0
     end
    if !is_nil(node.val) do
      Logger.info("set_control(#{node.sc_id}, in, #{node.val})")
      ScClient.set_control(node.sc_id, "in", node.val)
    end
    connection
  end

  def parse_connections(nodes, connections) do
    Enum.map(connections,
      fn %{"from_node" => from, "to_node" => to} ->
        from_node_param = %Node_Param{node_id: from["id"], param_name: from["param_name"]}
        to_node_param = %Node_Param{node_id: to["id"], param_name: to["param_name"]}
        %Connection{from_node_param: from_node_param,
                    to_node_param: to_node_param,
                    bus_type: nodes[from["id"]].bus_type,
                    desc: nodes[from["id"]].name <> "_to_" <> nodes[to["id"]].name}
      end)
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
    ScClient.get_audio_bus(name)
  end

  def get_bus(ct, name)  when ct == :control do
    ScClient.get_control_bus(name)
  end

  def connect_nodes(nodes, connection) do
    %Connection{from_node_param: from, to_node_param: to, desc: desc} = connection
    from_node = nodes[from.node_id]
    to_node = nodes[to.node_id]
    bus = get_bus(from_node.bus_type, desc)
    ScClient.set_control(from_node.sc_id, from.param_name, bus)
    ScClient.set_control(to_node.sc_id, to.param_name, bus)
    c = %Connection{connection | bus_id: bus}
    Logger.info("connect_nodes #{desc}, #{from_node.sc_id}, #{inspect(List.first(from_node.parameters))} #{bus}")
    c
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
      %Node{name: synth_name, parameters: synth_params, bus_type: bus_type}
    else 0
    end
  end

  def build_module(node) do
    %Node{name: synth_name, parameters: synth_params} = node
    id = ScClient.make_module(synth_name, synth_params)
    Logger.info("build_module: #{synth_name} id #{id}")
    id
  end

  @doc """
  special purpose for "const" controls
  """
  def ctl(id, val) do
    ScClient.set_control(id, "val", val)
  end

  #################################################################################
  # test functions, should probably be in another module
  #################################################################################
  #################################################################################

  # def make_connection({from_node, from_param}, {to_node, to_param}, bus_type, desc) do
  #   %Connection{
  #     from_node_param: %Node_Param{node_id: from_node.id, param_name: from_param},
  #     to_node_param: %Node_Param{node_id: to_node.id, param_name: to_param},
  #     bus_type: bus_type,
  #     desc: desc
  #   }
  # end

  # def t1(synths) do
  #   audio_out = get_module(synths, "audio-out") |> build_module
  #   amp = get_module(synths, "amp") |> build_module
  #   saw = get_module(synths, "saw-osc") |> build_module
  #   note_freq = get_module(synths, "note-freq") |> build_module
  #   note = get_module(synths, "const") |> build_module
  #   gain = get_module(synths, "const") |> build_module

  #   connect_nodes(make_connection({gain, "val"}, {amp, "gain"}, :control, "c_to_gain"))
  #   connect_nodes(make_connection({note, "val"}, {note_freq, "note"}, :control, "c_to_note"))
  #   connect_nodes(make_connection({note_freq, "freq"}, {saw, "in" }, :control,"note_to_saw"))
  #   connect_nodes(make_connection({saw, "sig"}, {amp, "in" }, :audio, "saw_to_gain"))
  #   connect_nodes(make_connection({amp, "out"}, {audio_out, "b1" }, :audio, "gain_to_audio"))
  #   ScClient.set_control(gain, "in", 0.1)
  #   %{:note => note, :gain => gain}
  # end

  # def t2(synths) do
  #   {audio_out, _, _} = get_module(synths, "audio-out") |> build_module
  #   {amp, _, _} = get_module(synths, "amp") |> build_module
  #   {saw, _, _} = get_module(synths, "saw-osc") |> build_module
  #   {note_freq, _, _} = get_module(synths, "note-freq") |> build_module
  #   {midi_in, _, _} = get_module(synths, "midi-in-note") |> build_module
  #   midi_pid = MidiInClient.start_midi(midi_in, "note", &ScClient.set_control/3)
  #   {gain, _, _} = get_module(synths, "cc-in") |> build_module
  #   :ok = MidiInClient.register_cc(2, gain, "in")
  #   :ok = MidiInClient.register_cc(7, gain, "in")

  #   connect_nodes(make_connection({gain, "val"}, {amp, "gain"}, :control, "c_to_gain"))
  #   connect_nodes(make_connection({midi_in, "out"}, {note_freq, "note"}, :control, "c_to_note"))
  #   connect_nodes(make_connection({note_freq, "freq"}, {saw, "freq" }, :control,"note_to_saw"))
  #   connect_nodes(make_connection({saw, "sig"}, {amp, "in" }, :audio, "saw_to_gain"))
  #   connect_nodes(make_connection({amp, "out"}, {audio_out, "b1" }, :audio, "gain_to_audio"))
  #   ScClient.set_control(gain, "in", 0.1)
  #   %{:midi_pid => midi_pid, :gain => gain}
  # end

  # def t3(synths) do
  #   {audio_out, _, _} = get_module(synths, "audio-out") |> build_module
  #   {amp, _, _} = get_module(synths, "amp") |> build_module
  #   {saw, _, _} = get_module(synths, "saw-osc") |> build_module
  #   {midi_in, _, _} = get_module(synths, "midi-in") |> build_module
  #   midi_pid = MidiInClient.start_midi(midi_in, "note", &ScClient.set_control/3)
  #   {gain, _, _} = get_module(synths, "cc-cont-in") |> build_module
  #   :ok = MidiInClient.register_cc(2, gain, "in")
  #   :ok = MidiInClient.register_cc(7, gain, "in")

  #   connect_nodes(make_connection({gain, "val"}, {amp, "gain"}, :control, "c_to_gain"))
  #   connect_nodes(make_connection({midi_in, "freq"}, {saw, "freq" }, :control,"note_to_saw"))
  #   connect_nodes(make_connection({saw, "sig"}, {amp, "in" }, :audio, "saw_to_gain"))
  #   connect_nodes(make_connection({amp, "out"}, {audio_out, "b1" }, :audio, "gain_to_audio"))
  #   ScClient.set_control(gain, "in", 0.1)
  #   %{:midi_pid => midi_pid, :gain => gain}
  # end

  # def tt() do
  #   #MidiIn.start(0,0)
  #   synths = init()
  #   Process.sleep(2000)
  #   t3(synths)
  # end


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
