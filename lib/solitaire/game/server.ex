defmodule Solitaire.Game.Server do
  use GenServer

  alias Solitaire.Statix

  require Logger

  @spec start_link(map()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%{token: token, type: type} = state) when type in [:klondike, :spider] do
    GenServer.start_link(__MODULE__, state,
      spawn_opt: [fullsweep_after: 20],
      name: name(token)
    )
  end

  def start_link(%{type: type} = params) do
    start_link(Map.merge(params, %{type: String.to_existing_atom(type)}))
  end

  def start_link(params) do
    start_link(Map.merge(params, %{type: type_from_config()}))
  end

  defp type_from_config, do: Application.get_env(:solitaire, :game)[:type]

  def stop(token) do
    GenServer.stop(name(token))
  end

  def game_pid(token), do: GenServer.whereis(name(token))

  defp name(token) do
    {:global, token}
  end

  def state(token) do
    measure("get_state", fn ->
      GenServer.call(name(token), :state)
    end)
  end

  @spec init(any) :: {:ok, Game.t(), {:continue, :give_cards}}
  def init(state) do
    {:ok, state, {:continue, :give_cards}}
  end

  def move_to_foundation(token, attr) do
    measure("move_to_foundation", fn ->
      GenServer.call(name(token), {:move_to_foundation, attr})
    end)
  end

  defp measure(label, fun) do
    if Application.get_env(:statsd_logger, :enable) do
      Statix.measure(label, fun)
    else
      fun.()
    end
  end

  def change(token) do
    measure("change", fn ->
      GenServer.call(name(token), :change)
    end)
  end

  def move_from_deck(token, column) do
    measure("move_from_deck", fn ->
      GenServer.call(name(token), {:move_from_deck, column})
    end)
  end

  def move_from_column(token, from, to) do
    GenServer.call(name(token), {:move_from_column, from, to})
  end

  def move_from_foundation(token, suit, column) do
    measure("move_from_foundation", fn ->
      GenServer.call(name(token), {:move_from_foundation, suit, column})
    end)
  end

  def handle_continue(:give_cards, state) do
    measure("give_cards", fn ->
      new_state =
        put_deck_length(update_game_state(state, module(state).load_game(suit_count(state))))

      perform_automove_to_foundation(new_state)
      {:noreply, new_state}
    end)
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:move_from_foundation, suit, column}, _from, %{type: :klondike} = state) do
    result = module(state).move_from_foundation(state, suit, column)

    new_state =
      state
      |> update_game_state(result)
      |> put_deck_length

    {:reply, new_state, new_state}
  end

  def handle_call({:move_from_foundation, _suit, _column}, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:move_to_foundation, attr}, _from, state) do
    result = module(state).move_to_foundation(state, attr)

    new_state = update_game_state(state, result)

    {:reply, new_state, new_state}
  end

  def handle_call(:change, _from, state) do
    result = Map.put(state, :deck, module(state).change(state))
    new_state = state |> update_game_state(result) |> put_deck_length

    perform_automove_to_foundation(state)
    {:reply, new_state, new_state}
  end

  def handle_call(
        {:move_from_deck, column},
        _from,
        state
      ) do
    result = module(state).move_from_deck(state, column)

    new_state = update_game_state(state, result)

    perform_automove_to_foundation(new_state)

    {:reply, new_state, new_state}
  end

  def handle_call({:move_from_column, from, to}, _from, state) do
    {_, result} = module(state).move_from_column(state, from, to)

    new_state = update_game_state(state, result)

    perform_automove_to_foundation(new_state)

    {:reply, new_state, new_state}
  end

  defp put_deck_length(%{deck: deck} = state) do
    deck_length = Enum.find_index(deck, &(&1 == []))
    %{state | deck_length: deck_length}
  end

  defp update_game_state(state, result) do
    state
    |> Map.put(:cols, result.cols)
    |> Map.put(:deck, result.deck)
    |> Map.put(:deck_length, result.deck_length)
    |> Map.put(:foundation, result.foundation)
  end

  def perform_automove_to_foundation(%{type: :klondike, token: token} = game) do
    Task.async(fn ->
      Solitaire.Game.Autoplayer.perform_automove_to_foundation(game, token)
    end)
  end

  def perform_automove_to_foundation(_state), do: false

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp suit_count(%{count: count}) do
    {val, _} = Integer.parse(count)
    val
  end

  defp suit_count(_state), do: Application.get_env(:solitaire, :game)[:suit_count]

  defp module(%{type: :klondike}), do: Solitaire.Game.Klondike
  defp module(_state), do: Solitaire.Game.Spider
end
