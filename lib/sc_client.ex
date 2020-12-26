defmodule ScClient do
  def t() do
    {:ok, socket} = :gen_udp.open(57110, [{:reuseaddr, true}])
    m = OSC.encode("/s_new", ["has", "stuff", 1, 3.4])
    :gen_udp.send(socket, {127,0,0,1}, 57110, m)
  end
end
