defmodule PlausibleWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :plausible

  @session_options [
    store: :cookie,
    key: "_plausible_key",
    signing_salt: "3IL0ob4k",
    # 5 years, this is super long but the SlidingSessionTimeout will log people out if they don't return for 2 weeks
    max_age: 60 * 60 * 24 * 365 * 5,
    extra: "SameSite=Lax"
    # domain added dynamically via RuntimeSessionAdapter, see below
  ]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug PlausibleWeb.Tracker
  plug PlausibleWeb.Favicon

  plug Plug.Static,
    at: "/",
    from: :plausible,
    gzip: false,
    only: ~w(css images js favicon.ico robots.txt)

  plug Plug.Static,
    at: "/kaffy",
    from: :kaffy,
    gzip: false,
    only: ~w(assets)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug PromEx.Plug, prom_ex_module: Plausible.PromEx
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Sentry.PlugContext

  plug Plug.MethodOverride
  plug Plug.Head

  plug PlausibleWeb.Plugs.RuntimeSessionAdapter, @session_options

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [
      check_origin: true,
      connect_info: [session: {__MODULE__, :patch_session_opts, []}]
    ]

  plug CORSPlug
  plug PlausibleWeb.Router

  def websocket_url() do
    :plausible
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:websocket_url)
  end

  def patch_session_opts() do
    # `host()` provided by Phoenix.Endpoint's compilation hooks
    # is used to inject the domain - this way we can authenticate
    # websocket requests within single root domain, in case websocket_url()
    # returns a ws{s}:// scheme (in which case SameSite=Lax is not applicable).
    Keyword.put(@session_options, :domain, host())
  end
end
