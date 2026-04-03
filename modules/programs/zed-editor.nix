{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  inherit (lib) mkAfter mkEnableOption mkIf mkMerge mkOption mkOptionDefault mkPackageOption types;
  inherit (lib.tundra) mergeFormat resolveList;
  cfg = config.shanetrs.programs.zed-editor;
in {
  options.shanetrs.programs.zed-editor = {
    enable = mkEnableOption "Zed configuration and integration";
    features = mkOption {
      type = types.listOf (types.enum ["nix" "rust"]);
      default = ["nix" "rust"];
    };
    package = mkPackageOption pkgs "zed-editor" {};
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
    };
    settings = mkOption {
      type = types.attrsOf types.anything;
      default = {
        agent.default_width = 360;
        auto_install_extensions = {
          csv = true;
          git-firefly = true;
          glsl = true;
          html = true;
          ini = true;
          java = true;
          lua = true;
          xml = true;
        };
        auto_update = false;
        buffer_line_height.custom = 1.5;
        diagnostics.inline = {
          enabled = true;
          padding = 6;
          update_debounce_ms = 15;
        };
        ensure_final_newline_on_save = false;
        expand_excerpt_lines = 12;
        "experimental.theme_overrides"."editor.invisible" = "#fff";
        extend_comment_on_newline = false;
        file_types = {
          JSONC = ["*.json"];
        };
        git.inline_blame.show_commit_summary = true;
        git_panel.tree_view = true;
        hard_tabs = true;
        indent_guides.coloring = "indent_aware";
        inlay_hints = {
          edit_debounce_ms = 15;
          enabled = true;
          show_other_hints = true;
          show_parameter_hints = true;
          show_type_hints = true;
        };
        lsp.clangd.binary.path = "clangd";
        middle_click_paste = false;
        minimap.show = "always";
        outline_panel.indent_size = 15;
        preferred_line_length = 120;
        prettier.allowed = false;
        project_panel.indent_size = 15;
        remove_trailing_whitespace_on_save = false;
        show_edit_predictions = false;
        soft_wrap = "editor_width";
        tab_size = 2;
        terminal.working_directory = "current_project_directory";
        theme = "Ayu Dark";
        use_system_path_prompts = false;
        vim_mode = false;
      };
    };
    keymap = mkOption {
      type = types.listOf types.attrs;
      default = [
        {
          bindings = {"ctrl-`" = "workspace::ToggleBottomDock";};
          context = "Workspace";
        }
        {
          bindings = {
            alt-q = "editor::ShowEditPrediction";
            kp_1 = [
              "workspace::SendKeystrokes"
              "NUMPAD_1"
            ];
            kp_enter = [
              "workspace::SendKeystrokes"
              "enter"
            ];
          };
          context = "Editor";
        }
        {
          bindings = {
            alt-l = null;
            alt-q = "editor::AcceptEditPrediction";
            alt-tab = "editor::Tab";
            tab = "editor::Tab";
          };
          context = "Editor && edit_prediction";
        }
        {
          bindings = {
            alt-l = null;
            alt-q = "editor::AcceptEditPrediction";
            alt-tab = "editor::Tab";
          };
          context = "Editor && edit_prediction_conflict";
        }
        {
          bindings = {
            alt-s = [
              "terminal::SendText"
              ""
            ];
          };
          context = "Terminal";
        }
      ];
    };
    tasks = mkOption {
      type = types.listOf types.attrs;
      default = [];
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      shanetrs.desktop.mime = {
        added."inode/directory" = mkAfter ["dev.zed.Zed.desktop"];
        default = {
          "application/csv" = ["dev.zed.Zed.desktop"];
          "application/json" = ["dev.zed.Zed.desktop"];
          "application/xml" = ["dev.zed.Zed.desktop"];
          "text/plain" = ["dev.zed.Zed.desktop"];
        };
      };
      tundra = {
        xdg.config = {
          "zed/settings.json" = {
            type = "execute";
            source = mergeFormat "json" cfg.settings;
          };
          "zed/keymap.json" = {
            type = "execute";
            source = mergeFormat "json" cfg.keymap;
          };
          "zed/tasks.json" = {
            type = "execute";
            source = mergeFormat "json" cfg.tasks;
          };
        };
        packages = [
          (pkgs.symlinkJoin {
            name = "zed-editor-wrapped";
            paths = [cfg.package];
            preferLocalBuild = true;
            nativeBuildInputs = with pkgs; [makeWrapper];
            postBuild = ''
              wrapProgram $out/bin/zeditor \
              --suffix PATH : ${lib.makeBinPath (cfg.extraPackages
                ++ (with pkgs;
                  resolveList [
                    shanetrs.devcontainer
                    gcc
                    clang-tools
                    package-version-server
                  ]))}
            '';
          })
        ];
      };
    }

    (mkIf (elem "nix" cfg.features) {
      shanetrs.programs.zed-editor = {
        extraPackages = with pkgs; [nixd alejandra];
        settings = mkOptionDefault {
          auto_install_extensions = {
            nix = true;
            toml = true;
          };
          languages.Nix = {
            formatter.external = {
              arguments = ["fmt" "--"];
              command = "nix";
            };
            hard_tabs = false;
            language_servers = ["nixd" "!nil"];
          };
          lsp.nixd.settings.diagnostic.suppress = [
            "sema-escaping-with"
            "sema-unused-def-lambda-witharg-formal"
          ];
        };
      };
    })

    (mkIf (elem "rust" cfg.features) {
      shanetrs.programs.zed-editor = {
        extraPackages = with pkgs; [rustup];
        settings = mkOptionDefault {
          auto_install_extensions.toml = true;
          languages.Rust = {
            formatter.external = {
              arguments = [
                "--config"
                "hard_tabs=true"
                "--edition"
                "2021"
              ];
              command = "rustfmt";
            };
          };
          lsp.rust-analyzer = {
            binary.path = "rust-analyzer";
            initialization_options = {
              cachePriming.enable = false;
              cargo.buildScripts.enable = false;
              checkOnSave = true;
              inlayHints = {
                closureCaptureHints.enable = true;
                expressionAdjustmentHints = {
                  enable = "always";
                  hideOutsideUnsafe = true;
                };
                implicitDrops.enable = true;
                implicitSizedBoundHints.enable = true;
                lifetimeElisionHints.enable = "skip_trivial";
              };
            };
          };
        };
      };
    })
  ]);
}
