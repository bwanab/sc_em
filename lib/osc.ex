defmodule OSC do
  require Logger
  use Bitwise

  defp find0(cl, c, r) do
    <<f::binary-size(1), l::binary>> = cl
    if f == c do
      r
    else
      find0(l, c, [f | r])
    end
  end

  defp find(s, c) do
    String.reverse(List.to_string(find0(s, c, [])))
  end

  def read_string(s) do
    res = find(s, <<0>>)
    length = String.length(res)
    new_index = ceil((length+1) / 4.0) * 4
    #Logger.info("new_index = #{new_index}")
    {res, String.slice(s, new_index..-1)}
  end

  def write_string(s) do
    length = String.length(s)
    new_index = ceil((length+1) / 4.0) * 4
    pad = (new_index - length) - 1
    s <> List.to_string(for _n <- 0..pad do "\0" end)
  end

  def read_int(s) do
    length = String.length(s)
    if length < 4 do
      Logger.info("Error: too few bytes for int #{s} #{length}")
      {0, <<>>}
    else
      bin = String.slice(s, 0..3)
      # Logger.debug("bin = #{inspect(bin)}")
      <<res :: big-integer-32>> = bin
      {res, String.slice(s, 4..-1)}
    end
  end

  def write_int(i) do
    <<i::big-integer-32>>
  end

  def read_double(s) do
    length = String.length(s)
    if length < 8 do
      Logger.info("Error: too few bytes for double #{s} #{length}")
      {0.0, <<>>}
    else
      bin = String.slice(s, 0..7)
      <<res :: float>> = bin
      {res, String.slice(s, 8..-1)}
    end
  end

  def write_double(d) do
    <<d :: float>>
  end

  def read_float(s) do
    length = String.length(s)
    if length < 4 do
      Logger.info("Error: too few bytes for double #{s} #{length}")
      {0.0, <<>>}
    else
      bin = String.slice(s, 0..3)
      # Logger.debug("bin = #{inspect(bin)}")
      <<res :: float-size(32)>> = bin
      {res, String.slice(s, 4..-1)}
    end
  end

  def write_float(f) do
    <<f :: float-size(32)>>
  end

  defp read_vals(tags, data, res) do
    Logger.debug("tags = #{tags} data = #{data} res = #{inspect(res)}")
    [h|l] = tags
    {val, r_data} =
      case h do
        115 -> read_string(data)
        105 -> read_int(data)
        102 -> read_float(data)
        _ -> read_double(data)
      end
    if length(l) > 0 do
      read_vals(l, r_data, [val|res])
    else
      Enum.reverse([val|res])
    end
  end

  def decode(s) do
    {addr, rest} = read_string(s)
    {tags, data} = read_string(rest)
    {addr, read_vals(String.to_charlist(String.slice(tags, 1..-1)), data, [])}
  end

  def write_val(d, tags, res) when is_binary(d) do
    {["s" | tags], [write_string(d) | res]}
  end

  def write_val(d, tags, res) when is_integer(d) do
    {["i" | tags], [write_int(d) | res]}
  end

  # def write_val(d, tags, res) when is_float(d) do
  #   {["f" | tags], [write_string(d) | res]}
  # end

  def write_val(d, tags, res) when is_float(d) do
    {["d" | tags], [write_double(d) | res]}
  end

  def write_vals(data, tags, res) do
    [h | l] = data
    {ntags, nres} = write_val(h, tags, res)
    if length(l) > 0 do
      write_vals(l, ntags, nres)
    else
      write_string(Enum.join(Enum.reverse(ntags))) <> Enum.join(Enum.reverse(nres))
    end
  end

  def write_vals(data) do
    write_vals(data, [','], [])
  end


  def encode(addr, data) do
    write_string(addr) <> write_vals(data)
  end
end
