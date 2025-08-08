defmodule Modsynth.Node do
  @derive Jason.Encoder
  defstruct name: "",
            parameters: [],
            bus_type: :audio,
            node_id: 0,
            val: nil,
            control: false,
            sc_id: 1001,
            x: 0,
            y: 0

  @type t :: %__MODULE__{
          name: String.t(),
          parameters: list,
          bus_type: atom,
          node_id: integer,
          val: float,
          control: atom,
          sc_id: integer,
          x: integer,
          y: integer
        }
end

defmodule Modsynth.Node_Param do
  @derive Jason.Encoder
  defstruct node_id: 0,
            param_name: ""

  @type t :: %__MODULE__{node_id: integer, param_name: String.t()}
end

defmodule Modsynth.Connection do
  @derive Jason.Encoder
  defstruct from_node_param: %Modsynth.Node_Param{},
            to_node_param: %Modsynth.Node_Param{},
            bus_type: :audio,
            bus_id: 0,
            desc: ""

  @type t :: %__MODULE__{
          from_node_param: Modsynth.Node_Param,
          to_node_param: Modsynth.Node_Param,
          bus_type: atom,
          bus_id: integer,
          desc: String.t()
        }
end

defmodule Modsynth.InputControl do
  defstruct node_id: 0,
            sc_id: 0,
            control_name: "",
            midi_control: nil

   @type t :: %__MODULE__{
            sc_id: integer(),
            node_id: integer(),
            control_name: String.t(),
            midi_control: atom() | nil
   }
end

defmodule Modsynth do
  require Logger
  alias Modsynth.InputControl
  alias Modsynth.Node
  alias Modsynth.Node_Param
  alias Modsynth.Connection

  @external_controls [{"gain",  "gain"}, {"midi-in", "note"}, {"midi-in-note", "note"}] |> Enum.into(%{})

  @doc """
  play an instrument definition file. There are several in the examples directory.

  Returns 1. A list of input controls
          2. A map of node_number -> node
          3. A list of connections.
  """
  @spec play(String.t() | {%{required(integer) => Node}, [Connection], {float, float}}, String.t(), fun()) ::
          {[InputControl], %{required(integer) => Node}, [Connection]}
  def play(f, device \\ "AE-30", gate_register \\ &MidiInClient.register_gate/1)

  def play(fname, device, gate_register) when is_binary(fname) do
    ScClient.group_free(1)
    MidiInClient.stop_midi()

    {node_map, connections} =
      init()
      |> read_file(fname)
      |> build_modules(gate_register)

    {set_up_controls(node_map, device), node_map, connections}
  end

  def play(synth_data, device, gate_register) do
    ScClient.group_free(1)
    MidiInClient.stop_midi()

    {node_map, connections} = build_modules(synth_data, gate_register)
    {set_up_controls(node_map, device), node_map, connections}
  end

  @spec look(binary()) ::
          {%{optional(integer()) => Modsynth.Node}, [Modsynth.Connection], {float(), float()}}
  def look(fname) do
    init() |> read_file(fname)
  end

  @spec init() :: %{required(String.t()) => {[[]], Atom}}
  def init() do
    if Logger.level() == :debug do
      stacktrace = Process.info(self(), :current_stacktrace)
      IO.inspect(stacktrace)
    end

    MidiIn.start(0, 0)
    ScClient.group_free(1)
    ScClient.load_synths(Path.join(__DIR__, "../synthdefs/"))
    synth_vals = get_synth_vals(Path.join(__DIR__, "../synthdefs/"))
    path = Path.expand(Application.get_env(:sc_em, :local_synth_dir))
    local_synth_vals = if File.exists?(path) do
      {:ok, local_synths} = File.ls(path)
      if length(local_synths) > 0 do
        ScClient.load_synths(path)
        get_synth_vals(path)
      else
        %{}
      end
    else
      %{}
    end
    Map.merge(synth_vals, local_synth_vals)
  end

  def atom_or_nil(s) when is_nil(s) do
    nil
  end

  def atom_or_nil(s) do
    String.to_atom(s)
  end

  @doc """
  read a stored modsynth circuit spec file, create the modules and make the connections

  returns a list of the external controls other than midi in or audio in
  """
  @spec read_file(%{required(String.t()) => {[[]], Atom}}, String.t()) ::
          {%{required(integer) => Node}, [Connection], {float, float}} | {:error, String.t()}
  def read_file(synths, fname) do
    case File.read(fname) do
      {:error, reason} ->
        {:error, reason}

      {:ok, d} ->
        {:ok, ms} = Jason.decode(d)
        specs_to_data(synths, ms)
    end
  end

  def specs_to_data(synths, ms) do
      all_node_specs =
        Enum.map(ms["nodes"], fn x ->
              {x["id"],
              Enum.map(x, fn {k, v} ->
                  {String.to_atom(k), (if k == "control", do: atom_or_nil(v), else: v)}
                end
              )
              |> Enum.into(%{})}
          end
        )
        |> Enum.into(%{})


      node_specs = Enum.filter(all_node_specs, fn {_id, spec} -> not is_nil(Map.get(synths, spec.name)) end)
      |> Enum.into(%{})
      bad_node_specs = Enum.filter(all_node_specs, fn {_id, spec} -> is_nil(Map.get(synths, spec.name)) end)
      Enum.each(bad_node_specs, fn {_id, spec} -> Logger.debug("No such node: #{spec.name}") end)

      nodes =
        Enum.map(
          Map.keys(node_specs),
          fn k -> {k, get_module(synths, node_specs[k].name), node_specs[k]} end
        )
        |> Enum.map(fn {k, node, specs} ->
          {k, %{node | node_id: k, val: specs.val, control: specs.control, x: specs.x, y: specs.y}}
        end)
        |> Enum.into(%{})

      connections = parse_connections(nodes, ms["connections"])
      {nodes, connections, {ms["frame"]["width"], ms["frame"]["height"]}}
  end

  @spec map_nodes_by_node_id([Node]) :: %{required(integer) => Node}
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
  @spec reorder_nodes([Connection], [Node]) :: [Node]
  def reorder_nodes(connections, nodes) when is_list(nodes) do
    audio_out = Enum.find(nodes, fn node -> node.name == "audio-out" end).node_id

    order =
      ([audio_out] ++ List.flatten(reorder_nodes(connections, audio_out)))
      # remove_nils and dups
      |> Enum.reject(&is_nil/1)
      |> Enum.reverse()
      |> Enum.uniq()
      |> Enum.reverse()

    node_map = map_nodes_by_node_id(nodes)
    Enum.map(order, fn id -> node_map[id] end)
  end

  @spec reorder_nodes([Connection], integer) :: [Node]
  def reorder_nodes(connections, node_id) do
    nodes =
      for c when c.to_node_param.node_id == node_id <- connections do
        c.from_node_param.node_id
      end

    if length(nodes) > 0 do
      nodes ++ for innode <- nodes, do: reorder_nodes(connections, innode)
    end
  end

  @spec build_modules({%{required(integer) => Node}, [Connection], {float, float}}, fun()) ::
          {%{required(integer) => Node}, [Connection]}
  def build_modules({nodes, connections, _}, gate_register) do
    node_map =
      reorder_nodes(connections, Map.values(nodes))
      |> Enum.map(fn node -> %{node | sc_id: build_module(node, gate_register)} end)
      |> map_nodes_by_node_id()

    full_connections =
      connections
      |> Enum.map(fn connection -> connect_nodes(node_map, connection) end)

    IO.inspect(node_map)
    {node_map, full_connections}
  end

  @spec set_up_controls(%{required(integer) => Node}, String.t()) :: [InputControl]
  def set_up_controls(node_map, device) do
    node_map
    |> Enum.filter(fn {_id, node} ->
      is_external_control(node.name)
    end)
    |> Enum.map(fn {_id, node} -> handle_midi_connection(node, device) end)
    |> Enum.map(fn node ->
      %InputControl{node_id: node.node_id,
                    sc_id: node.sc_id,
                    control_name: Map.get(@external_controls, node.name),
                    midi_control: node.control}
    end)
  end

  # def set_control({node, id}, name, val) do
  #   ScClient.set_control(id, name, val)
  #   if name == "gate" do
  #     delete_module(id)
  #     id = build_module(node, gate_register)
  #     node.sc_id = id # obviously this is where it breaks down. need to put that node back into the connections
  #   end
  # end

  @spec handle_midi_connection(%Node{}, String.t()) :: %Node{}
  def handle_midi_connection(node, device) do
    case Map.get(@external_controls, node.name) do
      "note" ->
        # Logger.info("handle_midi_connection: #{node.sc_id}")
        MidiInClient.start_midi(node.sc_id, "note", &ScClient.set_control/3, device)

      "gain" ->
        MidiInClient.register_cc(2, node.sc_id, "in")
        MidiInClient.register_cc(7, node.sc_id, "in")

      # ScClient.set_control(node.sc_id, "in", 0.1) # don't want to start too loud
      true ->
        0
    end

    if !is_nil(node.val) do
      # Logger.info("set_control(#{node.sc_id}, in, #{node.val})")
      ScClient.set_control(node.sc_id, "in", node.val)
    end

    node
  end

  @spec parse_connections(%{required(integer) => Node}, [Connection]) :: [Connection]
  def parse_connections(nodes, connections) do
    Enum.filter(connections,
      fn %{"from_node" => from, "to_node" => to} ->
        from_id = from["id"]
        to_id = to["id"]
        not is_nil(nodes[from_id]) and not is_nil(nodes[to_id])
      end)

    |> Enum.map(
      fn %{"from_node" => from, "to_node" => to} ->
        from_id = from["id"]
        to_id = to["id"]
        from_node_param = %Node_Param{node_id: from_id, param_name: from["param_name"]}
        to_node_param = %Node_Param{node_id: to_id, param_name: to["param_name"]}
        from_node = nodes[from_id]
        to_node = nodes[to_id]

        if is_nil(from_node) do
          Logger.error("looks like a node id mismatch with #{inspect(from)}")
        end

        if is_nil(to_node) do
          Logger.error("looks like a node id mismatch with #{inspect(to)}")
        end

        %Connection{
          from_node_param: from_node_param,
          to_node_param: to_node_param,
          bus_type: from_node.bus_type,
          desc: from_node.name <> "_to_" <> to_node.name
        }
      end
    )
  end



  @spec is_external_control(String.t()) :: boolean
  def is_external_control(name) do
    not is_nil(Map.get(@external_controls, name))
  end

  @doc """
  Reads the synthdef files from the specified directory to obtain their names and parameter specifications

  returns a list of synth specifications as a map indexed by the module name name => {parameters, out_bus_type}}
  e.g. "saw-osc" => {[["ib", 55.0], ["ob", 65.0]], :audio}
  """
  @spec get_synth_vals(String.t()) :: %{required(String.t()) => {[[]], Atom}}
  def get_synth_vals(dir) do
    File.ls!(dir)
    |> Enum.map(fn fname -> get_one_synth_vals(dir <> "/" <> fname) end)
    |> Enum.filter(fn s -> not is_nil(s) end)
    |> Enum.into(%{})
  end

  @spec get_one_synth_vals(String.t()) :: {String.t(), {[any()], :audio | :control}}
  def get_one_synth_vals(fname) do
    Logger.debug("get_one_synth_vals: #{fname}")
    synth = ReadSynthDef.read_file(fname) |> Map.get(:synth_defs) |> List.first()
    if is_nil(synth) do
      nil
    else
      synth_name = synth.name
      synth_vals = synth.parameter_vals

      synth_parameters =
        Enum.map(synth.parameter_names, fn {parm, order} -> [parm, Enum.at(synth_vals, order)] end)

      synth_out_type =
        case Enum.find(synth.ugens, fn x -> x.ugen_name == "Out" end).calc_rate do
          1 -> :control
          2 -> :audio
        end

      {synth_name, {synth_parameters, synth_out_type}}
    end
  end

  @spec get_bus(:audio | :control, String.t()) :: integer
  def get_bus(ct, name) when ct == :audio do
    ScClient.get_audio_bus(name)
  end

  def get_bus(ct, name) when ct == :control do
    ScClient.get_control_bus(name)
  end

  @spec connect_nodes(%{required(integer) => Node}, %Connection{}) :: %Connection{}
  def connect_nodes(nodes, connection) do
    %Connection{from_node_param: from, to_node_param: to, desc: desc} = connection
    # IO.inspect(connection)
    from_node = nodes[from.node_id]
    to_node = nodes[to.node_id]
    bus = get_bus(from_node.bus_type, desc)
    ScClient.set_control(from_node.sc_id, from.param_name, bus)
    ScClient.set_control(to_node.sc_id, to.param_name, bus)
    c = %Connection{connection | bus_id: bus}

    # Logger.info("connect_nodes #{desc}, #{from_node.sc_id}, #{inspect(List.first(from_node.parameters))} #{bus}")
    c
  end

  @spec get_module({[[]], Atom}, String.t()) :: %Node{} | 0
  def get_module(synths, name) do
    Logger.debug("get_module: #{name}")
    synth_name = name
    if synth_name != "" do
      {synth_params, bus_type} = synths[synth_name]
      %Node{name: synth_name, parameters: synth_params, bus_type: bus_type}
    else
      0
    end
  end

  @spec build_module(%Node{}, fun()) :: integer
  def build_module(%Node{name: synth_name, parameters: synth_params}, gate_register) do
    id = ScClient.make_module(synth_name, synth_params)

    if Enum.find(synth_params, &(List.first(&1) == "gate")) do
      Logger.info("register gated node: #{synth_name} id: #{id}")
      gate_register.(id)
    end

    id
  end

  def get_all_connection_values(connections) do
    Enum.map(connections, fn %{bus_id: bus_id, desc: desc} ->
      {bus_id, desc, ScClient.get_bus_val(bus_id)}
    end)
  end

  def get_all_control_values(node_map) do
    Enum.map(node_map, fn {_num, %Modsynth.Node{name: name, parameters: parameters, sc_id: sc_id}} ->
      {name,
      Enum.map(parameters, fn [parameter_name, _] ->
        {parameter_name, ScClient.get_control_val(sc_id, parameter_name)}
      end)}
    end)
  end

  def get_all_input_controls(controls) do
    Enum.map(controls, fn %InputControl{sc_id: sc_id, control_name: control_name} ->
      {sc_id, control_name, ScClient.get_control_val(sc_id, control_name)}
    end)
  end

  @doc """
  special purpose for "const" controls
  """
  def ctl(id, val) do
    ScClient.set_control(id, "val", val)
  end

  def trf(file) do
    synths = init()
    read_file(synths, file)
  end
end
