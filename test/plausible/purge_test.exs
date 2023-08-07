defmodule Plausible.PurgeTest do
  use Plausible.DataCase

  setup do
    site = insert(:site, stats_start_date: ~D[2020-01-01])

    populate_stats(site, [
      build(:pageview),
      build(:imported_visitors),
      build(:imported_sources),
      build(:imported_pages),
      build(:imported_entry_pages),
      build(:imported_exit_pages),
      build(:imported_locations),
      build(:imported_devices),
      build(:imported_browsers),
      build(:imported_operating_systems)
    ])

    {:ok, %{site: site}}
  end

  test "delete_imported_stats!/1 deletes imported data", %{site: site} do
    Enum.each(Plausible.Imported.tables(), fn table ->
      query = from(imported in table, where: imported.site_id == ^site.id)
      assert await_clickhouse_count(query, 1)
    end)

    assert :ok == Plausible.Purge.delete_imported_stats!(site)

    Enum.each(Plausible.Imported.tables(), fn table ->
      query = from(imported in table, where: imported.site_id == ^site.id)
      assert await_clickhouse_count(query, 0)
    end)
  end

  test "delete_imported_stats!/1 resets stats_start_date", %{site: site} do
    assert :ok == Plausible.Purge.delete_imported_stats!(site)
    assert %Plausible.Site{stats_start_date: nil} = Plausible.Repo.reload(site)
  end

  test "delete_native_stats!/1 moves the native_stats_start_at pointer", %{site: site} do
    assert :ok == Plausible.Purge.delete_native_stats!(site)

    assert %Plausible.Site{native_stats_start_at: native_stats_start_at} =
             Plausible.Repo.reload(site)

    assert NaiveDateTime.compare(native_stats_start_at, site.native_stats_start_at) == :gt
  end

  test "delete_native_stats!/1 resets stats_start_date", %{site: site} do
    assert :ok == Plausible.Purge.delete_native_stats!(site)
    assert %Plausible.Site{stats_start_date: nil} = Plausible.Repo.reload(site)
  end
end
