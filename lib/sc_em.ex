defmodule ScEm.State do

  @doc ~S"""
  ScEm State:
  port :: integer
  handler :: function
  socket :: %Socket
  next_id :: integer
  status :: map
  """
  defstruct port: nil, ip: {nil,nil,nil,nil} ,handler: {nil, nil}, socket: nil, next_id: 1001, status: %{}
  @type t :: %__MODULE__{port: integer, ip: tuple, handler: tuple, socket: reference, next_id: integer, status: map}
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
    {:reply, response, state}
  end

  @impl true
  def handle_call(:next_id, _from, %State{next_id: next_id} = state) do
    {:reply, next_id, %{state | next_id: next_id + 1}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    %State{status: status} = state
    {:reply, status, state}
  end

  @impl true
  def handle_call(:stop, _from, status) do
    {:stop, :normal, status}
  end

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
        _ ->
          apply mod, fun, [%Response{ip: format_ip(ip), fromport: fromport, packet: String.trim(packet)}]
          {:noreply, state}
      end
    rescue
      MatchError -> {:noreply, state}
    end
  end

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
