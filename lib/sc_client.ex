defmodule ScClient do
  require Logger
  @doc """
  things that work:
  encoded_message = OSC.encode("/quit", [24, 0])
  encoded_message = OSC.encode("/d_load", "synthdefs.void.scsyndef"])
  """

  @spec status() :: %{}
  def status() do
    GenServer.call(ScEm, :status)
    query_status_status()
  end

  @spec query_status_status() :: %{}
  def query_status_status() do
    case GenServer.call(ScEm, :status_status) do
      :pending -> query_status_status()
      val -> val
    end
  end

  @spec load_synths() :: :ok
  def load_synths() do
    load_synths("synthdefs/void.scsyndef")
  end

  @spec query_dir_status() :: :ok
  def query_dir_status() do
    case GenServer.call(ScEm, :load_dir_status) do
      :done -> :ok
      :pending -> query_dir_status()
    end
  end

  @spec load_synths(String.t) :: :ok
  def load_synths(dir) do
    GenServer.call(ScEm, {:load_dir, OSC.encode("/d_loadDir", [dir])})
    query_dir_status()
  end

  @spec make_sound(integer) :: integer
  def make_sound(synth) do
    id = GenServer.call(ScEm, :next_id)
    sendMsg({"/s_new", [synth, id, 0, 1, "freq", 220]})
    id
  end

  @spec midi_sound(any, any, float) :: integer
  def midi_sound(synth, note \\ 40, amp \\ 0.4) do
    id = GenServer.call(ScEm, :next_id)
    sendMsg({"/s_new", [synth, id, 0, 1, "note", note, "amp", amp]})
    id
  end

  @doc """
  synth is the synth name
  controls are a list of pairs where each is a control and a value which
  can be a bus number (in which case it'll probably be overwritten) or
  a constant, that might be used as is or might be overwritten.
  """
  @spec make_module(String.t, [any()]) :: integer
  def make_module(synth, controls) do
    id = GenServer.call(ScEm, :next_id)
    sendMsg({"/s_new", [synth, id, 0, 1] ++ List.flatten(controls)})
    id
  end

  @spec get_audio_bus(String.t) :: integer
  def get_audio_bus(name) do
    GenServer.call(ScEm, {:next_audio_bus, name})
  end

  @spec get_bus_val(integer) :: number
  def get_bus_val(bus) do
    GenServer.call(ScEm, {:get_bus_val, OSC.encode("/c_get", [bus]), bus})
    query_bus_val(bus)
  end

  @spec query_bus_val(integer) :: number
  def query_bus_val(bus) do
    case GenServer.call(ScEm, {:bus_val_status, bus}) do
      :pending -> query_bus_val(bus)
      val -> val
    end
  end

  @spec get_control_bus(String.t) :: integer
  def get_control_bus(name) do
    GenServer.call(ScEm, {:next_control_bus, name})
  end

  @spec set_control(integer, String.t, number) :: :ok
  def set_control(id, control, val) do
    # Logger.info("set control id #{id} control #{control} val #{val}")
    if (Logger.level() == :debug) and (control == "sig") do
      stacktrace = Process.info(self(), :current_stacktrace)
      IO.inspect(stacktrace)
    end

    sendMsg({"/n_set", [id, control, val]})
  end

  @spec get_control_val(integer, String.t) :: number
  def get_control_val(id, control) do
    GenServer.call(ScEm, {:get_control_val, OSC.encode("/s_get", [id, control]), id})
    query_control_val(id)
  end

  @spec query_control_val(integer) :: number
  def query_control_val(id) do
    case GenServer.call(ScEm, {:control_val_status, id}) do
      :pending -> query_control_val(id)
      val -> val
    end
  end

  @spec stop_sound(integer) :: :ok
  def stop_sound(id) do
    sendMsg({"/n_free", [id]})
  end

  @spec group_free(integer) :: :ok
  def group_free(id) do
    sendMsg({"/g_freeAll", [id]})
  end

  @spec quit() :: :ok
  def quit() do
    sendMsg({"/quit", [24, 0]})
  end

  @spec sendMsg({any, [any]}) :: :ok
  def sendMsg({cmd, args}) do
    GenServer.call(ScEm, {:send, OSC.encode(cmd, args)})
  end

  # def count_connections(node, connections) do
  #
  # end
end
