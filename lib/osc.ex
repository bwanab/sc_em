defmodule OSC do
  require Logger
  # import Bitwise

  @spec find0(binary, binary, [<<_::8>>]) :: [<<_::8>>]
  defp find0(cl, c, r) do
    <<f::binary-size(1), l::binary>> = cl

    if f == c do
      r
    else
      find0(l, c, [f | r])
    end
  end

  @spec find(binary, binary) :: binary
  defp find(s, c) do
    String.reverse(List.to_string(find0(s, c, [])))
  end

  @spec read_string(binary) :: {binary, binary}
  def read_string(s) do
    res = find(s, <<0>>)
    length = String.length(res)
    new_index = ceil((length + 1) / 4.0) * 4
    # Logger.debug("new_index = #{new_index}")
    {res, String.slice(s, new_index..-1)}
  end

  @spec write_string(binary) :: binary
  def write_string(s) do
    length = String.length(s)
    new_index = ceil((length + 1) / 4.0) * 4
    pad = new_index - length - 1

    s <>
      List.to_string(
        for _n <- 0..pad do
          "\0"
        end
      )
  end

  @spec read_int(binary) :: {integer, binary}
  def read_int(s) do
    length = String.length(s)

    if length < 4 do
      # Logger.debug("Error: too few bytes for int #{s} #{length}")
      {0, <<>>}
    else
      bin = oslice4(s)
      # Logger.debug("bin = #{inspect(bin)}")
      <<res::big-integer-32>> = bin
      {res, String.slice(s, 4..-1)}
    end
  end

  @spec write_int(integer) :: binary
  def write_int(i) do
    <<i::big-integer-32>>
  end

  @spec read_double(binary) :: {float, binary}
  def read_double(s) do
    length = String.length(s)

    if length < 8 do
      # Logger.debug("Error: too few bytes for double #{s} #{length}")
      {0.0, <<>>}
    else
      # bin = String.slice(s, 0..7)
      bin = oslice8(s)
      # Logger.debug("double bin = #{inspect(bin)}")
      <<res::float>> = bin
      {res, String.slice(s, 8..-1)}
    end
  end

  @spec write_double(float) :: binary
  def write_double(d) do
    <<d::float>>
  end

  @spec read_float(binary) :: {float, binary}
  def read_float(s) do
    length = String.length(s)

    if length < 4 do
      Logger.info("Error: too few bytes for double #{s} #{length}")
      {0.0, <<>>}
    else
      # bin = String.slice(s, 0..3)
      bin = oslice4(s)
      # Logger.debug("float bin = #{inspect(bin)}")
      <<res::float-size(32)>> = bin
      {res, String.slice(s, 4..-1)}
    end
  end

  @spec write_float(float) :: binary
  def write_float(f) do
    <<f::float-size(32)>>
  end

  @spec read_vals([char], binary, list) :: list
  defp read_vals(tags, data, res) do
    # Logger.debug("tags = #{tags} data = #{data} res = #{inspect(res)}")
    [h | l] = tags

    {val, r_data} =
      case h do
        ?s -> read_string(data)
        ?i -> read_int(data)
        ?f -> read_float(data)
        ?d -> read_double(data)
        _ -> read_string(data)
      end

    if length(l) > 0 do
      read_vals(l, r_data, [val | res])
    else
      Enum.reverse([val | res])
    end
  end

  @spec decode(binary) :: {binary, list}
  def decode(s) do
    {addr, rest} = read_string(s)
    {tags, data} = read_string(rest)
    {addr, read_vals(String.to_charlist(String.slice(tags, 1..-1)), data, [])}
  end

  # @spec write_val(binary | number, binary, [binary]) :: {list, list}
  def write_val(d, tags, res) when is_binary(d) do
    {["s" | tags], [write_string(d) | res]}
  end

  def write_val(d, tags, res) when is_integer(d) do
    {["i" | tags], [write_int(d) | res]}
  end

  def write_val(d, tags, res) when is_float(d) do
    {["f" | tags], [write_float(d) | res]}
  end

  # Supercollider seems to use 32 bit floats. Doubles don't seem to work.
  #
  #
  ##
  # def write_val(d, tags, res) when is_float(d) do
  #   {["d" | tags], [write_double(d) | res]}
  # end

  @spec write_vals(list, list, list) :: binary
  def write_vals(data, tags, res) do
    [h | l] = data
    {ntags, nres} = write_val(h, tags, res)

    if length(l) > 0 do
      write_vals(l, ntags, nres)
    else
      write_string(Enum.join(Enum.reverse(ntags))) <> Enum.join(Enum.reverse(nres))
    end
  end

  @spec write_vals(list) :: binary
  def write_vals([]) do
    ""
  end

  def write_vals(data) do
    write_vals(data, [~c","], [])
  end

  @spec encode(any, [any]) :: binary
  def encode(addr, data) do
    Logger.debug("Encode addr = #{inspect(addr)} data = #{inspect(data)}")
    write_string(addr) <> write_vals(data)
  end

  @spec oslice4(binary) :: binary
  def oslice4(bin) do
    [a, b, c, d] = Enum.slice(:erlang.binary_to_list(bin), 0, 4)
    <<a, b, c, d>>
  end

  @spec oslice8(binary) :: binary
  def oslice8(bin) do
    [a, b, c, d, e, f, g, h] = Enum.slice(:erlang.binary_to_list(bin), 0, 8)
    <<a, b, c, d, e, f, g, h>>
  end
end
