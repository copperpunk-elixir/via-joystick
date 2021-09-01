defmodule ViaJoystick do
  use GenServer
  require Logger

  @publish_joystick_loop :publish_joystick_loop
  @wait_for_all_channels_loop :wait_for_all_channels_loop
  @moduledoc """
  Documentation for `ViaJoystick`.
  """

  def start_link(config) do
    Logger.debug("Start ViaJoystick GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)

    state = %{
      joystick: Joystick.start_link(0, self(), :joystick_connected),
      num_axes: 0,
      num_channels: Keyword.fetch!(config, :num_channels),
      joystick_channels: %{},
      publish_joystick_loop_interval_ms:
        Keyword.fetch!(config, :publish_joystick_loop_interval_ms),
      subscriber_groups: Keyword.fetch!(config, :subscriber_groups)
    }

    {:ok, state}
  end

  def handle_cast({:joystick_connected, joystick}, state) do
    Logger.debug("Via connected to joystick: #{inspect(joystick)}")
    num_axes = joystick.axes

    GenServer.cast(
      __MODULE__,
      {@wait_for_all_channels_loop, state.publish_joystick_loop_interval_ms}
    )

    {:noreply,
     %{state | joystick: joystick, num_axes: num_axes, joystick_channels: %{num_axes => 0}}}
  end

  @impl GenServer
  def handle_cast({@wait_for_all_channels_loop, publish_joystick_loop_interval_ms}, state) do
    # Logger.debug("wait for channels. currently have: #{inspect(state.joystick_channels)}")
    if length(get_channels(state.joystick_channels, state.num_channels)) == state.num_channels do
      ViaUtils.Process.start_loop(
        self(),
        publish_joystick_loop_interval_ms,
        @publish_joystick_loop
      )
    else
      Process.sleep(100)

      GenServer.cast(
        __MODULE__,
        {@wait_for_all_channels_loop, publish_joystick_loop_interval_ms}
      )
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:joystick, event}, state) do
    # Logger.debug("event: #{inspect(event)}")

    {channel_number, scaled_value} =
      case event.type do
        :axis ->
          scaled_value = ViaUtils.Math.map_value(event.value, -999, 999, -1.0, 1.0)
          {event.number, scaled_value}

        :button ->
          channel_number = event.number + state.num_axes + 1

          cond do
            event.value == 1 -> {channel_number, 1.0}
            event.value == 0 -> {channel_number, -1.0}
          end

        other ->
          raise "how did we get an event of this type? #{inspect(other)}"
          {nil, nil}
      end

    joystick_channels =
      if !is_nil(channel_number) do
        Map.put(state.joystick_channels, channel_number, scaled_value)
      else
        state.joystick_channels
      end

    {:noreply, %{state | joystick_channels: joystick_channels}}
  end

  @impl GenServer
  def handle_info(@publish_joystick_loop, state) do
    channel_values = get_channels(state.joystick_channels, state.num_channels)
    # Logger.debug("#{ViaUtils.Format.eftb_map(state.joystick_channels, 3)}")
    # Logger.debug("#{ViaUtils.Format.eftb_list(channel_values, 3)}")

    Enum.each(state.subscriber_groups, fn group ->
      ViaUtils.Comms.send_local_msg_to_group(
        __MODULE__,
        {group, channel_values},
        self()
      )
    end)

    {:noreply, state}
  end

  @spec get_channels(map(), integer()) :: list()
  def get_channels(joystick_channels, num_channels) do
    joystick_channels
    |> Map.to_list()
    |> Enum.sort(fn {k1, _val1}, {k2, _val2} -> k1 < k2 end)
    |> Enum.reduce([], fn {_k, v}, acc -> [v] ++ acc end)
    |> Enum.reverse()
    |> Enum.take(num_channels)
  end
end
