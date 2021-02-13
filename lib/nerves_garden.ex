defmodule NervesGarden do

  def state do
    %{}
    |> Map.merge(NervesGarden.FillDrain.state)
    |> Map.merge(NervesGarden.Lights.state)
    |> Map.merge(NervesGarden.DhtSensor.state)
  end
end
