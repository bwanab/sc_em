defmodule MusicPrims do
  @circle_of_fifths [:C, :G, :D, :A, :E, :B, :F!, :C!, :Ab, :Eb, :Bb, :F]
  def key(mode, n_sharps_flats) when mode == :major do
    Enum.at(@circle_of_fifths, n_sharps_flats)
  end
  def key(mode, n_sharps_flats) when mode == :minor do
    Enum.at(@circle_of_fifths, n_sharps_flats+3)
  end
end
