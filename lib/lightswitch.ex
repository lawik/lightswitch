defmodule Lightswitch do
  use GenServer

  alias Circuits.SPI
  alias Circuits.GPIO
  alias Lightswitch.Actions

  require Logger

  @spi_device "spidev0.0"
  @spi_speed_hz 4_000_000
  @sof <<0, 0, 0, 0>>
  @eof <<255, 255, 255, 255>>
  # This is the hardware order that the LED colors need to be sent to the SPI
  # device in. The LED IDs are the ones from `Xebow.layout/0`.
  @spi_led_order [
    :k001,
    :k004,
    :k007,
    :k010,
    :k002,
    :k005,
    :k008,
    :k011,
    :k003,
    :k006,
    :k009,
    :k012
  ]

  @color_off "000000"

  @gpio_pins %{
    6 => :k004,
    5 => :k009,
    27 => :k011,
    26 => :k003,
    24 => :k008,
    23 => :k012,
    22 => :k007,
    20 => :k001,
    17 => :k010,
    16 => :k002,
    13 => :k006,
    12 => :k005
  }

  @fade_time 100 # ms

  def start_link(opts) do
    GenServer.start_link(Lightswitch, opts, opts)
  end

  @no_color %Chameleon.RGB{r: 0, b: 0, g: 0}

  def init(opts) do
    devices = Keylight.discover()
    {:ok, spidev} = SPI.open(@spi_device, speed_hz: @spi_speed_hz)
    pins = Enum.map(@gpio_pins, fn {pin_number, _} ->
      {:ok, pin_ref} = GPIO.open(pin_number, :input, pull_mode: :pullup)
      GPIO.set_interrupts(pin_ref, :both)
      {pin_number, pin_ref}
    end)

    colors = for key <- @spi_led_order, into: %{} do
      {key, @no_color}
    end

    state = %{
      spidev: spidev,
      pins: pins,
      devices: devices,
      colors: colors
    }
    Process.send_after(self(), :discovery, :timer.seconds(10))
    :timer.send_interval(:timer.seconds(30), self(), :discovery)
    #:timer.send_interval(100, self(), :shift)
    {:ok, state}
  end

  def handle_info(:discovery, state) do
    state = %{state | devices: Keylight.discover()}
    {:noreply, state}
  end

  def handle_info({:circuits_gpio, pin_number, timestamp, value}, state) do
    key = @gpio_pins[pin_number]
    Logger.info("Key: #{inspect(pin_number)} #{inspect(key)} #{value}")
    #set_lights(state, %{key => "ff00ff"})
    new_colors = if value == 0 and function_exported?(Actions, key, 1) do
      apply(Actions, key, [state])
      #fade_lights(state, %{key => %Chameleon.RGB{r: 0, g: 255, b: 255}})
    else
      state.colors
    end
    {:noreply, %{state | colors: new_colors}}
  end

  def handle_info({:fade, colors, fades}, state) do
    new_colors = fade_lights(state, colors, fades)
    {:noreply, %{state | colors: new_colors}}
  end

  def handle_info(:shift, state) do
    shift = (System.monotonic_time(:second)) |> :math.sin()
    hue = shift * 360
    set_lights(state, %{}, %Chameleon.HSL{h: hue, s: 100, l: 50})
    {:noreply, state}
  end

  defp set_lights(state, light_colors, fill \\ @color_off) do
    data = Enum.reduce(@spi_led_order, @sof, fn led, acc ->
      color = Map.get(light_colors, led, fill)
      rgb = Chameleon.convert(color, Chameleon.Color.RGB)
      acc <> <<227, rgb.b, rgb.g, rgb.r>>
    end) <> @eof
    SPI.transfer(state.spidev, data)
  end

  defp fade_lights(state, colors, fades \\ 0) do
    if fades < 255 do

      new_colors = state.colors
             |> Map.merge(colors)

      data = Enum.reduce(new_colors, @sof, fn {led, rgb}, acc ->
        if colors[led] do
          acc <> <<227, max(0, rgb.b - fades), max(0, rgb.g - fades), max(0, rgb.r - fades) >>
        else
          acc <> <<227, max(0, rgb.b), max(0, rgb.g), max(0, rgb.r) >>
        end
      end) <> @eof
      SPI.transfer(state.spidev, data)
      Process.send_after(self(), {:fade, colors, fades + 1}, @fade_time)
      new_colors
    else
      state.colors
    end
  end
end
