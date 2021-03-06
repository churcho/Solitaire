defmodule Solitaire.Game.KlondikeTest do
  alias Solitaire.Game.Klondike

  use ExUnit.Case

  setup do
    game = Klondike.load_game(3)
    {:ok, %{game: game}}
  end

  describe "#change" do
    test "changes - next cards move to top, current cards - to the end of the queue", %{
      game: game
    } do
      %{deck: [h | rest] = deck} = game
      rest_deck = res = Klondike.change(game)
      assert rest ++ [h] == res
      assert length(rest_deck) == length(deck)
    end

    test "if riched end of the deck - splits deck again by three, changes deck" do
      deck = [
        [heart: 2, spade: :K, diamond: 8],
        [],
        [heart: 3, club: 5],
        [club: :K, heart: 7, club: 3]
      ]

      new_deck = Klondike.change(%{deck: deck})
      deck_chunk_length = Enum.map(new_deck, &length/1)
      assert deck_chunk_length == [3, 3, 2, 0]
    end

    test "rest deck splitting" do
      deck = [
        [],
        [{:heart, :A}, {:club, 2}],
        [{:heart, 8}, {:club, 10}, {:club, 6}]
      ]

      new_deck = Klondike.change(%{deck: deck})
      deck_chunk_length = Enum.map(new_deck, &length/1)
      assert deck_chunk_length == [3, 2, 0]
    end
  end

  describe "#move_from_column/3" do
    test "when to column black - only King can be moved", %{game: game} do
      %{cols: cols} = game

      new_cols =
        cols
        |> List.replace_at(3, %{cards: [{:heart, :K}], unplayed: 0})
        |> List.replace_at(4, %{cards: [{:spade, :K}], unplayed: 0})
        |> List.replace_at(5, %{cards: [{:diamond, 10}], unplayed: 0})
        |> List.replace_at(0, %{cards: [], unplayed: 0})

      game = %{game | cols: new_cols}
      {:ok, %{cols: resulted_cols}} = Klondike.move_from_column(game, {3, 0}, 0)
      assert List.first(resulted_cols) == %{cards: [{:heart, :K}], unplayed: 0}
      assert Enum.at(resulted_cols, 3) == %{cards: [], unplayed: 0}
    end
  end

  describe "#move_from_deck/2" do
    test "1", %{game: game} do
      %{cols: init_cols} = game

      initial_deck = [
        [{:heart, 4}],
        [{:spade, 4}, {:club, 8}, {:club, :A}],
        [{:spade, 3}, {:club, 6}, {:diamond, 10}],
        []
      ]

      to_column = %{cards: [{:spade, 5}], unplayed: 0}
      cols = List.replace_at(init_cols, 2, to_column)

      game =
        game
        |> Map.put(:deck, initial_deck)
        |> Map.put(:cols, cols)

      %{deck: result_deck, cols: result_cols} = Klondike.move_from_deck(game, 2)
      assert result_deck == Enum.slice(initial_deck, 1..-1)
      %{cards: result_cards} = Enum.at(result_cols, 2)
      assert result_cards == [{:heart, 4}, {:spade, 5}]
    end

    test 2, %{game: game} do
      %{cols: init_cols} = game

      initial_deck = [
        [{:heart, 4}],
        [],
        [{:diamond, 2}, {:heart, :D}, {:heart, 3}]
      ]

      to_column = %{cards: [{:spade, 5}], unplayed: 0}
      cols = List.replace_at(init_cols, 2, to_column)

      game =
        game
        |> Map.put(:deck, initial_deck)
        |> Map.put(:cols, cols)

      %{deck: result_deck, cols: result_cols} = Klondike.move_from_deck(game, 2)
      assert result_deck == [[{:diamond, 2}, {:heart, :D}, {:heart, 3}], []]
      %{cards: result_cards} = Enum.at(result_cols, 2)
      assert result_cards == [{:heart, 4}, {:spade, 5}]
    end

    test 3, %{game: game} do
      deck = [
        [{:diamond, 5}, {:club, 6}, {:diamond, :A}],
        [{:spade, 3}, {:diamond, :K}, {:club, :A}],
        []
      ]

      %{cols: cols} = game

      new_cols = List.replace_at(cols, 3, %{cards: [{:club, 6}], unplayed: 0})

      game =
        game
        |> Map.put(:deck, deck)
        |> Map.put(:cols, new_cols)

      %{deck: result_deck} = Klondike.move_from_deck(game, 3)

      assert result_deck == [
               [{:club, 6}, {:diamond, :A}],
               [{:spade, 3}, {:diamond, :K}, {:club, :A}],
               []
             ]
    end

    test 4 do
      game = %Solitaire.Games{
        cols: [
          %{cards: [{:club, :D}, {:diamond, :K}], unplayed: 0}
        ],
        deck: [
          [{:heart, :J}, {:heart, :D}, {:club, 8}],
          [],
          [{:club, 9}, {:diamond, 9}, {:club, 5}]
        ],
        deck_length: 1
      }

      %{cols: cols, deck: deck} = Klondike.move_from_deck(game, 0)

      assert List.first(cols) == %{
               cards: [{:heart, :J}, {:club, :D}, {:diamond, :K}],
               unplayed: 0
             }

      assert deck == [
               [{:heart, :D}, {:club, 8}],
               [],
               [{:club, 9}, {:diamond, 9}, {:club, 5}]
             ]
    end
  end

  describe "#move_to_foundation/2 (game, :deck)" do
    test "when foundation is nil - A is available for move" do
      game = %{deck: [[{:spade, :A}], []], foundation: %{spade: nil}}

      Klondike.move_to_foundation(game, :deck)

      assert %{deck: [[]], foundation: %{spade: :A}} ==
               Klondike.move_to_foundation(game, :deck)
    end

    test "with non-empty foundation - next rank is available" do
      game = %{deck: [[{:spade, 2}], []], foundation: %{spade: :A}}

      assert %{deck: [[]], foundation: %{spade: 2}} ==
               Klondike.move_to_foundation(game, :deck)
    end

    test "rest deck splitting" do
      game = %{
        deck: [
          [heart: 2, spade: :K, diamond: 8],
          [],
          [heart: 3, club: 5, heart: 10]
        ],
        foundation: %{heart: :A}
      }

      %{
        deck: deck,
        foundation: %{heart: 2}
      } = Klondike.move_to_foundation(game, :deck)

      deck_lengths = Enum.map(deck, &length/1)
      assert deck_lengths == [2, 0, 3]
    end
  end

  describe "#move_to_foundation/2 (game, column)" do
    test "when foundation is nil - A is available for move" do
      game = %{cols: [%{cards: [{:spade, :A}], unplayed: 0}], foundation: %{spade: nil}}

      Klondike.move_to_foundation(game, 0)

      assert %{cols: [%{cards: [], unplayed: 0}], foundation: %{spade: :A}} ==
               Klondike.move_to_foundation(game, 0)
    end

    test "with non-empty foundation - next rank is available" do
      game = %{cols: [%{cards: [{:spade, 2}], unplayed: 0}], foundation: %{spade: :A}}

      assert %{cols: [%{cards: [], unplayed: 0}], foundation: %{spade: 2}} ==
               Klondike.move_to_foundation(game, 0)
    end

    # TODO: нужен генератор колоды, а нет вот это вот все
    test "unplayed handling" do
      game = %{
        cols: [%{cards: [{:spade, 2}, {:heart, 3}, {:spade, 4}], unplayed: 1}],
        foundation: %{spade: :A}
      }

      assert %{
               cols: [%{cards: [{:heart, 3}, {:spade, 4}], unplayed: 1}],
               foundation: %{spade: 2}
             } ==
               Klondike.move_to_foundation(game, 0)
    end
  end
end
