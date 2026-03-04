# Balico Health Impact Analysis

This repository contains a reproducible workflow to estimate and visualize the **air pollution and health impacts of emissions from a proposed natural gas power plant** using the **InMAP Source-Receptor Matrix (ISRM)** framework.

The pipeline processes emissions data, prepares model inputs, runs InMAP simulations, and produces spatial outputs and figures for downstream analysis and reporting.

---

# Repository Structure

Balico_health_impact_analysis/

│
├── scripts/
│ ├── 1.pre-processing.R
│ ├── 2.config_file_creation.R
│ ├── 3.post-processing.R
│ ├── 4.plots_github.R
│ └── 5.sociodemographic_analysis.R
│
├── data/
│ └── (ACS demographic data and other inputs)
│
├── Config_template.toml
│
├── 26.02.19/
│ └── Example run directory
│
└── README.md


---

# Overview of the Workflow

The workflow is organized into **five sequential scripts**, each responsible for a stage of the analysis pipeline.

Pre-processing
↓
Config file generation
↓
InMAP simulation
↓
Post-processing
↓
Visualization and sociodemographic analysis



---

# Script Descriptions

## 1. `1.pre-processing.R`

Prepares the emissions and spatial data needed for the InMAP simulation.

Main tasks:

- Load plant emissions data
- Convert emissions into InMAP-compatible units
- Create spatial features for the emission source
- Reproject geometries to **ESRI:102003 (USA Contiguous Albers Equal Area)**
- Export an **InMAP input shapefile**

Output:

run_folder/input_*.shp


---

## 2. `2.config_file_creation.R`

Generates the **InMAP configuration file** for a specific simulation.

Main tasks:

- Load the configuration template (`Config_template.toml`)
- Specify:
  - emissions shapefile
  - pollutant variables
  - output paths
- Write the run-specific configuration file.

Output:

PM concentration surfaces
aggregated exposure datasets
processed spatial layers



---

## 4. `4.plots_github.R`

Generates publication-ready figures.

Examples include:

- PM₂.₅ concentration maps
- Spatial exposure gradients
- Regional impact visualizations

These figures are used for:

- reports
- presentations
- graphical abstracts

---

## 5. `5.sociodemographic_analysis.R`

Links modeled pollution exposure to **demographic characteristics**.

Main tasks:

- Load **ACS demographic data**
- Merge with spatial pollution exposure estimates
- Compute **population-weighted exposure metrics**
- Analyze exposure across socioeconomic and demographic groups.

Outputs:

- exposure inequality summaries
- demographic exposure comparisons
- tables used in reporting

---

# Configuration

The simulation is controlled by a **TOML configuration file**.

Template:

Config_template.toml


Before running a simulation:

1. Copy the template
2. Modify paths and parameters
3. Save the new configuration in the run folder.

Example run:

26.02.19/


This directory contains an example of the full pipeline output for a specific simulation.

---

# Data Requirements

The `data/` directory must contain:

- **ACS demographic data**
- Additional spatial inputs required for demographic analysis.

These files are **not included in the repository** due to size or licensing constraints.

---

# Running the Pipeline

Typical workflow:

### Step 1 — Pre-process emissions

```r
source("scripts/1.pre-processing.R")
```

Step 2 — Generate configuration file

source("scripts/2.config_file_creation.R")

Step 3 — Run InMAP simulation

Run the reduced complexity air dispersion model using the generated config file.

Step 4 — Post-process outputs

source("scripts/3.post-processing.R")

Step 5 — Create plots

source("scripts/4.plots_github.R")

Step 6 — Run demographic analysis

source("scripts/5.sociodemographic_analysis.R")

Dependencies

Key R packages used in this project include:

sf
dplyr
ggplot2
readr
tibble
tidyr
stringr

Additional spatial packages may be required depending on the environment.

Reproducibility

Each run of the pipeline creates a timestamped run directory, ensuring that outputs from different simulations remain fully reproducible and separated.

Example:

26.02.19/

This directory stores:

configuration files

model inputs

processed outputs

figures


Applications

This pipeline was developed to support air pollution health impact assessments, including:

evaluation of proposed power plants

environmental justice analyses

policy-relevant exposure assessments.


Author

Paolo Dalla Torre di Sanguinetto
Harvard T.H. Chan School of Public Health
Bocconi University




