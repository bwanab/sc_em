defmodule Modsynth.Rand.State do
  defstruct last_note: 0,
    last_rhythm: 0,
    scale: []
  @type t :: %__MODULE__{last_note: integer,
                         last_rhythm: integer,
                         scale: list
  }
end

defmodule Modsynth.Rand do
  use GenServer
  require Logger
  alias Modsynth.Rand.State

  def start_link(_nothing_interesting) do
    GenServer.start_link(__MODULE__, [%State{}], name: __MODULE__)
  end

  #######################
  # client code
  #######################

  def start() do
    case start_link(1) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def set_scale(pid, scale) do
    GenServer.call(pid, {:set_scale, scale})
  end

  def next(pid) do
    GenServer.call(pid, :next)
  end


  #######################
  # implementation
  #######################

  @impl true
  def init([state]) do
    {:ok, state}
  end

  @impl true
  def handle_call(:stop, _from, status) do
    {:stop, :normal, status}
  end

  @impl true
  def handle_call({:set_scale, scale}, _from, state) do
    first_note = Enum.at(scale,:rand.uniform(length(scale)))
    {:reply, :ok, %State{state | scale: scale, last_note: first_note}}
  end

  @impl true
  def handle_call(:next, _from, %State{last_note: last_note,
                                       scale: scale} = state) do
    next_note = Modsynth.Rand.rand(last_note, scale)
    next_rhythm = rhythm()
    {:reply, {next_note, next_rhythm}, %State{state | last_note: next_note, last_rhythm: next_rhythm}}
  end
  
  def closest(note, scale) do
    index = Enum.find_index(scale, fn x -> x > note end)
    if is_nil(index) do
      Enum.at(scale,:rand.uniform(length(scale)))
    else
      val1 = Enum.at(scale, index - 1)
      val2 = Enum.at(scale, index)
      if note - val1 < val2 - note do val1 else val2 end
    end
   end

  def rand(val, scale) do
    :rand.normal(val, 20.0)
    |> closest(scale)
  end

  def rhythm() do
    :rand.uniform(4)
  end

end
