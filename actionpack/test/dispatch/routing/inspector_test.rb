require 'abstract_unit'
require 'rails/engine'
require 'action_dispatch/routing/inspector'

class MountedRackApp
  def self.call(env)
  end
end

module ActionDispatch
  module Routing
    class RoutesInspectorTest < ActiveSupport::TestCase
      def setup
        @set = ActionDispatch::Routing::RouteSet.new
        app = ActiveSupport::OrderedOptions.new
        app.config = ActiveSupport::OrderedOptions.new
        app.config.assets = ActiveSupport::OrderedOptions.new
        app.config.assets.prefix = '/sprockets'
        Rails.stubs(:application).returns(app)
        Rails.stubs(:env).returns("development")
      end

      def draw(options = {}, &block)
        @set.draw(&block)
        inspector = ActionDispatch::Routing::RoutesInspector.new(@set.routes)
        inspector.format(ActionDispatch::Routing::ConsoleFormatter.new, options[:filter]).split("\n")
      end

      def test_displaying_routes_for_engines
        engine = Class.new(Rails::Engine) do
          def self.inspect
            "Blog::Engine"
          end
        end
        engine.routes.draw do
          get '/cart', :to => 'cart#show'
        end

        output = draw do
          get '/custom/assets', :to => 'custom_assets#show'
          mount engine => "/blog", :as => "blog"
        end

        assert_equal [
          "       Prefix Verb URI Pattern              Controller#Action",
          "custom_assets GET  /custom/assets(.:format) custom_assets#show",
          "         blog      /blog                    Blog::Engine",
          "",
          "Routes for Blog::Engine:",
          "  cart GET  /cart(.:format) cart#show"
        ], output
      end

      def test_displaying_routes_for_engines_without_routes
        engine = Class.new(Rails::Engine) do
          def self.inspect
            "Blog::Engine"
          end
        end
        engine.routes.draw do
        end

        output = draw do
          mount engine => "/blog", as: "blog"
        end

        assert_equal [
          "Prefix Verb URI Pattern Controller#Action",
          "  blog      /blog       Blog::Engine",
          "",
          "Routes for Blog::Engine:"
        ], output
      end

      def test_cart_inspect
        output = draw do
          get '/cart', :to => 'cart#show'
        end

        assert_equal [
          "Prefix Verb URI Pattern     Controller#Action",
          "  cart GET  /cart(.:format) cart#show"
        ], output
      end

      def test_inspect_shows_custom_assets
        output = draw do
          get '/custom/assets', :to => 'custom_assets#show'
        end

        assert_equal [
          "       Prefix Verb URI Pattern              Controller#Action",
          "custom_assets GET  /custom/assets(.:format) custom_assets#show"
        ], output
      end

      def test_inspect_routes_shows_resources_route
        output = draw do
          resources :articles
        end

        assert_equal [
          "      Prefix Verb   URI Pattern                  Controller#Action",
          "    articles GET    /articles(.:format)          articles#index",
          "             POST   /articles(.:format)          articles#create",
          " new_article GET    /articles/new(.:format)      articles#new",
          "edit_article GET    /articles/:id/edit(.:format) articles#edit",
          "     article GET    /articles/:id(.:format)      articles#show",
          "             PATCH  /articles/:id(.:format)      articles#update",
          "             PUT    /articles/:id(.:format)      articles#update",
          "             DELETE /articles/:id(.:format)      articles#destroy"
        ], output
      end

      def test_inspect_routes_shows_root_route
        output = draw do
          root :to => 'pages#main'
        end

        assert_equal [
          "Prefix Verb URI Pattern Controller#Action",
          "  root GET  /           pages#main"
        ], output
      end

      def test_inspect_routes_shows_dynamic_action_route
        output = draw do
          get 'api/:action' => 'api'
        end

        assert_equal [
          "Prefix Verb URI Pattern            Controller#Action",
          "       GET  /api/:action(.:format) api#:action"
        ], output
      end

      def test_inspect_routes_shows_controller_and_action_only_route
        output = draw do
          get ':controller/:action'
        end

        assert_equal [
          "Prefix Verb URI Pattern                    Controller#Action",
          "       GET  /:controller/:action(.:format) :controller#:action"
        ], output
      end

      def test_inspect_routes_shows_controller_and_action_route_with_constraints
        output = draw do
          get ':controller(/:action(/:id))', :id => /\d+/
        end

        assert_equal [
          "Prefix Verb URI Pattern                            Controller#Action",
          "       GET  /:controller(/:action(/:id))(.:format) :controller#:action {:id=>/\\d+/}"
        ], output
      end

      def test_rake_routes_shows_route_with_defaults
        output = draw do
          get 'photos/:id' => 'photos#show', :defaults => {:format => 'jpg'}
        end

        assert_equal [
          "Prefix Verb URI Pattern           Controller#Action",
          %Q[       GET  /photos/:id(.:format) photos#show {:format=>"jpg"}]
        ], output
      end

      def test_rake_routes_shows_route_with_constraints
        output = draw do
          get 'photos/:id' => 'photos#show', :id => /[A-Z]\d{5}/
        end

        assert_equal [
          "Prefix Verb URI Pattern           Controller#Action",
          "       GET  /photos/:id(.:format) photos#show {:id=>/[A-Z]\\d{5}/}"
        ], output
      end

      def test_rake_routes_shows_routes_with_dashes
        output = draw do
          get 'about-us' => 'pages#about_us'
          get 'our-work/latest'

          resources :photos, only: [:show] do
            get 'user-favorites', on: :collection
            get 'preview-photo', on: :member
            get 'summary-text'
          end
        end

        assert_equal [
          "               Prefix Verb URI Pattern                              Controller#Action",
          "             about_us GET  /about-us(.:format)                      pages#about_us",
          "      our_work_latest GET  /our-work/latest(.:format)               our_work#latest",
          "user_favorites_photos GET  /photos/user-favorites(.:format)         photos#user_favorites",
          "  preview_photo_photo GET  /photos/:id/preview-photo(.:format)      photos#preview_photo",
          "   photo_summary_text GET  /photos/:photo_id/summary-text(.:format) photos#summary_text",
          "                photo GET  /photos/:id(.:format)                    photos#show"
        ], output
      end

      def test_rake_routes_shows_route_with_rack_app
        output = draw do
          get 'foo/:id' => MountedRackApp, :id => /[A-Z]\d{5}/
        end

        assert_equal [
          "Prefix Verb URI Pattern        Controller#Action",
          "       GET  /foo/:id(.:format) MountedRackApp {:id=>/[A-Z]\\d{5}/}"
        ], output
      end

      def test_rake_routes_shows_named_route_with_mounted_rack_app
        output = draw do
          mount MountedRackApp => '/foo'
        end

        assert_equal [
          "          Prefix Verb URI Pattern Controller#Action",
          "mounted_rack_app      /foo        MountedRackApp"
        ], output
      end

      def test_rake_routes_shows_overridden_named_route_with_mounted_rack_app_with_name
        output = draw do
          mount MountedRackApp => '/foo', as: 'blog'
        end

        assert_equal [
          "Prefix Verb URI Pattern Controller#Action",
          "  blog      /foo        MountedRackApp"
        ], output
      end

      def test_rake_routes_shows_route_with_rack_app_nested_with_dynamic_constraints
        constraint = Class.new do
          def inspect
            "( my custom constraint )"
          end
        end

        output = draw do
          scope :constraint => constraint.new do
            mount MountedRackApp => '/foo'
          end
        end

        assert_equal [
          "          Prefix Verb URI Pattern Controller#Action",
          "mounted_rack_app      /foo        MountedRackApp {:constraint=>( my custom constraint )}"
        ], output
      end

      def test_rake_routes_dont_show_app_mounted_in_assets_prefix
        output = draw do
          get '/sprockets' => MountedRackApp
        end
        assert_no_match(/MountedRackApp/, output.first)
        assert_no_match(/\/sprockets/, output.first)
      end

      def test_rake_routes_shows_route_defined_in_under_assets_prefix
        output = draw do
          scope '/sprockets' do
            get '/foo' => 'foo#bar'
          end
        end
        assert_equal [
          "Prefix Verb URI Pattern              Controller#Action",
          "   foo GET  /sprockets/foo(.:format) foo#bar"
        ], output
      end

      def test_redirect
        output = draw do
          get "/foo"    => redirect("/foo/bar"), :constraints => { :subdomain => "admin" }
          get "/bar"    => redirect(path: "/foo/bar", status: 307)
          get "/foobar" => redirect{ "/foo/bar" }
        end

        assert_equal [
          "Prefix Verb URI Pattern       Controller#Action",
          "   foo GET  /foo(.:format)    redirect(301, /foo/bar) {:subdomain=>\"admin\"}",
          "   bar GET  /bar(.:format)    redirect(307, path: /foo/bar)",
          "foobar GET  /foobar(.:format) redirect(301)"
        ], output
      end

      def test_routes_can_be_filtered
        output = draw(filter: 'posts') do
          resources :articles
          resources :posts
        end

        assert_equal ["   Prefix Verb   URI Pattern               Controller#Action",
                      "    posts GET    /posts(.:format)          posts#index",
                      "          POST   /posts(.:format)          posts#create",
                      " new_post GET    /posts/new(.:format)      posts#new",
                      "edit_post GET    /posts/:id/edit(.:format) posts#edit",
                      "     post GET    /posts/:id(.:format)      posts#show",
                      "          PATCH  /posts/:id(.:format)      posts#update",
                      "          PUT    /posts/:id(.:format)      posts#update",
                      "          DELETE /posts/:id(.:format)      posts#destroy"], output
      end

      def test_regression_route_with_controller_regexp
        output = draw do
          get ':controller(/:action)', controller: /api\/[^\/]+/, format: false
        end

        assert_equal ["Prefix Verb URI Pattern            Controller#Action",
                      "       GET  /:controller(/:action) (?-mix:api\\/[^\\/]+)#:action"], output
      end
    end
  end
end
