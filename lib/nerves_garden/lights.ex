defmodule NervesGarden.Lights do
  use GenServer
  alias Circuits.GPIO
  require Logger

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do
    lights_on_pin = Application.get_env(:nerves_garden, :light_pin)

    {:ok, gpio} = GPIO.open(lights_on_pin, :output)
    :ok = GPIO.write(gpio, 0)

    {:ok, ref} = :timer.send_after(on_time(), self(), :off)

    {:ok, {ref, {true, gpio}}}
  end

  defp hours_to_ms(hours), do: hours * 1000 * 60 * 60
  defp on_time(), do: Application.get_env(:nerves_garden, :lights_on_hours) |> hours_to_ms
  defp off_time(), do: hours_to_ms(24) - on_time()

  def handle_info(:off, {_, {_, gpio}}) do
    Logger.info("Lights are turning off")
    :ok = GPIO.write(gpio, 1)

    {:ok, ref} = :timer.send_after(off_time(), self(), :on)

    {:noreply, {ref, {false, gpio}}}
  end

  def handle_info(:on, {_, {_, gpio}}) do
    Logger.info("Lights are turning on")
    :ok = GPIO.write(gpio, 0)

    {:ok, ref} = :timer.send_after(on_time(), self(), :off)

    {:noreply, {ref, {true, gpio}}}
  end

  def handle_call({:override, new}, _, {ref, state}) do
    Logger.info("Override with: #{inspect new}")
    {:ok, _} = :timer.cancel(ref)
    send(self(), new)
    {:reply, :ok, {nil, state}}
  end

  def handle_call(:state, _, {ref, {on?, _} = state}) do
    s = %{ lights_on?: on? }
    {:reply, s, {ref, state}}
  end

  def on(), do: GenServer.call(__MODULE__, {:override, :on})
  def off(), do: GenServer.call(__MODULE__, {:override, :off})

  def state(), do: GenServer.call(__MODULE__, :state)
end
