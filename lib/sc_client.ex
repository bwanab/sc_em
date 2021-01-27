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
  end

  def load_synths(dir) do
    sendMsg({"/d_loadDir", [dir]})
  end

  def make_sound(synth) do
    id = GenServer.call(ScEm, :next_id)
    sendMsg({"/s_new", [synth, id, 0, 1, "freq", 220]})
    id
  end

  def midi_sound(synth, note \\ 40) do
    id = GenServer.call(ScEm, :next_id)
    sendMsg({"/s_new", [synth, id, 0, 1, "note", note]})
    id
  end

  def set_control(id, control, val) do
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
