defmodule MidiIn.CC do
  defstruct cc_id: 0,
    cc_control: ""
  @type t :: %__MODULE__{cc_id: integer,
                         cc_control: String.t
  }
end

defmodule MidiIn.State do
  defstruct note_module_id: 0,
    note_control: "",
    cc_registry: %{},
    midi_pid: 0,
    bad_midi_messages: 0
  @type t :: %__MODULE__{note_module_id: integer,
                         note_control: String.t,
                         cc_registry: map,
                         midi_pid: integer,
                         bad_midi_messages: integer
  }
end



defmodule MidiIn do
  use Application
  use GenServer
  require Logger
  alias MidiIn.State

  @impl true
  def start(_type, _args) do
    MidiIn.Supervisor.start_link(name: MidiIn.Supervisor)
  end

  @impl true
  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def start_link(_nothing_interesting) do
    GenServer.start_link(__MODULE__, [%State{}], name: __MODULE__)
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
  def handle_call({:start_midi, device, synth, note_control}, _from, %State{midi_pid: old_pid} = state) do
    if old_pid != 0 do
      :ok = PortMidi.close(:input, old_pid)
    end
    {:ok, midi_pid} = PortMidi.open(:input, device)
    PortMidi.listen(midi_pid, self())
    Logger.info("device #{device}, synth #{synth}, note_control #{note_control}")
    {:reply, {:ok, midi_pid}, %{state | note_module_id: synth, note_control: note_control, midi_pid: midi_pid}}
  end

  @impl true
  def handle_call({:register_cc, cc_num, cc_id, cc_control}, _from, %State{cc_registry: cc_registry} = state) do
    Logger.info("cc_num #{cc_num} cc #{cc_id}, cc_control #{cc_control}")

    cc_specs = Map.get(cc_registry, cc_num, [])

    {:reply, :ok,
     %{state | cc_registry: Map.put(cc_registry, cc_num, cc_specs ++ [%MidiIn.CC{cc_id: cc_id, cc_control: cc_control}])}}
  end

  @impl true
  def handle_call({:stop_midi, midi_pid}, _from, state) do
    :ok = PortMidi.close(:input, midi_pid)
    {:reply, :ok, %{state | midi_pid: 0}}
  end


  @impl true
  def handle_info({_pid, messages}, state) do
    # Logger.info("midi_in messages #{inspect(messages)}")
    Enum.each(messages, &(process_message(&1, state)))
    {:noreply, state}
  end

  def process_message({{status, note, vel}, _timestamp}, state) do
    cond do
        (status >= 0x80) && (status < 0x90) ->
          Logger.warn("unexpected noteoff message")

        (status >= 0x90) && (status < 0xA0) ->
        if state.note_module_id != 0 do
          ScClient.set_control(state.note_module_id, state.note_control, note)
          #Logger.info("note #{note} vel #{vel} synth #{state.note_module_id} control #{state.note_control}")
        end

        (status >= 0xA0) && (status < 0xB0) ->
          Logger.warn("unexpected polyphonic touch message")

        (status >= 0xB0) && (status < 0xC0) ->
            cc_list = Map.get(state.cc_registry, note, 0)
            if cc_list == 0 do
              Logger.info("cc message #{Integer.to_string(note, 16)} val #{vel} not handled")
            else
              Enum.each(cc_list, fn %MidiIn.CC{cc_id: cc_id, cc_control: cc_control} ->
                ScClient.set_control(cc_id, cc_control, vel / 127)
              end)
            end

        (status >= 0xC0) && (status < 0xD0) ->
          Logger.info("pc message #{Integer.to_string(note, 16)} val #{vel} not handled")# program_change

        (status >= 0xD0) && (status < 0xE0) ->
          Logger.warn("unexpected aftertouch_message")

        (status >= 0xE0) && (status < 0xF0) ->
          Logger.warn("unexpected pitch_wheel_message")

        status == 0xF0 ->
          Logger.warn("unexpected sysex_message")
    end
  end
end
