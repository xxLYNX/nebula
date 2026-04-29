{ pkgs, ... }:
{

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;

    extraConfigLua = ''
      local cmp = require("cmp")

      cmp.setup({
        mapping = {
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.confirm({ select = true })
            else
              fallback()
            end
          end, { "i", "s" }),
        },
      })
    '';

    colorschemes.moonfly.enable = true;
    colorscheme = "moonfly";

    opts = {
      number         = true;
      relativenumber = true;
      wrap           = true;
      cursorline     = true;
      signcolumn     = "yes";
      scrolloff      = 3;
      clipboard      = "unnamedplus";
    };

    extraPackages = with pkgs; [ curl ripgrep file ];

    # ── Syntax highlighting ────────────────────────────────────────────────
    plugins.treesitter = {
      enable = true;
      highlight.enable = true;
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        go gomod gosum gowork
        yaml
        javascript typescript tsx
        bash
        nix
      ];
    };
    plugins.treesitter-context.enable = true;

    # ── LSP ───────────────────────────────────────────────────────────────
    plugins.lsp = {
      enable = true;
      servers = {
        gopls = {
          enable = true;
          settings.gopls = {
            analyses.unusedparams = true;
            staticcheck           = true;
            completeUnimported    = true;
          };
        };
        ts_ls.enable  = true;  # javascript / typescript
        bashls.enable = true;
        nixd.enable   = true;  # nix LSP
      };
    };

    # ── Brace / scope visibility ───────────────────────────────────────────
    plugins.rainbow-delimiters.enable = true;
    plugins.indent-blankline = {
      enable = true;
      settings = {
        indent = { char = "│"; };
        scope = {
          enabled         = true;
          show_start      = true;
          show_end        = true;
          show_exact_scope = true;
        };
      };
    };

    # ── Completion ────────────────────────────────────────────────────────
    plugins.cmp = {
      enable            = true;
      autoEnableSources = true;
      settings = {
        preselect = "cmp.PreselectMode.Item";
        sources = [
          { name = "nvim_lsp"; }
          { name = "path"; }
          { name = "buffer"; }
        ];
        mapping = {
          "<tab>" = "cmp.mapping.complete()";
        };
      };
    };

    # ── Linting ───────────────────────────────────────────────────────────
    plugins.lint = {
      enable = true;
      lintersByFt = {
        go               = [ "golangcilint" ];
        javascript       = [ "eslint" ];
        typescript       = [ "eslint" ];
        typescriptreact  = [ "eslint" ];
        javascriptreact  = [ "eslint" ];
        bash             = [ "shellcheck" ];
      };
    };

    # ── Formatting ────────────────────────────────────────────────────────
    plugins.conform-nvim = {
      enable = true;
      settings = {
        formatters_by_ft = {
          go              = [ "goimports" "gofumpt" ];
          javascript      = [ "prettier" ];
          typescript      = [ "prettier" ];
          javascriptreact = [ "prettier" ];
          typescriptreact = [ "prettier" ];
          bash            = [ "shfmt" ];
          nix             = [ "nixfmt" ];
        };
        format_on_save = {
          timeout_ms   = 500;
          lsp_fallback = true;
        };
      };
    };

    # ── AI code completion ────────────────────────────────────────────────
    plugins.copilot-vim = {
      enable = true;
      settings = {
        no_tab_map = true;
        filetypes  = { "*" = true; };
      };
    };

    plugins.codecompanion = {
      enable = true;
      settings.interactions = {
        chat   = { adapter = "copilot"; };
        inline = { adapter = "copilot"; };
      };
    };

    # ── Keymaps ───────────────────────────────────────────────────────────
    keymaps = [
      {
        mode   = "n";
        key    = "<leader>ac";
        action = "<cmd>CodeCompanionChat<CR>";
        options.desc = "CodeCompanion chat";
      }
      {
        mode   = [ "n" "v" ];
        key    = "<leader>aa";
        action = "<cmd>CodeCompanion<CR>";
        options.desc = "CodeCompanion inline";
      }
      {
        mode   = "n";
        key    = "<leader>ap";
        action = "<cmd>CodeCompanionActions<CR>";
        options.desc = "CodeCompanion actions";
      }
      {
        mode   = "i";
        key    = "<C-l>";
        action = ''copilot#Accept("\<CR>")'';
        options = {
          expr             = true;
          silent           = true;
          replace_keycodes = false;
          desc             = "Accept Copilot suggestion";
        };
      }
    ];
  };

  # Dev toolchain packages
  home.packages = with pkgs; [
    # Go
    go gopls golangci-lint gotools gofumpt
    # JavaScript / TypeScript
    typescript-language-server typescript eslint prettier
    # Bash
    bash-language-server shellcheck shfmt
    # Nix
    nixd nixfmt-rfc-style
  ];
}
