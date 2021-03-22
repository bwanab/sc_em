defmodule Modsynth.Bus do
  defstruct name: "", type: :control, id: 0
  @type t :: %__MODULE__{name: String.t, type: atom, id: integer}
end

defmodule ScEm.State do

  defstruct port: nil,
    ip: {nil,nil,nil,nil} ,
    socket: nil,
    next_id: 1001,
    status: %{},
    next_control_bus: 50,
    next_audio_bus: 15,
    bus_map: %{},
    load_dir_status: :pending,
    bus_val_status: %{},
    control_val_status: %{}
    # midi_module_id: 0,
    # amp_module_id: 0
  @type t :: %__MODULE__{port: integer,
                         ip: tuple,
                         socket: reference,
                         next_id: integer,
                         status: map,
                         next_control_bus: integer,
                         next_audio_bus: integer,
                         bus_map: map,
                         load_dir_status: atom,
                         bus_val_status: map,
                         control_val_status: map
                         # midi_module_id: integer,
                         # amp_module_id: integer
  }
end

defmodule ScEm do
  @doc """
  """
  use Application
  use GenServer
  require OSC
  require Logger
  alias ScEm.State

  @impl true
  def start(_type, _args) do
    ScEm.Supervisor.start_link(name: ScEm.Supervisor)
  end

  @impl true
  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def start_link(_dork) do
    {ip, port} = {Application.get_env(:sc_em, :ip, {127,0,0,1}), Application.get_env(:sc_em, :port, 57110)}
    GenServer.start_link(__MODULE__, [%State{ip: ip, port: port}], name: __MODULE__)
  end

  @impl true
  def init([state]) do
    require Logger
    {:ok, socket} = :gen_udp.open(0, [:binary, :inet,
                                      {:active, true},
                                     ])
    Logger.notice("listening on socket #{inspect(socket)}")

    {:ok, %{state | socket: socket}}
  end

  @impl true
  def terminate(_reason, %State{socket: socket} = state) when socket != nil do
    Logger.info("closing port #{state.port}")
    :ok = :gen_udp.close(socket)
  end

  @impl true
  def handle_call({:send, packet}, _from, %State{socket: socket, ip: ip, port: port} = state) do
    # Logger.info("sending = #{packet} to ip #{inspect(ip)} port #{port} from #{inspect(socket)}")
    response = :gen_udp.send(socket, ip, port, packet)
    {:reply, response, state}
  end

  @impl true
  def handle_call({:get_bus_val, packet, bus}, _from,
    %State{socket: socket, ip: ip, port: port, bus_val_status: bus_val_status} = state) do
    # Logger.debug("sending = #{packet} to ip #{format_ip(ip)} port #{port}")
    response = :gen_udp.send(socket, ip, port, packet)
    {:reply, response, %{state | bus_val_status: Map.put(bus_val_status, bus, :pending)}}
  end

  @impl true
  def handle_call({:bus_val_status, bus}, _from, %State{bus_val_status: status} = state) do
    {:reply, status[bus], state}
  end

  @impl true
  def handle_call({:get_control_val, packet, id}, _from,
    %State{socket: socket, ip: ip, port: port, control_val_status: control_val_status} = state) do
    # Logger.debug("sending = #{packet} to ip #{format_ip(ip)} port #{port}")
    response = :gen_udp.send(socket, ip, port, packet)
    {:reply, response, %{state | control_val_status: Map.put(control_val_status, id, :pending)}}
  end

  @impl true
  def handle_call({:control_val_status, id}, _from, %State{control_val_status: status} = state) do
    {:reply, status[id], state}
  end

  @impl true
  def handle_call({:load_dir, packet}, _from, %State{socket: socket, ip: ip, port: port} = state) do
    # Logger.debug("sending = #{packet} to ip #{inspect(ip)} port #{port}")
    response = :gen_udp.send(socket, ip, port, packet)
    {:reply, response, %{state | load_dir_status: :pending}}
  end

  @impl true
  def handle_call(:next_id, _from, %State{next_id: next_id} = state) do
    {:reply, next_id, %{state | next_id: next_id + 1}}
  end

  @doc """
  At some point we'll need to reuse old bus numbers which will mean scaning the currently used
  ones and reassigning.
  """
  @impl true
  def handle_call({:next_control_bus, name}, _from, %State{next_control_bus: next_control_bus} = state) do
    bus = %Modsynth.Bus{name: name, type: :control, id: next_control_bus}
    {:reply, next_control_bus,
     %{state |
       next_control_bus: next_control_bus + 1,
       bus_map: Map.put(state.bus_map, name, bus)}}
  end

  @impl true
  def handle_call({:next_audio_bus, name}, _from, %State{next_audio_bus: next_audio_bus} = state) do
    bus = %Modsynth.Bus{name: name, type: :audio, id: next_audio_bus}
    {:reply, next_audio_bus,
     %{state |
       next_audio_bus: next_audio_bus + 1,
       bus_map: Map.put(state.bus_map, name, bus)}}
  end

  @impl true
  def handle_call({:get_bus_info, name}, _from, %State{bus_map: bus_map} = state) do
    bus = Map.get(bus_map, name)
    {:reply, bus, state}
  end

  @impl true
  def handle_call(:status, _from, %State{socket: socket, ip: ip, port: port} = state) do
    :gen_udp.send(socket, ip, port, OSC.encode("/status", []))
    {:reply, :ok, %{state | status: :pending}}
  end

  @impl true
  def handle_call(:status_status, _from, state) do
    %State{status: status} = state
    {:reply, status, state}
  end

  @impl true
  def handle_call(:load_dir_status, _from, state) do
    %State{load_dir_status: status} = state
    {:reply, status, state}
  end

  @impl true
  def handle_call(:stop, _from, status) do
    {:stop, :normal, status}
  end


  @impl true
  def handle_info({:udp, socket, _ip, _fromport, packet}, %State{socket: socket, bus_val_status: bus_val_status, control_val_status: control_val_status} = state) do
    try do
      {f, l} = OSC.decode(packet)
      case f do
        "/status.reply" ->
          {:noreply, %{state | status: form_status(l)}}
        "/done" ->
          {:noreply, %{state | load_dir_status: :done}}
        "/c_set" ->
          [bus, val] = l
          {:noreply, %{state | bus_val_status: Map.put(bus_val_status, bus, val)}}
        "/n_set" ->
          [id, _control, val] = l
          {:noreply, %{state | control_val_status: Map.put(control_val_status, id, val)}}
        _ ->
          Logger.notice("address: #{f} data = #{inspect(l)}")
          {:noreply, state}
      end
    rescue
      MatchError -> {:noreply, state}
    end
  end

  def form_status([_,n_ugens,n_synths,n_groups,n_syndefs,avg_cpu,peak_cpu,nom_sample_rate,act_sample_rate]) do
    %{
      :n_ugenss => n_ugens,
      :n_synths => n_synths,
      :n_groups => n_groups,
      :n_syndefs => n_syndefs,
      :avg_cpu => avg_cpu,
      :peak_cpu => peak_cpu,
      :nom_sample_rate => nom_sample_rate,
      :act_sample_rate => act_sample_rate
    }
  end

end
