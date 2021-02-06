defmodule Modsynth.Bus do
  defstruct name: "", type: :control, id: 0
  @type t :: %__MODULE__{name: String.t, type: atom, id: integer}
end

defmodule ScEm.State do

  defstruct port: nil,
    ip: {nil,nil,nil,nil} ,
    handler: {nil, nil},
    socket: nil,
    next_id: 1001,
    status: %{},
    next_control_bus: 50,
    next_audio_bus: 15,
    bus_map: %{},
    load_dir_status: :pending
    # midi_module_id: 0,
    # amp_module_id: 0
  @type t :: %__MODULE__{port: integer,
                         ip: tuple,
                         handler: tuple,
                         socket: reference,
                         next_id: integer,
                         status: map,
                         next_control_bus: integer,
                         next_audio_bus: integer,
                         bus_map: map,
                         load_dir_status: atom
                         # midi_module_id: integer,
                         # amp_module_id: integer
  }
end

defmodule ScEm.Response do
  @doc ~S"""
  Struct for UDP response packet
  ip :: String.t
  fromport :: integer
  packet :: String.t
  """
  defstruct ip: nil, fromport: nil, packet: nil
  @type t :: %__MODULE__{ip: String.t, fromport: integer, packet: String.t}
end

defmodule ScEm do
  @doc """

  bugs: # status as it stands has a delay between when the request is made from SC and when SC returns the response. Makes it hard to get the value.

  """
  use Application
  use GenServer
  require OSC
  require Logger
  alias ScEm.State
  alias ScEm.Response

  @impl true
  def start(_type, _args) do
    ScEm.Supervisor.start_link(name: ScEm.Supervisor)
  end

  @impl true
  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def start_link(_dork) do
    {mod, fun} = Application.get_env :sc_em, :udp_handler, {__MODULE__, :default_handler}
    {ip, port} = {Application.get_env(:sc_em, :ip, {127,0,0,1}), Application.get_env(:sc_em, :port, 57110)}
    GenServer.start_link(__MODULE__, [%State{handler: {mod,fun}, ip: ip, port: port}], name: __MODULE__)
  end

  @impl true
  def init([%State{port: port} = state]) do
    require Logger
    {:ok, socket} = :gen_udp.open(port, [:binary, :inet,
                                         {:active, true},
                                        ])
    Logger.notice("listening on port #{port}")

    # uncomment to get status going
    schedule_status()


    {:ok, %{state | socket: socket}}
  end

  @impl true
  def terminate(_reason, %State{socket: socket} = state) when socket != nil do
    Logger.info("closing port #{state.port}")
    :ok = :gen_udp.close(socket)
  end

  @impl true
  def handle_call({:send, packet}, _from, %State{socket: socket, ip: ip, port: port} = state) do
    Logger.debug("sending = #{packet} to ip #{format_ip(ip)} port #{port}")
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
  def handle_call(:status, _from, state) do
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

  # @impl true
  # def handle_call({:start_midi, device, synth, synth_controls, amp, amp_controls}, _from, state) do
  #   {:ok, midi_pid} = PortMidi.open(:input, device)
  #   PortMidi.listen(midi_pid, self())
  #   module_id = ScClient.make_module(synth, synth_controls)
  #   amp_id = ScClient.make_module(amp, amp_controls)
  #   {:reply, {:ok, midi_pid, module_id, amp_id}, %{state | midi_module_id: module_id, amp_module_id: amp_id}}
  # end

  # @impl true
  # def handle_call({:stop_midi, midi_pid}, _from, state) do
  #   :ok = PortMidi.close(:input, midi_pid)
  #   {:reply, :ok, %{state | midi_module_id: 0}}
  # end

  @impl true
  def handle_info(:timed_status, %State{socket: socket, ip: ip, port: port} = state) do
    :gen_udp.send(socket, ip, port, OSC.encode("/status", []))
    schedule_status()
    {:noreply, state}
  end

  @impl true
  def handle_info({:udp, socket, ip, fromport, packet}, %State{socket: socket, handler: {mod, fun}} = state) do
    try do
      {f, l} = OSC.decode(packet)
      case f do
        "/status.reply" ->
          {:noreply, %{state | status: form_status(l)}}
        "/done" ->
          {:noreply, %{state | load_dir_status: :done}}
        _ ->
          apply mod, fun, [%Response{ip: format_ip(ip), fromport: fromport, packet: String.trim(packet)}]
          {:noreply, state}
      end
    rescue
      MatchError -> {:noreply, state}
    end
  end

  # @impl true
  # def handle_info({_pid, [{{status, note, vel}, _timestamp}]}, %State{midi_module_id: module_id, amp_module_id: amp_id} = state) do
  #   #Logger.info("midi status #{Integer.to_string(status, 16)} event #{note} val #{vel}")
  #   cond do
  #       (status >= 0x80) && (status < 0x90) ->
  #         Logger.warn("unexpected noteoff message")

  #       (status >= 0x90) && (status < 0xA0) ->
  #       if module_id != 0 do
  #         ScClient.set_control(module_id, "note", note)
  #         ScClient.set_control(amp_id, "gain", vel)
  #       end

  #       (status >= 0xA0) && (status < 0xB0) ->
  #         Logger.warn("unexpected polyphonic touch message")

  #       (status >= 0xB0) && (status < 0xC0) ->
  #       if module_id != 0 do
  #         case note do
  #           0x2 -> ScClient.set_control(amp_id, "gain", vel)
  #           _ -> Logger.info("cc message #{Integer.to_string(note, 16)} val #{vel} not handled")
  #         end
  #       end

  #       (status >= 0xC0) && (status < 0xD0) ->
  #         Logger.info("pc message #{Integer.to_string(note, 16)} val #{vel} not handled")# program_change

  #       (status >= 0xD0) && (status < 0xE0) ->
  #         Logger.warn("unexpected aftertouch_message")

  #       (status >= 0xE0) && (status < 0xF0) ->
  #         Logger.warn("unexpected pitch_wheel_message")

  #       status == 0xF0 ->
  #         Logger.warn("unexpected sysex_message")
  #    end
  #   {:noreply, state}
  # end

  # def handle_info({_pid, stuff}, state) do
  #   Logger.info("stuff #{inspect(stuff)}")
  #   {:noreply, state}
  # end

  defp schedule_status do
    Process.send_after(self(), :timed_status, 5000)
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

  def default_handler(%Response{} = response) do
    packet = response.packet
    {f, l} = OSC.decode(packet)
    Logger.notice("address: #{f} data = #{inspect(l)}")
  end

  #ip is passed as a tuple one int each octet {127,0,0,1}
  defp format_ip ({a, b, c, d}) do
    "#{a}.#{b}.#{c}.#{d}"
  end
end
