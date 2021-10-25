defmodule Lightswitch.Actions do
  require Logger

    @increment 10
    def k003(state) do
      is_on? = state.devices
               |> Keylight.status()
               |> Enum.any?(fn {_device, status} ->
                 case status do
                   {:ok, %{"lights" => [%{"on" => 1}]}} -> true
                   _ -> false
                 end
               end)

      if is_on? do
        Logger.info("Turning off all devices...")
        Keylight.off(state.devices)
      else
        Logger.info("Turning on all devices...")
        Keylight.on(state.devices)
      end
    end

    def k006(state) do
      brightness = state.devices
      |> Keylight.status()
      |> Enum.map(fn {_device, status} ->
        case status do
          {:ok, %{"lights" => [%{"brightness" => level}]}} -> level
          _ -> 0
        end
      end)
      |> Enum.max()

      Keylight.set(state.devices, brightness: brightness - @increment)
    end

    def k009(state) do
      brightness = state.devices
      |> Keylight.status()
      |> Enum.map(fn {_device, status} ->
        case status do
          {:ok, %{"lights" => [%{"brightness" => level}]}} -> level
          _ -> 0
        end
      end)
      |> Enum.max()

      Keylight.set(state.devices, brightness: brightness + @increment)
    end
end
