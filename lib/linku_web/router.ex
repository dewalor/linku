defmodule LinkuWeb.Router do
  use LinkuWeb, :router

  import LinkuWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {LinkuWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LinkuWeb do
    pipe_through :browser

    live_session :default,
      on_mount: [{LinkuWeb.UserAuth, :ensure_authenticated}, LinkuWeb.Scope] do
      live "/home", HomeLive, :dashboard
      live "/renkus/new", HomeLive, :new_renku
      live "/renkus/:id/edit", HomeLive, :edit_renku

      live "/lines/:id/invitations", InvitationLive.Index, :index
      live "/lines/:id/invitations/new", InvitationLive.Index, :new
      live "/lines/:id/invitations/:id", InvitationLive.Show, :show

      live "/invitations/:key", HomeLive, :dashboard
    end

    live_session :unauthenticated,
      on_mount: [LinkuWeb.Scope] do
      live "/", JournalLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", LinkuWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:linku, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LinkuWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", LinkuWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{LinkuWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
    get "/users/log_in/:token", UserSessionController, :create
  end

  scope "/", LinkuWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{LinkuWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", LinkuWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{LinkuWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
