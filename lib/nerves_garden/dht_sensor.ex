defmodule NervesGarden.DhtSensor do
  use GenServer
  require Logger

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    :timer.send_interval(2_000, self(), :read)
    {:ok, []}
  end

  defp avg([]), do: 0
  defp avg(nums), do: Enum.sum(nums) / length(nums)

  def handle_info(:read, state) do
    case DHT.read(Application.get_env(:nerves_garden, :dht_pin), :dht22) do
      {:ok, %{temperature: temp, humidity: humid}} ->
        new_state = [{temp, humid} | state]

        temp = Enum.map(new_state, fn {t, _} -> t end) |> avg
        humid = Enum.map(new_state, fn {_, h} -> h end) |> avg
        # Logger.info("Temp=#{temp} Humid=#{humid}")

        {:noreply, Enum.take(new_state, 10)}
      {:error, what} ->
        Logger.error("Failed to read temp/humid #{inspect what}")
        {:noreply, state}
    end
  end

  def handle_call(:state, _, state) do
    temp = Enum.map(state, fn {t, _} -> t end) |> avg
    humid = Enum.map(state, fn {_, h} -> h end) |> avg

    s = %{temp: temp, humidity: humid}

    {:reply, s, state}
  end

  def state() do
    GenServer.call(__MODULE__, :state)
  end

end
