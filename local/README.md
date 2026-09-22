Machine-specific config lives here. Everything except this README is gitignored.
Put work paths, SDK exports, and aliases in local/env.sh. The final block of
config/shell/devtools.sh sources it automatically when readable, using
${ALTER_ROOT:-$HOME/alter}/local/env.sh. That file is never committed.
