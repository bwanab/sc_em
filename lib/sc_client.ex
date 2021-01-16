defmodule ScClient do
  require Logger
  """
  things that work:
  encoded_message = OSC.encode("/quit", [24, 0])
  encoded_message = OSC.encode("/d_load", "synthdefs.void.scsyndef"])
  """

  @port 57110

  def open() do
    :gen_udp.open(@port, [:binary, {:active, false}])
  end


  def t(socket) do
    encoded_message = OSC.encode("/quit", [24, 0])
    IO.inspect(encoded_message)
    :gen_udp.send(socket, {192,168,4,39}, @port, encoded_message)
    {:ok, {_ip, _port, msg}} = :gen_udp.recv(socket, 0, 5000)
    IO.inspect(OSC.decode(msg))
    # Logger.info("ip = #{ip} port = #{port} #{msg}")

    # :gen_udp.send(socket, {192,168,4,39}, 57110,
    #   OSC.encode("/n_set", [1001, "defpath", "/home/bill/src/sc/examples/synthdefs/sine.scsyndef"]))
    # {:ok, {ip, port, msg}} = :gen_udp.recv(socket, 0)
    # Logger.info("ip = #{ip} port = #{port} #{msg}")

    # :gen_udp.send(socket, {192,168,4,39}, 57110,
    #   OSC.encode("/d_load", ["/home/bill/src/sc/examples/synthdefs/sine.scsyndef"]))
    # {:ok, {ip, port, msg}} = :gen_udp.recv(socket, 0)
    # Logger.info("ip = #{ip} port = #{port} #{msg}")

    # :gen_udp.send(socket, {192,168,4,39}, 57110,
    #   OSC.encode("/s_new", ["sine", 1001, 1, 0]))
    # {:ok, {ip, port, msg}} = :gen_udp.recv(socket, 0)
    # Logger.info("ip = #{ip} port = #{port} #{msg}")
end

  """
  This depends on having a SynthDef named quick1 previously defined and stored
  in supercollider.
  """
  def make_sound(socket) do
    create = OSC.encode("/s_new", ["quick1", 1001, 1, 0])
    :gen_udp.send(socket, {192,168,4,39}, @port, create)
    # :gen_udp.recv(socket, 0)
  end

  def stop_sound(socket) do
    stop = OSC.encode("/n_free", [1001])
    :gen_udp.send(socket, {192,168,4,39}, @port, stop)
    # :gen_udp.recv(socket, 0)
  end

end
