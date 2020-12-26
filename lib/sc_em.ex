defmodule ScEm.State do

  @doc ~S"""
  ScEm State:
  port :: integer
  count :: integer
  handler :: function
  socket :: %Socket
  """
  defstruct port: nil, ip: {nil,nil,nil,nil} ,handler: {nil, nil}, socket: nil, count: 0
  @type t :: %__MODULE__{port: integer, ip: tuple, handler: tuple, socket: reference, count: integer}
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
    {ip, port} = {Application.get_env(:sc_em, :ip, {127,0,0,1}), Application.get_env(:sc_em, :port, 1514)}
    GenServer.start_link(__MODULE__, [%State{handler: {mod,fun}, ip: ip, port: port}], name: __MODULE__)
  end

  @impl true
  def init([%State{} = state]) do
    require Logger
    {:ok, socket} = :gen_udp.open(state.port, [:binary, :inet,
                                               {:ip, state.ip},
                                               {:active, true},
                                              {:reuseaddr, true}])
    {:ok, port} = :inet.port(socket)
    Logger.info("listening on port #{port}")
    #update state
    {:ok, %{state | socket: socket, port: port}}
  end

  @impl true
  def terminate(_reason, %State{socket: socket} = state) when socket != nil do
    Logger.info("closing port #{state.port}")
    :ok = :gen_udp.close(socket)
  end

  def count(pid) do
    GenServer.call(pid, :count)
  end

  @impl true
  def handle_call(:count, _from, state) do
    {:reply, state.count, state}
  end

  @impl true
  def handle_call(:stop, _from, status) do
    {:stop, :normal, status}
  end

  @impl true
  def handle_info({:udp, socket, ip, fromport, packet}, %State{socket: socket, handler: {mod, fun}} = state) do
    new_count = state.count + 1
    apply mod, fun, [%Response{ip: format_ip(ip), fromport: fromport, packet: String.trim(packet)}]
    {:noreply, %State{state | count: new_count}}
  end


  def default_handler(%Response{} = response) do
    Logger.debug("#{response.ip}:#{response.fromport} #{response.packet}")
    packet = response.packet
    {f, l} = OSC.decode(packet)
    Logger.info("address: #{f} data = #{inspect(l)}")
  end

  #ip is passed as a tuple one int each octet {127,0,0,1}
  defp format_ip ({a, b, c, d}) do
    "#{a}.#{b}.#{c}.#{d}"
  end
end
