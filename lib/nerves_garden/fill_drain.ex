defmodule NervesGarden.FillDrain do
  use GenServer
  alias Circuits.GPIO
  require Logger

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init(_) do

    pump_pin = Application.get_env(:nerves_garden, :pump_pin)
    valve_open_pin  = Application.get_env(:nerves_garden, :valve_open_pin)
    valve_close_pin = Application.get_env(:nerves_garden, :valve_close_pin)

    {:ok, pump} = GPIO.open(pump_pin, :output)
    {:ok, valve_open} = GPIO.open(valve_open_pin, :output)
    {:ok, valve_close} = GPIO.open(valve_close_pin, :output)

    gpio = {pump, valve_open, valve_close}
    state = {{false, false}, gpio}

    state = open_valve(state)
    state = pump_off(state)
    Logger.info("Init filldrain")
    {:ok, ref} = :timer.send_after(Application.get_env(:nerves_garden, :fill_init_seconds) * 1_000, self(), :fill)

    {:ok, {ref, state}}
  end

  defp open_valve({{is_pump_on?, _is_valve_open?}, {_pump, valve_open, valve_close} = gpio}) do
    :ok = GPIO.write(valve_open, 0)
    :ok = GPIO.write(valve_close, 1)
    Logger.info("Valve open")

    {{is_pump_on?, true}, gpio}
  end

  defp close_valve({{is_pump_on?, _is_valve_open?}, {_pump, valve_open, valve_close} = gpio}) do
    :ok = GPIO.write(valve_open, 1)
    :ok = GPIO.write(valve_close, 0)
    Logger.info("Valve close")

    {{is_pump_on?, false}, gpio}
  end

  defp pump_on({{_is_pump_on?, is_valve_open?}, {pump, _, _} = gpio}) do
    :ok = GPIO.write(pump, 0)
    Logger.info("Pump on")

    {{true, is_valve_open?}, gpio}
  end

  defp pump_off({{_is_pump_on?, is_valve_open?}, {pump, _, _} = gpio}) do
    :ok = GPIO.write(pump, 1)
    Logger.info("Pump off")

    {{false, is_valve_open?}, gpio}
  end

  defp fill_time(), do: Application.get_env(:nerves_garden, :fill_time_seconds) * 1_000
  defp sit_time(), do: Application.get_env(:nerves_garden, :sit_time_seconds) * 1_000
  defp dry_time(), do: Application.get_env(:nerves_garden, :dry_time_seconds) * 1_000

  def handle_info(:fill, {_, state}) do
    Logger.info("Starting fill")

    new_state =
      state
      |> close_valve
      |> pump_on

    {:ok, ref} = :timer.send_after(fill_time(), self(), :sit)

    {:noreply, {ref, new_state}}
  end

  def handle_info(:sit, {_, state}) do
    Logger.info("Starting sit")

    new_state =
      state
      |> close_valve
      |> pump_off

    {:ok, ref} = :timer.send_after(sit_time(), self(), :drain)

    {:noreply, {ref, new_state}}
  end

  def handle_info(:drain, {_, state}) do
    Logger.info("Starting drain")

    new_state =
      state
      |> open_valve
      |> pump_off

    {:ok, ref} = :timer.send_after(dry_time(), self(), :fill)

    {:noreply, {ref, new_state}}
  end


  def handle_call({:override, what}, _, {ref, state}) do
    {:ok, _} = :timer.cancel(ref)
    send(self(), what)
    {:reply, :ok, {nil, state}}
  end

  def handle_call(:state, _, {ref, {{is_pump_on?, is_valve_open?}, _} = state}) do

    s = %{
      is_pump_on?: is_pump_on?,
      is_valve_open?: is_valve_open?
    }

    {:reply, s, {ref, state}}
  end

  def drain(), do: GenServer.call(__MODULE__, {:override, :drain})
  def sit(), do: GenServer.call(__MODULE__, {:override, :sit})
  def fill(), do: GenServer.call(__MODULE__, {:override, :fill})

  def state(), do: GenServer.call(__MODULE__, :state)
end
