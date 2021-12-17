defmodule Lightswitch.Actions do
  require Logger

    @increment 10
    def k003(state) do
      toggle(state)
    end

    def k006(state) do
      brightness(state, -@increment)
    end

    def k009(state) do
      brightness(state, @increment)
    end

    def k002(state) do
      state
      |> toggle(light: 1)
    end

    def k005(state) do
      state
      |> brightness(-@increment, light: 1)
    end

    def k008(state) do
      state
      |> brightness(@increment, light: 1)
    end

    def k001(state) do
      state
      |> toggle(light: 2)
    end

    def k004(state) do
      state
      |> brightness(-@increment, light: 2)
    end

    def k007(state) do
      state
      |> brightness(@increment, light: 2)
    end

    defp light_one(devices) do
      devices
      |> Enum.sort()
      |> Enum.reverse()
      |> Enum.take(1)
      |> Map.new()
    end

    defp light_two(devices) do
      devices
      |> Enum.sort()
      |> Enum.take(1)
      |> Map.new()
    end

    defp filter_devices(devices, opts) do
      case opts[:light] do
        1 -> light_one(devices)
        2 -> light_two(devices)
        nil -> devices
      end
    end

    defp filter_statuses(status, devices) do
      Map.take(status, Map.keys(devices))
    end

    defp brightness(state, change, opts \\ []) do
      devices = filter_devices(state.devices, opts)

      brightness = state.status
                   |> filter_statuses(devices)
                   |> get_brightness()

      Logger.info("Changing brightness from #{brightness} with #{change}")

      Keylight.set(devices, brightness: brightness + change)
      send(self(), :check_status)
      state
    end

    defp get_brightness(statuses) do
      if statuses == %{} do
        0
      else
        statuses
        |> Enum.map(fn {_, status} ->
          case status do
            {:ok, %{"lights" => [%{"brightness" => level}]}} -> level
            _ -> 0
          end
        end)
        |> Enum.max()
      end
    end

    def toggle(state, opts \\ []) do
      devices = filter_devices(state.devices, opts)

      is_on? = state.status
               |> filter_statuses(devices)
               |> get_is_on?()

      if is_on? do
        Logger.info("Turning off...")
        Keylight.off(devices)
      else
        Logger.info("Turning on...")
        Keylight.on(devices)
      end

      send(self(), :check_status)
      state
    end

    defp get_is_on?(statuses) do
      statuses
      |> Enum.any?(fn {_device, status} ->
        case status do
          {:ok, %{"lights" => [%{"on" => 1}]}} -> true
          _ -> false
        end
      end)
    end

    def state_to_colors(%{status: status, devices: devices}) do
      all = devices
      one = filter_devices(devices, light: 1)
      two = filter_devices(devices, light: 2)
      %{
        k003: status |> filter_statuses(all) |> get_is_on?() |> to_color(),
        k002: status |> filter_statuses(one) |> get_is_on?() |> to_color(),
        k001: status |> filter_statuses(two) |> get_is_on?() |> to_color(),
        k006: status |> filter_statuses(all) |> get_brightness() |> lower() |> to_color(),
        k005: status |> filter_statuses(one) |> get_brightness() |> lower() |> to_color(),
        k004: status |> filter_statuses(two) |> get_brightness() |> lower() |> to_color(),
        k009: status |> filter_statuses(all) |> get_brightness() |> higher() |> to_color(),
        k008: status |> filter_statuses(one) |> get_brightness() |> higher() |> to_color(),
        k007: status |> filter_statuses(two) |> get_brightness() |> higher() |> to_color()
      }
    end

    defp to_color(value) when is_boolean(value) do
      if value do
        "ffffff"
      else
        "000000"
      end
    end

    defp to_color(value) when is_integer(value) do
      intensity = trunc((255 / 100) * value)
      Chameleon.RGB.new(intensity, intensity, intensity)
    end

    defp lower(brightness) do
      case brightness - @increment do
        b when b > 100 -> 100
        b when b < 0 -> 0
        b -> b
      end
    end

    defp higher(brightness) do
      case brightness + @increment do
        b when b > 100 -> 100
        b when b < 0 -> 0
        b -> b
      end
    end
end
