defmodule Modsynth.Rand do

  def rand_pent(val) do
     :rand.normal(val, 12.0)
  end

end
