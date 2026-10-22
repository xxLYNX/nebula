# PHP 8.4 CLI on pluto for vendor phpt-style repro (mod_php stays in VM containers).
{ pkgs }:
pkgs.writeShellScriptBin "blackhole-php-debug" ''
  exec ${pkgs.php84}/bin/php \
    -d display_errors=1 \
    -d display_startup_errors=1 \
    -d memory_limit=128M \
    "$@"
''
