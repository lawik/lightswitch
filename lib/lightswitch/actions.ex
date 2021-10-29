defmodule Lightswitch.Actions do
  require Logger

    @increment 10
    def k003(state) do
      toggle(state.devices)
    end

    def k006(state) do
      brightness(state.devices, -@increment)
    end

    def k009(state) do
      brightness(state.devices, @increment)
    end

    def k002(state) do
      state.devices
      |> light_one()
      |> toggle()
    end

    def k005(state) do
      state.devices
      |> light_one()
      |> brightness(-@increment)
    end

    def k008(state) do
      state.devices
      |> light_one()
      |> brightness(@increment)
    end

    def k001(state) do
      state.devices
      |> light_two()
      |> toggle()
    end

    def k004(state) do
      state.devices
      |> light_two()
      |> brightness(-@increment)
    end

    def k007(state) do
      state.devices
      |> light_two()
      |> brightness(@increment)
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

    defp brightness(devices, change) do
      brightness = devices
      |> Keylight.status()
      |> Enum.map(fn {_, status} ->
        case status do
          {:ok, %{"lights" => [%{"brightness" => level}]}} -> level
          _ -> 0
        end
      end)
      |> Enum.max()

      Logger.info("Changing brightness from #{brightness} with #{change}")

      Keylight.set(devices, brightness: brightness + change)
    end

    def toggle(devices) do
      is_on? = devices
               |> Keylight.status()
               |> Enum.any?(fn {_device, status} ->
                 case status do
                   {:ok, %{"lights" => [%{"on" => 1}]}} -> true
                   _ -> false
                 end
               end)

      if is_on? do
        Logger.info("Turning off...")
        Keylight.off(devices)
      else
        Logger.info("Turning on...")
        Keylight.on(devices)
      end
    end
end
