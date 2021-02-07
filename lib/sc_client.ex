defmodule ScClient do
  require Logger
  @doc """
  things that work:
  encoded_message = OSC.encode("/quit", [24, 0])
  encoded_message = OSC.encode("/d_load", "synthdefs.void.scsyndef"])
  """

  def status() do
    GenServer.call(ScEm, :status)
  end

  def load_synths() do
    sendMsg({"/d_load", ["synthdefs/void.scsyndef"]})
    query_status()
  end

  def query_status() do
    case GenServer.call(ScEm, :load_dir_status) do
      :done -> :ok
      :pending -> query_status()
    end
  end

  def load_synths(dir) do
    sendMsg({"/d_loadDir", [dir]})
  end

  def make_sound(synth) do
    id = GenServer.call(ScEm, :next_id)
    sendMsg({"/s_new", [synth, id, 0, 1, "freq", 220]})
    id
  end

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
  def make_module(synth, controls) do
    id = GenServer.call(ScEm, :next_id)
    sendMsg({"/s_new", [synth, id, 0, 1] ++ List.flatten(controls)})
    id
  end

  def get_audio_bus(name) do
    GenServer.call(ScEm, {:next_audio_bus, name})
  end

  def get_control_bus(name) do
    GenServer.call(ScEm, {:next_control_bus, name})
  end

  def set_control(id, control, val) do
    # Logger.info("set control id #{id} control #{control} val #{val}")
    sendMsg({"/n_set", [id, control, val]})
  end

  def stop_sound(id) do
    sendMsg({"/n_free", [id]})
  end

  def quit() do
    sendMsg({"/quit", [24, 0]})
  end

  def sendMsg({cmd, args}) do
    GenServer.call(ScEm, {:send, OSC.encode(cmd, args)})
  end
end
