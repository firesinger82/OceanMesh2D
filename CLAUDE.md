# CLAUDE.md - OceanMesh2D Developer Guide for AI Assistants

**Last Updated:** 2025-11-20
**Version:** 6.0.0+
**Branch:** Projection (Recommended)

---

## Table of Contents

1. [Repository Overview](#repository-overview)
2. [Codebase Structure](#codebase-structure)
3. [Core Architecture](#core-architecture)
4. [Development Workflow](#development-workflow)
5. [Testing Conventions](#testing-conventions)
6. [File Formats and Standards](#file-formats-and-standards)
7. [Key Conventions](#key-conventions)
8. [Common Tasks Guide](#common-tasks-guide)
9. [Important Gotchas](#important-gotchas)
10. [Git Workflow](#git-workflow)

---

## Repository Overview

**OceanMesh2D** is a MATLAB-based software package for generating two-dimensional unstructured meshes for coastal ocean circulation models (primarily ADCIRC). The toolbox uses feature-driven geometric and bathymetric mesh size functions combined with a force-balance algorithm to create high-quality triangular meshes.

### Key Features
- Distance-based automatic mesh generation
- No paid MATLAB toolboxes required
- Object-oriented design with four main classes
- Pre/post-processing workflows for ADCIRC model
- Support for multi-scale nested meshes
- High-fidelity shoreline constraint generation

### Primary Use Cases
- Coastal ocean modeling (storm surge, tides, circulation)
- Mesh generation for ADCIRC, SWAN, SCHISM, and similar models
- Automated mesh size function generation from bathymetry/geography
- Multi-resolution nesting for regional to local scales

### References
- Main paper: Roberts et al. (2019) GMD, https://doi.org/10.5194/gmd-12-1847-2019
- User guide: Available in `UserGuide/` directory (PDF)
- Examples: 14 progressive examples from simple to complex

---

## Codebase Structure

### Directory Layout

```
OceanMesh2D/
├── @geodata/              # Geographic data processing class
│   ├── geodata.m          # Constructor and public methods
│   └── private/           # 11 private helper functions
├── @edgefx/               # Mesh size function class
│   ├── edgefx.m           # Constructor and sizing methods
│   └── private/           # 6 private helper functions
├── @meshgen/              # Mesh generation class
│   ├── meshgen.m          # Force-balance mesh generator
│   └── private/           # 11 private helper functions
├── @msh/                  # Mesh storage/manipulation class (largest)
│   ├── msh.m              # 50+ public methods
│   └── private/           # 19 private functions (readers/writers)
├── @ann/                  # Approximate Nearest Neighbor class
│   ├── ann.m              # KD-tree search wrapper
│   └── private/           # C++ ANN library + 4 MEX binaries
├── Examples/              # 14 example scripts
│   ├── Example_1_NZ.m     # Basic: South Island NZ
│   ├── Example_2_NY.m     # High-res LiDAR: Manhattan
│   ├── Example_3_ECGC.m   # Nested: East Coast with NY nest
│   ├── Example_4_PRVI.m   # Multi-nest: Puerto Rico/USVI
│   ├── Example_5_JBAY.m   # Ultra high-fidelity: 15m Jamaica Bay
│   ├── Example_6_GBAY.m   # Thalweg/channel sizing
│   ├── Example_7_Global.m # Global ocean mesh
│   └── runall.m           # Run all examples
├── Tests/                 # Test suite
│   ├── RunTests.m         # Main test runner
│   ├── TestSanity.m       # Basic functionality (Example 1)
│   ├── TestEleSizes.m     # Element sizing validation
│   ├── TestInterp.m       # Interpolation tests
│   ├── TestECGC.m         # Regional mesh test
│   └── TestJBAY.m         # High-fidelity mesh test
├── utilities/             # 160+ helper functions
│   ├── Make_f15.m         # ADCIRC fort.15 generator
│   ├── Calc_f13.m         # ADCIRC fort.13 calculator
│   ├── m_*.m              # m_map plotting wrappers
│   ├── GEOM_UTIL/         # mesh2d library utilities
│   └── Nodal_Reduce_Matlab_Codes/ # Mesh decimation
├── datasets/              # Global datasets (downloaded by setup)
│   ├── GSHHS/             # Global shoreline
│   └── SRTM15/            # Global bathymetry
├── UserGuide/             # Documentation
│   └── OceanMesh2D.pdf    # Comprehensive user guide
├── setup.sh / setup.bat   # Platform-specific setup scripts
├── setup_oceanmesh2d.m    # MATLAB path configuration
└── README.md              # Main documentation

Key Files NOT in Repo (downloaded by setup):
├── m_map/                 # Mapping package (from UBC)
├── datasets/GSHHS_*.shp   # Global shoreline data
└── datasets/SRTM15+.nc    # Global bathymetry DEM
```

### File Counts and Sizes
- **@geodata**: ~870 lines (main class)
- **@edgefx**: ~1075 lines (main class)
- **@meshgen**: ~1177 lines (main class)
- **@msh**: ~4403 lines (main class) - largest and most complex
- **utilities**: 160+ standalone functions
- **Examples**: 14 example scripts
- **Tests**: 8 test scripts

---

## Core Architecture

### The Four-Class Pipeline

OceanMesh2D uses a sequential object-oriented pipeline:

```matlab
% Typical workflow:
gdat = geodata(...)    % 1. Process geographic data
fh = edgefx(...)       % 2. Build mesh size functions
mshopts = meshgen(...) % 3. Generate mesh
m = mshopts.grd        % 4. Extract and post-process mesh
```

### Class Details

#### 1. `@geodata` - Geographic Data Processing

**Purpose**: Load, process, and classify geographic data (coastlines, DEMs, shapefiles)

**Key Properties**:
- `bbox`: Bounding box [lon_min lon_max; lat_min lat_max]
- `mainland`: Mainland polygon (outer boundary)
- `outer`: Outer boundary polygon (simplified)
- `inner`: Inner boundary polygons (islands, lakes)
- `Fb`, `Fb2`: Bathymetry interpolant objects
- `weirs`: Weir/barrier crestlines
- `boubox`: Boundary box for meshing domain

**Key Methods**:
- `geodata()`: Constructor - loads shapefiles/DEMs
- `ParseShoreline()`: Process coastline data
- `ClassifyShoreline()`: Classify as mainland/islands
- `ParseDEM()`: Load and process DEM data
- `extractContour()`: Extract elevation contours
- `plot()`: Visualize boundaries and bathymetry

**Input Formats**:
- Shapefiles (`.shp`)
- NetCDF DEMs (`.nc`)
- GeoTIFF (`.tif`)
- KML files (via utilities)

**Private Methods** (in `@geodata/private/`):
- `Read_shapefile.m`, `coarsen_polygon.m`, `densify.m`, `smooth_coastline.m`

---

#### 2. `@edgefx` - Mesh Size Functions

**Purpose**: Define spatially-varying mesh element size based on geometric/bathymetric features

**Key Properties**:
- `fs`: Feature size resolution (elements per feature width)
- `wl`, `wld`: Wavelength-based sizing
- `slp`, `slpd`: Slope-based sizing
- `ch`, `chd`: Channel/thalweg sizing
- `g`: Mesh grade (transition rate, 0-1)
- `F`: Final gridded interpolant (combined size function)

**Key Methods**:
- `edgefx()`: Constructor
- `distfx()`: Distance-based sizing (nearshore refinement)
- `featfx()`: Feature-based sizing (resolve channels, islands)
- `wlfx()`: Wavelength sizing (CFL-based)
- `slpfx()`: Slope-based sizing (bathymetric gradients)
- `chfx()`: Channel sizing (polyline/thalweg)
- `finalize()`: Combine all functions and create interpolant
- `plot()`: Visualize size function

**Size Function Types**:
1. **Distance-based**: Refine near coastline
2. **Feature-based**: Resolve geometric features (width-based)
3. **Wavelength-based**: CFL stability constraint
4. **Slope-based**: Bathymetric gradient resolution
5. **Channel-based**: Polyline/thalweg refinement

**Grading**: All functions respect grade `g` (typical: 0.15-0.35)

---

#### 3. `@meshgen` - Mesh Generation

**Purpose**: Generate mesh using force-balance algorithm with topological improvements

**Key Properties**:
- `fd`: Distance function (signed distance to boundary)
- `fh`: Edge length function (from edgefx)
- `h0`: Minimum element size
- `pfix`: Fixed points (user-specified or boundary)
- `egfix`: Fixed edges (constraints)
- `grd`: Output mesh (msh object)
- `qual`: Quality metrics [mean, lower_3rd_percentile, min]
- `nscreen`: Plot refresh interval
- `cleanup`: Quality improvement options

**Key Methods**:
- `meshgen()`: Constructor
- `build()`: Main mesh generation loop
- `plot()`: Visualize during generation

**Algorithm**:
1. **Initial Point Distribution**: Poisson disk sampling
2. **Delaunay Triangulation**: MATLAB `delaunay()`
3. **Force-Balance**: Move vertices based on spring forces
4. **Topology Improvement**: `delaunay_elim()` removes low-quality elements
5. **Boundary Projection**: Snap to constraints
6. **Iterate**: Until quality converges

**Quality Metrics**:
- Mean quality (target: >0.90)
- Lower 3rd percentile (target: >0.70)
- Minimum quality (target: >0.25-0.35)

**Cleanup Options** (`ds` parameter):
- `0`: No cleanup
- `1`: Implicit smoothing (preserves fixed points)
- `2`: Moderate cleanup (default)
- `3`: Aggressive cleanup

---

#### 4. `@msh` - Mesh Storage and Manipulation

**Purpose**: Store, read, write, visualize, and manipulate meshes and auxiliary data

**Key Properties**:
- `p`: Vertex coordinates [NP x 2]
- `t`: Triangle connectivity [NT x 3]
- `b`: Bathymetry/elevation values [NP x 1]
- `bd`: Boundary data structure (nodestrings)
- `op`: Open boundary data
- `f13`, `f15`, `f19`, `f20`, `f24`: ADCIRC file structures
- `proj`, `coord`, `mapvar`: Projection info (m_map)
- `pfix`, `egfix`: Fixed constraints

**50+ Methods** (most important listed):

**I/O Methods**:
- `read()`: Read fort.14/13/15/24, 2dm, mat files
- `write()`: Write fort.14/13/15/24, 2dm, mat files

**Boundary Methods**:
- `make_bc()`: Generate boundary conditions (auto, manual)
- `get_boundary_of_mesh()`: Extract boundary polygons

**Interpolation**:
- `interp()`: Interpolate DEM to mesh vertices
  - Methods: `linear`, `nearest`, `CA` (cell-averaging)
  - Options: `slope_calc`, `nan_fill`, `invert`

**Quality/Refinement**:
- `clean()`: Topology cleaning (uses `ds` parameter)
- `bound_courant_number()`: CFL-limited refinement

**Mesh Operations**:
- `plus()`, `minus()`, `cat()`: Mesh algebra (merge, subtract, concatenate)
- `remesh_patch()`: Remesh subdomain and insert back
- `map_mesh_properties()`: Transfer attributes between meshes

**Visualization**:
- `plot()`: Advanced plotting with many options
  - Types: `'tri'`, `'tricontour'`, `'bd'`, `'b'`, arbitrary f13
  - Options: `'subdomain'`, `'colormap'`, `'axis'`, `'log'`

**ADCIRC Utilities**:
- Numerous methods for ADCIRC file generation/manipulation
- See `private/` directory for readers/writers

---

#### 5. `@ann` - Approximate Nearest Neighbor

**Purpose**: Fast spatial searches using KD-trees (C++ library wrapper)

**Key Methods**:
- `ann()`: Constructor - builds KD-tree
- `ksearch()`: K-nearest neighbors
- `prisearch()`: Priority search
- `frsearch()`: Fixed radius search
- `close()`: Release memory (important!)

**Implementation**: MATLAB wrapper for David Mount & Sunil Arya's ANN library

**Performance**: Essential for large meshes (>100k points)

---

### Design Patterns

#### Object-Oriented Pipeline
Each class feeds into the next, creating a clear workflow:
```matlab
geodata → edgefx → meshgen → msh
```

#### Immutability with Mutation
Methods often return modified objects:
```matlab
m = make_bc(m, 'auto', gdat);  % Returns modified mesh
m = interp(m, gdat);           % Returns modified mesh
```

#### Name-Value Pairs
Heavy use of `varargin` with MATLAB's `inputParser`:
```matlab
gdat = geodata('shp', file, 'bbox', bbox, 'h0', min_el);
fh = edgefx('geodata', gdat, 'fs', 3, 'max_el', 100e3);
```

#### Projection Handling
All classes check for m_map dependency:
```matlab
if exist('m_proj','file') ~= 2
    error('Where''s m_map? Please read the user guide')
end
```

---

## Development Workflow

### Initial Setup

**Prerequisites**:
- MATLAB R2018a or newer (no paid toolboxes required)
- Internet connection (for downloading dependencies)
- 5+ GB disk space (for datasets)

**Setup Steps**:
```bash
# 1. Clone repository
git clone https://github.com/CHLNDDEV/OceanMesh2D.git
cd OceanMesh2D

# 2. Run setup script
./setup.sh          # Linux/Mac
setup.bat           # Windows

# This downloads:
#   - m_map v1.4 (mapping package)
#   - GSHHS global shoreline
#   - SRTM15+ global bathymetry

# 3. Configure MATLAB startup
# Edit ~/Documents/MATLAB/startup.m and add:
run('/path/to/OceanMesh2D/setup_oceanmesh2d.m')

# 4. Restart MATLAB
```

**Verifying Setup**:
```matlab
% In MATLAB:
which m_proj      % Should return m_map path
which geodata     % Should return OceanMesh2D path
```

---

### Development Branches

**PROJECTION** (default, recommended):
- Current stable branch
- All new features and fixes
- Use this for development

**MASTER** (legacy):
- Pre-projection coordinate system
- Not recommended for new work

**DEV** (bleeding edge):
- Experimental features
- May be unstable

---

### Making Changes

#### Typical Development Flow
1. Create feature branch from `Projection`
2. Make changes to classes or utilities
3. Test with `RunTests.m`
4. Test relevant examples
5. Commit with descriptive messages
6. Create pull request

#### File Modification Guidelines
- **Classes**: Edit `@classname/classname.m` or `@classname/private/*.m`
- **Utilities**: Edit or add to `utilities/`
- **Examples**: Add to `Examples/` (not tracked in git)
- **Tests**: Update `Tests/` if adding features

---

### Pull Request Process

Per README.md Contributing section:

1. **Fork** the repository
2. **Clone** your fork
3. **Create feature branch**
4. **Make changes** and commit
5. **Run tests**: Ensure `RunTests.m` passes
6. **Run examples**: Test relevant examples work
7. **Push** to your fork
8. **Create Pull Request** with:
   - Clear description of changes
   - Minimal working examples demonstrating functionality
   - Good commit messages

**Acceptance Criteria**:
- All tests pass (`RunTests.m`)
- Examples still work (maintainers test locally)
- Code follows existing conventions
- Changes are well-documented

---

## Testing Conventions

### Test Structure

Tests are located in `Tests/` directory:

```
Tests/
├── RunTests.m         # Main test runner (sequential)
├── TestSanity.m       # Basic functionality (Example 1)
├── TestEleSizes.m     # Element sizing validation
├── TestInterp.m       # Interpolation tests
├── TestECGC.m         # Regional mesh (requires SRTM15+.nc)
├── TestJBAY.m         # High-fidelity mesh (requires PostSandy data)
└── (others)
```

### Running Tests

```matlab
% From MATLAB:
cd Tests/
RunTests

% Or from command line:
matlab -batch "cd Tests; RunTests"
```

### Test Pattern

Each test follows this pattern:

```matlab
% 1. Run example script
run('../Examples/Example_1_NZ.m')

% 2. Define tolerances
NP_TOL = 500;        % Vertex count tolerance
NT_TOL = 1500;       % Triangle count tolerance
QUAL_TOL = 0.25;     % Minimum quality tolerance

% 3. Define expected values
TARGET_NP = 5968;
TARGET_NT = 9530;

% 4. Validate results
assert(abs(length(m.p) - TARGET_NP) < NP_TOL, 'Wrong vertex count');
assert(abs(length(m.t) - TARGET_NT) < NT_TOL, 'Wrong triangle count');
assert(mshopts.qual(end,3) > QUAL_TOL, 'Quality too low');

% 5. Report success
fprintf('Passed: %s\n', PREFIX);
```

### Quality Metrics

Mesh quality is reported as a 3-element vector:
```
[mean, lower_3rd_percentile, minimum]
```

Typical expectations:
- **Mean quality**: 0.90-0.95
- **Lower 3rd percentile**: 0.70-0.80
- **Minimum quality**: 0.25-0.40

Quality is computed as:
```
q = 4*sqrt(3)*Area / (sum of squared edge lengths)
```
Perfect equilateral triangle: q = 1.0

---

### Test Dependencies

| Test | Required Data | Source |
|------|---------------|--------|
| TestSanity | GSHHS shoreline | setup.sh |
| TestEleSizes | GSHHS shoreline | setup.sh |
| TestInterp | GSHHS shoreline | setup.sh |
| TestECGC | SRTM15+.nc | setup.sh |
| TestJBAY | PostSandyNCEI.nc/.shp | Zenodo manual download |

---

## File Formats and Standards

### ADCIRC File Formats

OceanMesh2D primarily generates files for the ADCIRC model:

#### fort.14 (Mesh/Grid File)
- Vertices, triangles, bathymetry
- Open/land boundary specifications
- Written by: `write(m, 'filename')`

#### fort.13 (Nodal Attributes File)
- Manning's n, primitive weighting, etc.
- Generated by: `Calc_f13()`, `Make_f13()`
- Structure stored in: `m.f13`

#### fort.15 (Model Control File)
- Simulation parameters, timesteps, physics
- Generated by: `Make_f15()`
- Structure stored in: `m.f15`

#### Other Files
- **fort.19**: Non-periodic elevation boundaries
- **fort.20**: River flux boundaries
- **fort.24**: SAL (Self Attraction and Loading)

---

### SMS 2dm Format

OceanMesh2D can read/write SMS 2dm format:
```matlab
m = msh('fname.2dm');        % Read
write(m, 'output', '2dm');   % Write
```

---

### MATLAB .mat Format

```matlab
save('mesh.mat', 'm');       % Save msh object
load('mesh.mat', 'm');       % Load msh object
```

---

### Coordinate Systems

**Supported**:
- **Geographic**: WGS84 lat/lon (most common)
- **Projected**: UTM, State Plane, etc. (via m_map)

**Projection Handling**:
- Set via `'proj'` parameter in meshgen
- Options: `'trans'` (transverse Mercator), `'stereo'`, `'lambert'`, etc.
- All internal calculations in planar meters
- Output can be geographic or projected

**Important**: Meshes store projection info in `m.coord` and `m.proj`

---

## Key Conventions

### Naming Conventions

#### Variables
- `gdat`: geodata object
- `fh`: edgefx object
- `mshopts`: meshgen object
- `m`: msh object
- `p`: Vertex coordinates [N x 2]
- `t`: Triangle connectivity [N x 3]
- `b`: Bathymetry values [N x 1]
- `obj`: Generic class instance

#### Files
- **Classes**: `@classname/classname.m`
- **Private methods**: `@classname/private/FunctionName.m`
- **ADCIRC utilities**: `Make_f##.m`, `Calc_*.m`
- **m_map wrappers**: `m_*.m`
- **Examples**: `Example_#_ABBREV.m`

#### Functions
- **CamelCase**: `Make_f15()`, `Calc_f13()`, `GridData()`
- **snake_case**: `extract_subdomain()`, `tidal_data_to_ob()`
- Mixed conventions (historical)

---

### Coding Style

#### Comments
Extensive header comments in all functions:
```matlab
%FUNCTION_NAME - Brief description
%
% Syntax:  [output1,output2] = function_name(input1,input2)
%
% Inputs:
%    input1 - Description
%    input2 - Description
%
% Outputs:
%    output1 - Description
%    output2 - Description
%
% Example:
%    output = function_name(data)
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% Author: Name
% Date: YYYY-MM-DD
```

#### Error Handling
- Dependency checks in constructors
- Informative error messages with suggestions
- Warnings for non-critical issues

Example:
```matlab
if ~exist('m_proj', 'file')
    error('OceanMesh2D requires m_map! Run setup.sh/setup.bat')
end
```

#### Assertions
Use for validation:
```matlab
assert(size(bbox,1)==2, 'bbox must be 2x2 matrix');
```

---

### MATLAB-Specific Patterns

#### inputParser
Heavy use for name-value pairs:
```matlab
p = inputParser;
addParameter(p, 'bbox', [], @isnumeric);
addParameter(p, 'h0', 1e3, @isnumeric);
parse(p, varargin{:});
bbox = p.Results.bbox;
h0 = p.Results.h0;
```

#### Handle Classes
All main classes use handle semantics:
```matlab
classdef msh < handle
    % Methods modify object in-place
end
```

#### Persistent Variables
Used for caching in utilities:
```matlab
persistent cached_data;
if isempty(cached_data)
    cached_data = load_expensive_data();
end
```

---

## Common Tasks Guide

### Task 1: Create a Basic Mesh

```matlab
clearvars; clc;

% 1. Define domain
bbox = [lon_min lon_max; lat_min lat_max];
min_el = 1e3;       % 1 km minimum
max_el = 100e3;     % 100 km maximum
grade = 0.35;       % 35% grade

% 2. Load geographic data
gdat = geodata('shp', 'GSHHS_f_L1', 'bbox', bbox, 'h0', min_el);

% 3. Build mesh size function
fh = edgefx('geodata', gdat, 'fs', 3, 'max_el', max_el, 'g', grade);

% 4. Generate mesh
mshopts = meshgen('ef', fh, 'bou', gdat, 'plot_on', 1);
mshopts = mshopts.build;

% 5. Post-process
m = mshopts.grd;
m = make_bc(m, 'auto', gdat);

% 6. Write output
write(m, 'output_mesh');
```

---

### Task 2: Add Bathymetry from DEM

```matlab
% Assume m is a mesh object, gdat has DEM loaded

% Method 1: Simple interpolation
m = interp(m, gdat);

% Method 2: Cell-averaging (smoother)
m = interp(m, gdat, 'method', 'CA');

% Method 3: Custom options
m = interp(m, gdat, ...
    'method', 'linear', ...
    'slope_calc', 'abs', ...
    'nan_fill', true, ...
    'invert', true);  % Positive up
```

---

### Task 3: Create ADCIRC fort.15

```matlab
% Basic fort.15 generation
Make_f15(m, ...
    'timestep', 1.0, ...           % seconds
    'start_date', '2020-01-01', ...
    'end_date', '2020-01-31', ...
    'constituents', 'major8', ...  % or cell array
    'Coriolis', true);

% With custom namelists
namelists = struct();
namelists.wetdry = struct('h0', 0.1, 'velmin', 0.05);
namelists.windstress = struct('nws', 8, 'wtiminc', 3600);

Make_f15(m, 'timestep', 1.0, 'namelist', namelists);
```

---

### Task 4: Merge Two Meshes

```matlab
% Load two meshes
m1 = msh('mesh1.14');
m2 = msh('mesh2.14');

% Merge (concatenate)
m_combined = plus(m1, m2);  % or: m_combined = m1 + m2;

% Clean up overlaps
m_combined = clean(m_combined, 'ds', 2);
```

---

### Task 5: Extract Subdomain

```matlab
% Define subdomain bbox
bbox_sub = [lon_min lon_max; lat_min lat_max];

% Extract subdomain
m_sub = extract_subdomain(m, bbox_sub);

% Or keep original numbering
m_sub = extract_subdomain(m, bbox_sub, 'keep_numbering', true);
```

---

### Task 6: Refine Mesh Based on CFL

```matlab
% CFL-limited refinement
dt = 1.0;  % timestep in seconds
Cr = 0.5;  % Courant number limit

m_refined = bound_courant_number(m, 'dt', dt, 'Cr', Cr);
```

---

### Task 7: Add Manning's n from Land Cover

```matlab
% Calculate Manning's n from NLCD or CCAP
m = Calc_Mannings_Landcover(m, 'nlcd', 'NLCD_data.tif', ...
    'method', 'linear');

% Or use cell-averaging
m = Calc_Mannings_Landcover(m, 'ccap', 'CCAP_data.tif', ...
    'method', 'CA');
```

---

### Task 8: Create Tidal Boundary Conditions

```matlab
% Automatic tidal BC from TPXO
m = tidal_data_to_ob(m, 'TPXO9_atlas_path/**', ...
    'constituents', {'M2', 'S2', 'K1', 'O1'});

% Or use 'major8' for standard constituents
m = tidal_data_to_ob(m, 'TPXO9_atlas_path/**', ...
    'constituents', 'major8');
```

---

### Task 9: Visualize Mesh

```matlab
% Basic triangulation plot
plot(m, 'type', 'tri');

% Bathymetry with colorbar
plot(m, 'type', 'b', 'colormap', 'cmocean');

% Boundary conditions
plot(m, 'type', 'bd');

% Subdomain view
plot(m, 'type', 'tri', 'subdomain', bbox_sub);

% Custom f13 attribute
plot(m, 'type', 'ManningsN', 'log', true);
```

---

### Task 10: Read Existing Mesh

```matlab
% Read fort.14
m = msh('mesh.14');

% Read multiple ADCIRC files
m = msh('mesh.14');
m = m.read({'fort.13', 'fort.15'});

% Read 2dm format
m = msh('mesh.2dm');
```

---

## Important Gotchas

### 1. m_map Dependency

**Issue**: All classes require m_map, even if not using projections

**Solution**: Always run setup.sh/setup.bat first

**Check**:
```matlab
if exist('m_proj', 'file') ~= 2
    error('Run setup.sh to download m_map');
end
```

---

### 2. Polygon Orientation

**Issue**: Boundaries must be counter-clockwise (CCW) for outer, clockwise (CW) for inner

**Solution**: geodata handles this automatically, but manual polygons need:
```matlab
[lat, lon] = poly2ccw(lat, lon);  % Outer boundaries
[lat, lon] = poly2cw(lat, lon);   % Inner boundaries (islands)
```

---

### 3. Bathymetry Sign Convention

**Issue**: ADCIRC uses positive-down (depth), some DEMs use positive-up (elevation)

**Solution**: Use `'invert'` parameter:
```matlab
m = interp(m, gdat, 'invert', true);  % If DEM is elevation
```

---

### 4. Memory Usage in Large Meshes

**Issue**: meshgen can consume large amounts of memory for >500k vertices

**Solution**: Use `'memory_gb'` parameter:
```matlab
mshopts = meshgen(..., 'memory_gb', 8);  % Limit to 8 GB
```

---

### 5. Projection Consistency

**Issue**: Mixing geographic and projected coordinates causes errors

**Solution**: Always check `m.coord`:
```matlab
if strcmp(m.coord, 'geographic')
    % Use lat/lon
else
    % Use projected coordinates
end
```

---

### 6. Boundary Classification

**Issue**: `make_bc(..., 'auto', ...)` may misclassify boundaries

**Solution**:
- Use `'distance'` method for complex geometries
- Or manually specify boundaries:
```matlab
m = make_bc(m, 'outer', 1);     % First boundary is ocean
m = make_bc(m, 'inner', [2 3]); % Others are islands
```

---

### 7. Quality Degradation During Cleaning

**Issue**: `clean()` with high `ds` may remove boundary elements

**Solution**: Use moderate cleaning:
```matlab
m = clean(m, 'ds', 2);  % Default, safe
% Avoid ds=3 near boundaries
```

---

### 8. Fixed Points Not Preserved

**Issue**: Mesh cleaning/smoothing moves fixed points

**Solution**: Use implicit smoother:
```matlab
m = clean(m, 'ds', 1);  % Preserves fixed points
```

---

### 9. NaN Values in Interpolation

**Issue**: Vertices outside DEM bounds get NaN bathymetry

**Solution**: Use `'nan_fill'` option:
```matlab
m = interp(m, gdat, 'nan_fill', true);
```

---

### 10. Test Tolerances

**Issue**: Mesh generation is stochastic, vertex counts vary

**Solution**: Tests use tolerances (±500 vertices, ±1500 elements)

**When to worry**: Differences >10% from expected values

---

## Git Workflow

### Branch Structure

```
main branches:
├── Projection (default, recommended)
├── MASTER (legacy)
└── DEV (experimental)

feature branches:
├── feature/description
├── bugfix/description
└── docs/description
```

---

### Commit Message Conventions

Follow existing patterns:

```
TYPE: Brief description (#issue)

Longer description if needed.

Examples:
- BUGFIX: Fix boundary classification in make_bc (#123)
- FEATURE: Add high-fidelity constraint generation (#264)
- IMPRV: Optimize KD-tree searches in ann class
- DOC: Update user guide with new examples
```

---

### Pull Request Checklist

Before submitting PR:

- [ ] All tests pass (`RunTests.m`)
- [ ] Relevant examples still work
- [ ] Code follows existing style
- [ ] Functions have header comments
- [ ] Minimal working example provided
- [ ] Changes documented in commit messages

---

## Additional Resources

### Documentation
- **User Guide**: `UserGuide/OceanMesh2D.pdf` (comprehensive)
- **README**: Main repository documentation
- **Examples**: 14 progressive examples
- **Help**: `doc classname` in MATLAB

### External Links
- **Repository**: https://github.com/CHLNDDEV/OceanMesh2D
- **Issues**: https://github.com/CHLNDDEV/OceanMesh2D/issues
- **Slack**: https://join.slack.com/t/oceanmesh2d/shared_invite/...
- **Zenodo Datasets**: https://doi.org/10.5281/zenodo.2605388
- **Main Paper**: https://doi.org/10.5194/gmd-12-1847-2019

### Contact
- Dr. William Pringle: wpringle@anl.gov
- Dr. Keith Roberts: keithrbt0@gmail.com

---

## For AI Assistants: Quick Reference

### When Working With This Codebase

**DO**:
- ✓ Run tests after modifications (`cd Tests; RunTests`)
- ✓ Follow the four-class pipeline pattern
- ✓ Use name-value pair syntax for flexibility
- ✓ Check for m_map dependency in new code
- ✓ Preserve existing code style and conventions
- ✓ Add header comments to new functions
- ✓ Test with examples before committing
- ✓ Use tolerances when validating mesh outputs

**DON'T**:
- ✗ Modify class files without understanding the pipeline
- ✗ Add dependencies on paid MATLAB toolboxes
- ✗ Break backward compatibility without discussion
- ✗ Commit example output files (*.mat, fort.*, etc.)
- ✗ Push to MASTER or DEV without explicit direction
- ✗ Change quality thresholds in tests arbitrarily
- ✗ Assume mesh generation is deterministic

---

### Common User Questions

**"How do I create a mesh?"**
→ See [Task 1: Create a Basic Mesh](#task-1-create-a-basic-mesh)

**"Tests are failing"**
→ Check m_map is installed, GSHHS data exists, tolerances are reasonable

**"Mesh quality is poor"**
→ Adjust grade (lower = smoother), check boundaries, use `clean()`

**"Interpolation gives NaN"**
→ DEM doesn't cover mesh extent, use `'nan_fill'` option

**"Memory errors"**
→ Use `'memory_gb'` parameter, reduce `h0`, increase `max_el`

**"Boundaries misclassified"**
→ Use `make_bc(..., 'distance')` or manual classification

---

### Debugging Tips

1. **Enable plotting**: `'plot_on', 1` in meshgen
2. **Check intermediate steps**: Visualize gdat, fh before meshing
3. **Reduce problem size**: Smaller bbox for testing
4. **Check coordinate system**: `m.coord`, `m.proj`
5. **Validate inputs**: `assert()` for bbox, h0, etc.
6. **Use MATLAB debugger**: `dbstop if error`

---

**End of CLAUDE.md**
