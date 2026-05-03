{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (builtins) elem;
  inherit (lib) mkAfter mkEnableOption mkIf mkMerge mkOption mkPackageOption types;
  inherit (lib.tundra) mergeFormat;
  cfg = config.shanetrs.programs.zed-editor;
  opt = options.shanetrs.programs.zed-editor;
in {
  options.shanetrs.programs.zed-editor = {
    enable = mkEnableOption "Zed configuration and integration";
    package = mkPackageOption pkgs "zed-editor" {};
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        shanetrs.devcontainer
        gcc
        clang-tools
        package-version-server
      ];
    };
    environment = mkOption {
      type = types.lines;
      default = "__ZED_ENV_SOURCED=1";
    };
    features = mkOption {
      type = types.listOf (types.enum ["java" "nix" "rust"]);
      default = ["nix"];
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
          bindings = {alt-q = "editor::ShowEditPrediction";};
          context = "Editor && !edit_prediction";
        }
        {
          bindings = {alt-q = "editor::AcceptEditPrediction";};
          context = "Editor && edit_prediction";
          unbind = {
            alt-l = "editor::AcceptEditPrediction";
            alt-tab = "editor::AcceptEditPrediction";
            tab = "editor::AcceptEditPrediction";
          };
        }
        {
          bindings = {
            alt-s = [
              "terminal::SendText"
              "s"
            ];
          };
          context = "Terminal";
        }
        {
          bindings = {alt-f9 = "editor::ToggleBreakpoint";};
          context = "Editor";
          unbind = {f9 = "editor::ToggleBreakpoint";};
        }
      ];
    };
    settings = mkOption {
      type = types.attrsOf types.anything;
      default = {
        agent.default_width = 360;
        auto_indent_on_paste = false;
        auto_install_extensions = {
          csv = true;
          git-firefly = true;
          glsl = true;
          html = true;
          ini = true;
          lua = true;
          toml = true;
          xml = true;
        };
        auto_update = false;
        buffer_line_height.custom = 1.5;
        diagnostics.inline = {
          enabled = true;
          padding = 6;
          update_debounce_ms = 15;
        };
        diff_view_style = "unified";
        ensure_final_newline_on_save = false;
        expand_excerpt_lines = 12;
        "experimental.theme_overrides"."editor.invisible" = "#fff";
        extend_comment_on_newline = false;
        file_types.JSONC = ["*.json"];
        git.inline_blame.show_commit_summary = true;
        git_panel = {
          file_icons = true;
          status_style = "label_color";
          tree_view = true;
        };
        hard_tabs = true;
        indent_guides = {
          active_line_width = 2;
          coloring = "indent_aware";
        };
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
        project_panel = {
          diagnostic_badges = true;
          indent_size = 15;
        };
        remove_trailing_whitespace_on_save = false;
        session.trust_all_worktrees = true;
        show_edit_predictions = false;
        soft_wrap = "editor_width";
        tab_bar.show_pinned_tabs_in_separate_row = true;
        tab_size = 2;
        tabs.git_status = true;
        terminal.working_directory = "current_project_directory";
        theme = "Ayu Dark";
        use_system_path_prompts = false;
        vim_mode = false;
      };
    };
    tasks = mkOption {
      type = types.listOf types.attrs;
      default = [];
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      shanetrs.programs.zed-editor = {
        extraPackages = opt.extraPackages.default;
        environment = opt.environment.default;
        features = opt.features.default;
        settings = opt.settings.default;
        keymap = opt.keymap.default;
      };
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
          "zed/env" = {
            type = "execute";
            source = mergeFormat.text.concatLines cfg.environment;
          };
          "zed/keymap.json" = {
            type = "execute";
            source = mergeFormat.json.c cfg.keymap;
          };
          "zed/settings.json" = {
            type = "execute";
            source = mergeFormat.json.c cfg.settings;
          };
          "zed/tasks.json" = {
            type = "execute";
            source = mergeFormat.json.c cfg.tasks;
          };
        };
        packages = [
          (pkgs.symlinkJoin {
            name = "zed-editor-wrapped";
            paths = [
              (pkgs.writeShellScriptBin "zeditor" ''
                set -a
                PATH="${lib.makeBinPath cfg.extraPackages}:$PATH"
                source "${config.tundra.paths.xdg.config}/zed/env"
                exec ${cfg.package}/bin/zeditor --dev-container "$@"
              '')
              cfg.package
            ];
            preferLocalBuild = true;
          })
        ];
      };
    }

    (mkIf (elem "java" cfg.features) {
      shanetrs.programs.zed-editor = {
        extraPackages = with pkgs; [jdt-language-server];
        settings = {
          auto_install_extensions.java = true;
          languages.Java.format_on_save = "off";
          lsp.jdtls.binary.path = "jdtls";
        };
      };
    })

    (mkIf (elem "nix" cfg.features) {
      shanetrs.programs.zed-editor = {
        extraPackages = with pkgs; [nixd alejandra];
        settings = {
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
        settings = {
          auto_install_extensions.toml = true;
          languages.Rust = {
            formatter.external = {
              arguments = [
                "--config"
                "hard_tabs=true"
                "--edition"
                "2024"
              ];
              command = "rustfmt";
            };
          };
          lsp.rust-analyzer = {
            binary.path = "rust-analyzer";
            initialization_options = {
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
