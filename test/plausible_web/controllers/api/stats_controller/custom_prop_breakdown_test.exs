defmodule PlausibleWeb.Api.StatsController.CustomPropBreakdownTest do
  use PlausibleWeb.ConnCase

  describe "GET /api/stats/:domain/custom-prop-values/:prop_key" do
    setup [:create_user, :log_in, :create_new_site, :add_imported_data]

    test "returns breakdown by a custom property", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, user_id: 123, "meta.key": [prop_key], "meta.value": ["Lotte"]),
        build(:pageview, user_id: 123, "meta.key": [prop_key], "meta.value": ["Lotte"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Sipsik"])
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 2,
                 "name" => "K2sna Kalle",
                 "events" => 2,
                 "percentage" => 50.0
               },
               %{
                 "visitors" => 1,
                 "name" => "Lotte",
                 "events" => 2,
                 "percentage" => 25.0
               },
               %{
                 "visitors" => 1,
                 "name" => "Sipsik",
                 "events" => 1,
                 "percentage" => 25.0
               }
             ]
    end

    test "ignores imported data when calculating percentage", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:imported_visitors, visitors: 2)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&with_imported=true"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 1,
                 "name" => "K2sna Kalle",
                 "events" => 1,
                 "percentage" => 100.0
               }
             ]
    end

    test "returns (none) values in the breakdown", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 2,
                 "name" => "K2sna Kalle",
                 "events" => 2,
                 "percentage" => 66.7
               },
               %{
                 "visitors" => 1,
                 "name" => "(none)",
                 "events" => 1,
                 "percentage" => 33.3
               }
             ]
    end

    test "(none) value is added as +1 to pagination limit", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview)
      ])

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&limit=1"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 2,
                 "name" => "K2sna Kalle",
                 "events" => 2,
                 "percentage" => 66.7
               },
               %{
                 "visitors" => 1,
                 "name" => "(none)",
                 "events" => 1,
                 "percentage" => 33.3
               }
             ]
    end

    test "(none) value is only included on the first page of results", %{conn: conn, site: site} do
      prop_key = "kaksik"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Teet"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Teet"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Tiit"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Tiit"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Tiit"]),
        build(:pageview)
      ])

      conn1 =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&limit=1&page=1"
        )

      conn2 =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&limit=1&page=2"
        )

      assert json_response(conn1, 200) == [
               %{
                 "visitors" => 3,
                 "name" => "Tiit",
                 "events" => 3,
                 "percentage" => 50.0
               },
               %{
                 "visitors" => 1,
                 "name" => "(none)",
                 "events" => 1,
                 "percentage" => 16.7
               }
             ]

      assert json_response(conn2, 200) == [
               %{
                 "visitors" => 2,
                 "name" => "Teet",
                 "events" => 2,
                 "percentage" => 33.3
               }
             ]
    end
  end

  describe "GET /api/stats/:domain/custom-prop-values/:prop_key - with goal filter" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns property breakdown for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"]),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"])
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      filters = Jason.encode!(%{goal: "Signup"})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 2,
                 "name" => "B",
                 "events" => 2,
                 "conversion_rate" => 33.3
               },
               %{
                 "visitors" => 1,
                 "name" => "A",
                 "events" => 1,
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "returns (none) values in property breakdown for goal", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup"),
        build(:event, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"])
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      filters = Jason.encode!(%{goal: "Signup"})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 2,
                 "name" => "(none)",
                 "events" => 2,
                 "conversion_rate" => 33.3
               },
               %{
                 "visitors" => 1,
                 "name" => "A",
                 "events" => 1,
                 "conversion_rate" => 16.7
               }
             ]
    end

    test "does not return (none) value in property breakdown with is filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "0"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "0",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns only (none) value in property breakdown with is (none) filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "(none)",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns (none) value in property breakdown with is_not filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!0"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "20",
                 "visitors" => 2,
                 "events" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "(none)",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 25.0
               }
             ]
    end

    test "does not return (none) value in property breakdown with is_not (none) filter", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "0",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "does not return (none) value in property breakdown with member filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "0|1"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "1",
                 "visitors" => 2,
                 "events" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "0",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 25.0
               }
             ]
    end

    test "returns (none) value in property breakdown with member filter including a (none) value",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["1"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "1|(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "1",
                 "visitors" => 2,
                 "events" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "name" => "(none)",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 25.0
               }
             ]
    end

    test "returns (none) value in property breakdown with not_member filter on prop_value", %{
      conn: conn,
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0.01"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!0|0.01"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "20",
                 "visitors" => 2,
                 "events" => 2,
                 "conversion_rate" => 40.0
               },
               %{
                 "name" => "(none)",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 20.0
               }
             ]
    end

    test "does not return (none) value in property breakdown with not_member filter including a (none) value",
         %{conn: conn, site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["0"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["cost"],
          "meta.value": ["20"]
        ),
        build(:event, name: "Purchase")
      ])

      insert(:goal, %{site: site, event_name: "Purchase"})

      filters =
        Jason.encode!(%{
          goal: "Purchase",
          props: %{cost: "!0|(none)"}
        })

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/cost?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "20",
                 "visitors" => 2,
                 "events" => 2,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns property breakdown with a pageview goal filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, pathname: "/"),
        build(:pageview, pathname: "/register"),
        build(:pageview, pathname: "/register", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:pageview, pathname: "/register", "meta.key": ["variant"], "meta.value": ["A"])
      ])

      insert(:goal, %{site: site, page_path: "/register"})
      filters = Jason.encode!(%{goal: "Visit /register"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/variant?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 2,
                 "name" => "A",
                 "events" => 2,
                 "conversion_rate" => 50.0
               },
               %{
                 "visitors" => 1,
                 "name" => "(none)",
                 "events" => 1,
                 "conversion_rate" => 25.0
               }
             ]
    end

    test "property breakdown with prop filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1),
        build(:event, user_id: 1, name: "Signup", "meta.key": ["variant"], "meta.value": ["A"]),
        build(:pageview, user_id: 2),
        build(:event, user_id: 2, name: "Signup", "meta.key": ["variant"], "meta.value": ["B"])
      ])

      insert(:goal, %{site: site, event_name: "Signup"})
      filters = Jason.encode!(%{goal: "Signup", props: %{"variant" => "B"}})
      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 1,
                 "name" => "B",
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "Property breakdown with prop and goal filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, utm_campaign: "campaignA"),
        build(:event,
          user_id: 1,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        ),
        build(:pageview, user_id: 2, utm_campaign: "campaignA"),
        build(:event,
          user_id: 2,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["B"]
        )
      ])

      insert(:goal, %{site: site, event_name: "ButtonClick"})

      filters =
        Jason.encode!(%{
          goal: "ButtonClick",
          props: %{variant: "A"},
          utm_campaign: "campaignA"
        })

      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "A",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "Property breakdown with goal and source filter", %{conn: conn, site: site} do
      populate_stats(site, [
        build(:pageview, user_id: 1, referrer_source: "Google"),
        build(:event,
          user_id: 1,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["A"]
        ),
        build(:pageview, user_id: 2, referrer_source: "Google"),
        build(:pageview, user_id: 3, referrer_source: "ignore"),
        build(:event,
          user_id: 3,
          name: "ButtonClick",
          "meta.key": ["variant"],
          "meta.value": ["B"]
        )
      ])

      insert(:goal, %{site: site, event_name: "ButtonClick"})

      filters =
        Jason.encode!(%{
          goal: "ButtonClick",
          source: "Google"
        })

      prop_key = "variant"

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "name" => "A",
                 "visitors" => 1,
                 "events" => 1,
                 "conversion_rate" => 50.0
               }
             ]
    end

    test "returns revenue metrics when filtering by a revenue goal", %{conn: conn, site: site} do
      prop_key = "logged_in"

      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": [prop_key],
          "meta.value": ["true"],
          revenue_reporting_amount: Decimal.new("12"),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "Payment",
          "meta.key": [prop_key],
          "meta.value": ["true"],
          revenue_reporting_amount: Decimal.new("100"),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "Payment",
          "meta.key": [prop_key],
          "meta.value": ["false"],
          revenue_reporting_amount: Decimal.new("8"),
          revenue_reporting_currency: "EUR"
        )
      ])

      insert(:goal, %{site: site, event_name: "Payment", currency: :EUR})

      filters = Jason.encode!(%{goal: "Payment"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 2,
                 "name" => "true",
                 "events" => 2,
                 "conversion_rate" => 66.7,
                 "total_revenue" => %{"long" => "€112.00", "short" => "€112.0"},
                 "average_revenue" => %{"long" => "€56.00", "short" => "€56.0"}
               },
               %{
                 "visitors" => 1,
                 "name" => "false",
                 "events" => 1,
                 "conversion_rate" => 33.3,
                 "total_revenue" => %{"long" => "€8.00", "short" => "€8.0"},
                 "average_revenue" => %{"long" => "€8.00", "short" => "€8.0"}
               }
             ]
    end

    test "returns revenue metrics when filtering by many revenue goals with same currency", %{
      conn: conn,
      site: site
    } do
      prop_key = "logged_in"
      insert(:goal, site: site, event_name: "Payment", currency: "EUR")
      insert(:goal, site: site, event_name: "Payment2", currency: "EUR")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": [prop_key],
          "meta.value": ["false"],
          revenue_reporting_amount: Decimal.new("10"),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "Payment",
          "meta.key": [prop_key],
          "meta.value": ["true"],
          revenue_reporting_amount: Decimal.new("30"),
          revenue_reporting_currency: "EUR"
        ),
        build(:event,
          name: "Payment2",
          "meta.key": [prop_key],
          "meta.value": ["true"],
          revenue_reporting_amount: Decimal.new("50"),
          revenue_reporting_currency: "EUR"
        )
      ])

      filters = Jason.encode!(%{goal: "Payment|Payment2"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 2,
                 "name" => "true",
                 "events" => 2,
                 "conversion_rate" => 66.7,
                 "total_revenue" => %{"long" => "€80.00", "short" => "€80.0"},
                 "average_revenue" => %{"long" => "€40.00", "short" => "€40.0"}
               },
               %{
                 "visitors" => 1,
                 "name" => "false",
                 "events" => 1,
                 "conversion_rate" => 33.3,
                 "total_revenue" => %{"long" => "€10.00", "short" => "€10.0"},
                 "average_revenue" => %{"long" => "€10.00", "short" => "€10.0"}
               }
             ]
    end

    test "does not return revenue metrics when filtering by many revenue goals with different currencies",
         %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Payment", currency: "USD")
      insert(:goal, site: site, event_name: "AddToCart", currency: "EUR")

      populate_stats(site, [
        build(:event,
          name: "Payment",
          "meta.key": ["logged_in"],
          "meta.value": ["false"],
          revenue_reporting_amount: Decimal.new("10"),
          revenue_reporting_currency: "EUR"
        )
      ])

      filters = Jason.encode!(%{goal: "Payment|AddToCart"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/whatever-prop?period=day&filters=#{filters}"
        )

      returned_metrics =
        json_response(conn, 200)
        |> List.first()
        |> Map.keys()

      refute "Average revenue" in returned_metrics
      refute "Total revenue" in returned_metrics
    end
  end

  describe "GET /api/stats/:domain/custom-prop-values/:prop_key - other filters" do
    setup [:create_user, :log_in, :create_new_site]

    test "returns prop-breakdown with a page filter", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, pathname: "/sipsik", "meta.key": [prop_key], "meta.value": ["Sipsik"])
      ])

      filters = Jason.encode!(%{page: "/sipsik"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 1,
                 "name" => "Sipsik",
                 "events" => 1,
                 "percentage" => 100.0
               }
             ]
    end

    test "returns prop-breakdown with a session-level filter", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, browser: "Chrome", "meta.key": [prop_key], "meta.value": ["Sipsik"])
      ])

      filters = Jason.encode!(%{browser: "Chrome"})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 1,
                 "name" => "Sipsik",
                 "events" => 1,
                 "percentage" => 100.0
               }
             ]
    end

    test "returns prop-breakdown with a prop_value filter", %{conn: conn, site: site} do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Sipsik"])
      ])

      filters = Jason.encode!(%{props: %{parim_s6ber: "Sipsik"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 1,
                 "name" => "Sipsik",
                 "events" => 1,
                 "percentage" => 100.0
               }
             ]
    end

    test "returns prop-breakdown with a prop_value is_not (none) filter", %{
      conn: conn,
      site: site
    } do
      prop_key = "parim_s6ber"

      populate_stats(site, [
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["K2sna Kalle"]),
        build(:pageview, "meta.key": [prop_key], "meta.value": ["Sipsik"]),
        build(:pageview)
      ])

      filters = Jason.encode!(%{props: %{parim_s6ber: "!(none)"}})

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/custom-prop-values/#{prop_key}?period=day&filters=#{filters}"
        )

      assert json_response(conn, 200) == [
               %{
                 "visitors" => 2,
                 "name" => "K2sna Kalle",
                 "events" => 2,
                 "percentage" => 66.7
               },
               %{
                 "visitors" => 1,
                 "name" => "Sipsik",
                 "events" => 1,
                 "percentage" => 33.3
               }
             ]
    end
  end
end
