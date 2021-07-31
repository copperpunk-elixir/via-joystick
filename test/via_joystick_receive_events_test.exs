defmodule ViaJoystickReceiveEventsTest do
  use ExUnit.Case
  doctest ViaJoystick

  setup %{} do
    ViaUtils.Comms.Supervisor.start_link([])
    {:ok, []}
  end

  test "Receive Joystick Events" do
    config = [
      num_channels: 10,
      subscriber_groups: [],
      publish_joystick_loop_interval_ms: 20
    ]

    ViaJoystick.start_link(config)
    Process.sleep(200_000)
  end
end
