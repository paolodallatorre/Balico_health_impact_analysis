# Fill path placeholders in an InMAP TOML config and save a new file.
# Placeholders supported: ${path_to_data}, ${input_path}, ${output_path}
#
# Usage:
#   Rscript fill_config_paths.R --template Config_github.toml --out Config.toml \
#     --path_to_data "/abs/path/to/data" --input_path "/abs/path/to/input" --output_path "/abs/path/to/output"
#
# If you omit any of the paths, simple defaults are used relative to the template.

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NA_character_) {
  i <- match(flag, args)
  if (!is.na(i) && i < length(args)) return(args[i + 1])
  default
}

timestamp <- format(Sys.Date(), "%y.%m.%d")

template <- get_arg("--template", "Config_template.toml")
config_out <- get_arg("--out", sprintf("Config_%s.toml",timestamp))

# Defaults: folders next to the template
template_dir <- normalizePath(dirname(template), winslash = "/", mustWork = FALSE)
run_dir <- file.path(template_dir,timestamp)

#adjust accordingly path_to_data is where the eval_data should be
path_to_data <- get_arg("--path_to_data", file.path(template_dir, "data"))
input_path   <- get_arg("--input_path",   file.path(run_dir, "input"))
output_path  <- get_arg("--output_path",  file.path(run_dir,"output"))

dir.create(output_path, recursive = TRUE, showWarnings = FALSE)

# Read template as plain text and substitute placeholders.
txt <- readLines(template, warn = FALSE)

repl <- list(
  "${path_to_data}" = path_to_data,
  "${input_path}"   = input_path,
  "${output_path}"  = output_path,
  "${timestamp}"    = timestamp
)

for (k in names(repl)) {
  txt <- gsub(k, repl[[k]], txt, fixed = TRUE)
}

# Build output path inside run_dir
config_out_file_path <- file.path(run_dir, config_out)

writeLines(txt, config_out_file_path)

cat("Wrote:", normalizePath(config_out, winslash = "/", mustWork = FALSE), "\n")
cat("path_to_data:", normalizePath(path_to_data, winslash = "/", mustWork = FALSE), "\n")
cat("input_path:",   normalizePath(input_path,   winslash = "/", mustWork = FALSE), "\n")
cat("output_path:",  normalizePath(output_path,  winslash = "/", mustWork = FALSE), "\n")