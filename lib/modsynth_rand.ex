defmodule Modsynth.Rand.State do
  defstruct last_note: 0,
    last_rhythm: 0,
    note_control: 0,
    bpm: 240,
    scale: []
  @type t :: %__MODULE__{last_note: integer,
                         last_rhythm: integer,
                         note_control: integer,
                         bpm: integer,
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

  def set_bpm(pid, bpm) do
    GenServer.call(pid, {:set_bpm, bpm})
  end

  def get_bpm(pid) do
    GenServer.call(pid, :get_bpm)
  end

  def next(pid) do
    GenServer.call(pid, :next)
  end

  def stop() do
    stop(Modsynth.Rand)
    ScClient.group_free(1)
  end

  def get_scale({key, scale_type}) do
    f = case scale_type do
      :pent -> &MusicPrims.pent_scale/2
      :major -> &MusicPrims.major_scale/2
      :minor -> &MusicPrims.minor_scale/2
    end
    MusicPrims.scale_seq(key, 4, f)
  end

  def play(file, scale \\ {:D, :pent}, bpm \\ 240) do
    pid = start()
    set_scale(pid, get_scale(scale))
    controls = Modsynth.play(file)
    {_, note, _, _, _} = Enum.find(controls, fn {_, _, _, _, control} -> control == :note end)
    # Logger.info("note control: #{note}")
    GenServer.call(pid, {:set_note_control, note})
    {first_note, first_dur} = next(pid)
    # Logger.info("first note #{first_note} first dur #{first_dur}")
    ScClient.set_control(note, "in", first_note)
    set_bpm(pid, bpm)
    schedule_next_note(pid, first_dur, bpm)
    {pid, controls}
  end


  defp schedule_next_note(pid, dur, bpm) do
    Process.send_after(pid, :next_note, dur * floor(1000 * 60 / bpm))
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
    ScClient.group_free(1)
    {:stop, :normal, status}
  end

  @impl true
  def handle_call({:set_scale, scale}, _from, state) do
    first_note = Enum.at(scale,:rand.uniform(length(scale)))
    {:reply, :ok, %State{state | scale: scale, last_note: first_note}}
  end

  @impl true
  def handle_call({:set_note_control, control}, _from, state) do
    {:reply, :ok, %State{state | note_control: control}}
  end

  @impl true
  def handle_call({:set_bpm, bpm}, _from, state) do
    {:reply, :ok, %State{state | bpm: bpm}}
  end

  @impl true
  def handle_call(:get_bpm, _from, %State{bpm: bpm} = state) do
    {:reply, bpm, state}
  end

  @impl true
  def handle_call(:next, _from, %State{last_note: last_note,
                                       scale: scale} = state) do
    next_note = Modsynth.Rand.rand(last_note, scale)
    next_rhythm = rhythm()
    {:reply, {next_note, next_rhythm}, %State{state | last_note: next_note, last_rhythm: next_rhythm}}
  end

  @impl true
  def handle_info(:next_note, %State{last_note: last_note,
                                     scale: scale,
                                     note_control: note,
                                     bpm: bpm} = state) do
    next_note = Modsynth.Rand.rand(last_note, scale)
    next_rhythm = rhythm()
    ScClient.set_control(note, "in", next_note)
    schedule_next_note(self(), next_rhythm, bpm)
    {:noreply, %State{state | last_note: next_note, last_rhythm: next_rhythm}}
  end

  
  def closest(note, scale) do
    index = Enum.find_index(scale, fn x -> x > note end)
    if is_nil(index) do
      len = length(scale)
      pos = :rand.uniform(floor(len / 4))
      if note < List.first(scale) do
        Enum.at(scale, pos)
      else
        Enum.at(scale, len - pos)
      end
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
