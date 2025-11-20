# OceanMesh2D 격자생성을 위한 Shapefile 구조 가이드

## 개요

OceanMesh2D는 격자 생성 시 해안선과 지형 경계를 정의하기 위해 shapefile을 사용합니다. 이 문서는 shapefile의 필수 구조와 요구사항을 설명합니다.

---

## 1. 지원되는 Shapefile 형식

### 1.1 지오메트리 타입
OceanMesh2D는 다음 지오메트리 타입을 지원합니다:

| 타입 | 설명 | 지원 여부 |
|------|------|-----------|
| **Polygon** | 닫힌 다각형 (첫 점 = 마지막 점) | ✅ 완전 지원 |
| **Polyline** | 선 세그먼트 | ✅ 지원 |
| **Multi-part** | 하나의 피처에 여러 폴리곤 | ✅ 지원 |
| **3D Shapes** | 높이/고도 속성 포함 | ✅ 지원 |
| Point | 점 | ❌ 미지원 |

### 1.2 좌표계
- **형식**: WGS84 경위도 좌표계
- **경도 범위**: -180° ~ 180° 또는 0° ~ 360° (자동 감지)
- **위도 범위**: -90° ~ 90°
- **자오선 교차**: 180°/-180° 자오선을 자동으로 처리

---

## 2. 필수 폴리곤 요구사항

### 2.1 닫힌 폴리곤 (Closure)
**가장 중요한 요구사항**: 모든 폴리곤은 닫혀 있어야 합니다.

```
첫 번째 좌표 = 마지막 좌표
```

**예시**:
```
올바른 폴리곤:
[120.0, 25.0]  ← 시작점
[121.0, 25.0]
[121.0, 26.0]
[120.0, 26.0]
[120.0, 25.0]  ← 종료점 (시작점과 동일)

잘못된 폴리곤:
[120.0, 25.0]  ← 시작점
[121.0, 25.0]
[121.0, 26.0]
[120.0, 26.0]  ← 종료점 (시작점과 다름)
```

**검증 코드** (Read_shapefile.m:212-216):
```matlab
if all(points(1,:) == points(end,:))
    area = shoelace(points(:,1), points(:,2));
else
    area = 999; % 폴리곤이 아님
end
```

### 2.2 자체 교차 금지
- 폴리곤의 선분이 서로 교차하면 안 됨
- 꼬인 폴리곤은 메쉬 생성 실패의 원인

### 2.3 최소 면적 임계값

폴리곤이 메쉬에 포함되려면 최소 면적 조건을 만족해야 합니다:

| 폴리곤 타입 | 최소 면적 | 설명 |
|-------------|-----------|------|
| **섬 (Inner)** | `4 × h0²` | 완전히 bbox 내부에 있는 폴리곤 |
| **본토 (Mainland)** | `100 × h0²` | bbox와 부분적으로 교차하는 폴리곤 |

**예시 계산** (h0 = 1000m):
- 섬 최소 면적: 4 × (1000m)² = 4,000,000 m² = **4 km²**
- 본토 최소 면적: 100 × (1000m)² = 100,000,000 m² = **100 km²**

**코드 위치** (Read_shapefile.m:217-241):
```matlab
if length(find(In == 1)) == length(points)
    % 완전히 bbox 내부
    if area < 4*h0^2
        continue; % 너무 작으면 제외
    end
    % 섬으로 설정
else
    % 부분적으로 bbox 내부
    if area < 100*h0^2
        continue; % 너무 작으면 제외
    end
    % 본토로 설정
end
```

### 2.4 면적 계산 방법
**Shoelace 공식** (신발끈 알고리즘) 사용:

```matlab
function [area] = shoelace(x, y)
    n = length(x);
    area = 0;
    for i = 1:n-1
        area = area + (x(i)*y(i+1) - x(i+1)*y(i));
    end
    area = abs(area) / 2;
end
```

---

## 3. Shapefile 분류 시스템

OceanMesh2D는 자동으로 폴리곤을 세 가지 카테고리로 분류합니다:

### 3.1 Outer (외부 경계)
- **정의**: 메쉬 생성 영역의 외곽 경계
- **생성 방법**: bbox로부터 자동 생성
- **조밀화**: h0/2 간격으로 자동 조밀화

**코드** (Read_shapefile.m:102-109):
```matlab
polygon_struct.outer = boubox;  % bbox로부터 생성
[latout,lonout] = my_interpm(polygon_struct.outer(:,2), ...
                             polygon_struct.outer(:,1), h0/2);
polygon_struct.outer(:,1) = lonout;
polygon_struct.outer(:,2) = latout;
```

### 3.2 Mainland (본토)
- **정의**: bbox와 부분적으로 교차하는 해안선
- **용도**: 외부 경계와 결합하여 point-in-polygon 테스트에 사용
- **조건**:
  - 폴리곤의 일부가 bbox 내부에 있음
  - 면적 ≥ 100×h0²

### 3.3 Inner (섬)
- **정의**: bbox 내부에 완전히 포함된 폴리곤
- **용도**: 메쉬의 "구멍" (hole)로 사용
- **조건**:
  - 폴리곤의 모든 점이 bbox 내부에 있음
  - 면적 ≥ 4×h0²

### 3.4 분류 플로우차트
```
Shapefile 폴리곤
    ↓
bbox와의 교차 테스트
    ↓
┌─────────────┬─────────────┐
│ 완전히 내부  │ 부분적 교차  │
│             │             │
│ area >= 4h0²│ area >= 100h0²│
│     ↓       │      ↓      │
│   Inner     │  Mainland   │
│   (섬)      │  (본토)     │
└─────────────┴─────────────┘
         ↓
    outer와 병합
         ↓
  Point-in-polygon 테스트용
```

---

## 4. 3D Shapefile (높이 속성 포함)

### 4.1 3D Shapefile 활성화
```matlab
gdat = geodata('shp', shapefile, 'bbox', bbox, 'h0', h0, ...
               'shapefile_3d', 1);
```

### 4.2 필수 속성
3D shapefile을 사용할 때는 다음 정보가 필요합니다:

1. **Z 좌표**: 높이/고도 (3번째 좌표)
2. **DBF 속성**: 첫 번째 필드에 피처 타입 코드

### 4.3 인식되는 피처 타입 코드

| 코드 | 의미 | 변환 |
|------|------|------|
| `BA040` | Ocean | `'ocean'` |
| `BH080` | Lake | `'lake'` |
| `BH140` | River | `'river'` |

**코드** (Read_shapefile.m:186-197):
```matlab
if shapefile_3d
    height = points(:,3);
    points = points(:,1:2);
    type = tmpC{i,2};
    if strcmp(type,'BA040')
        type = 'ocean';
    elseif strcmp(type,'BH080')
        type = 'lake';
    elseif strcmp(type,'BH140')
        type = 'river';
    end
end
```

### 4.4 출력 구조
```matlab
polygon_struct.innerb       % [lon lat height] 배열
polygon_struct.mainlandb    % [lon lat height] 배열
polygon_struct.innerb_type  % 피처 타입 셀 배열
polygon_struct.mainlandb_type % 피처 타입 셀 배열
```

---

## 5. Shapefile 처리 파이프라인

### 5.1 전체 프로세스
```
1. 읽기 (Read)
   ↓ shaperead() 시도, 실패 시 m_shaperead() 사용
2. 분류 (Classify)
   ↓ bbox 교차 기반으로 inner/mainland/outer 분류
3. 검증 (Validate)
   ↓ 닫힘, 면적, point-in-polygon 확인
4. 조밀화 (Densify)
   ↓ h0/2 간격으로 간격 채우기
5. 보간 (Interpolate)
   ↓ gridspace/spacing 간격으로 정규 간격 (spacing=2.0)
6. 평활화 (Smooth)
   ↓ 이동 평균 (기본값: window=5)
7. 조악화 (Coarsen)
   ↓ bbox의 1.1배 외부 점들을 조악화
8. 병합 (Merge)
   ↓ 선택적 폴리곤 합집합 (polyshape/polybool 필요)
```

### 5.2 갭 채우기 (Gap Filling)
**목적**: h0/2보다 큰 간격을 자동으로 채움

**함수**: `my_interpm(lat, lon, spacing)`

**이유**: 경계 거부 방법(boundary rejection method)을 사용하기 위해 필요

**코드** (Read_shapefile.m:104-109):
```matlab
[latout,lonout] = my_interpm(polygon_struct.outer(:,2), ...
                             polygon_struct.outer(:,1), h0/2);
```

### 5.3 평활화 (Smoothing)
**방법**: 이동 평균 윈도우

**기본 윈도우 크기**: 5개 점

**설정 방법**:
```matlab
gdat = geodata('shp', shapefile, 'bbox', bbox, 'h0', h0, ...
               'window', 10);  % 윈도우 크기 10으로 변경
```

---

## 6. 사용 방법

### 6.1 기본 사용법
```matlab
% 필수 매개변수 설정
bbox = [
    120 125    % lon_min lon_max
    22 28      % lat_min lat_max
];
min_el = 1000;  % 최소 해상도 (미터)

% Shapefile로 geodata 객체 생성
coastline = 'GSHHS_f_L1';
gdat = geodata('shp', coastline, 'bbox', bbox, 'h0', min_el);
```

### 6.2 여러 Shapefile 사용
```matlab
% 여러 해상도의 해안선 사용
coastline = {'GSHHS_f_L1', 'GSHHS_f_L6'};
gdat = geodata('shp', coastline, 'bbox', bbox, 'h0', min_el);
```

### 6.3 DEM과 함께 사용
```matlab
dem = 'SRTM15+.nc';
coastline = 'GSHHS_f_L1';
gdat = geodata('shp', coastline, 'dem', dem, 'bbox', bbox, 'h0', min_el);
```

### 6.4 폴리곤 bbox 사용
```matlab
% bbox를 사각형이 아닌 폴리곤으로 정의
bbox_poly = [
    -74.25 40.5
    -73.75 40.55
    -73.75 41.0
    -74.0  41.0
    -74.25 40.5
];
gdat = geodata('shp', coastline, 'bbox', bbox_poly, 'h0', min_el);
```

### 6.5 NaN-delimited 벡터 사용
Shapefile 대신 NaN으로 구분된 벡터 사용 가능:

```matlab
% 사용자 정의 폴리곤
my_polygon = [
    120.0 25.0
    121.0 25.0
    121.0 26.0
    120.0 26.0
    120.0 25.0
    NaN   NaN      % 폴리곤 구분자
    120.5 25.2
    120.7 25.2
    120.7 25.4
    120.5 25.4
    120.5 25.2
];

gdat = geodata('pslg', my_polygon, 'bbox', bbox, 'h0', min_el);
```

### 6.6 고충실도 (High Fidelity) 모드
```matlab
% 정밀한 메쉬가 필요한 영역
gdat = geodata('shp', coastline, 'bbox', bbox, 'h0', min_el, ...
               'high_fidelity', 1);
```

이 모드는 2D 메싱 전에 1D 메쉬 생성 단계를 수행하여 pfix 및 egfix를 형성합니다.

---

## 7. 출력 데이터 구조

### 7.1 geodata 객체 속성
```matlab
gdat.outer          % [lon lat] 배열, NaN 구분
gdat.mainland       % [lon lat] 배열, NaN 구분
gdat.inner          % [lon lat] 배열, NaN 구분
gdat.mainlandb      % [lon lat height] 3D shapefile용
gdat.innerb         % [lon lat height] 3D shapefile용
gdat.mainlandb_type % 피처 타입 (ocean/lake/river)
gdat.innerb_type    % 피처 타입 (ocean/lake/river)
gdat.bbox           % 경계 상자
gdat.boubox         % bbox를 반시계방향 폴리곤으로
gdat.h0             % 최소 에지 길이 (미터)
gdat.gridspace      % 격자 간격
gdat.Fb             % DEM의 선형 격자 보간자
```

### 7.2 Point-in-Polygon 테스트
```matlab
% 경계 에지 가져오기
edges = Get_poly_edges([gdat.outer; gdat.inner]);

% 점이 폴리곤 내부인지 테스트
test_points = [120.5 25.5; 121.2 26.3];
in = inpoly(test_points, gdat.outer, edges);
```

---

## 8. 권장 Shapefile 데이터셋

### 8.1 GSHHS (Global Self-consistent Hierarchical High-resolution Shorelines)
**권장 이유**: OceanMesh2D와 완벽하게 호환

**해상도 레벨**:
- `GSHHS_f_L1`: 가장 정밀 (full resolution, ~1:1,000,000)
- `GSHHS_h_L1`: 높음 (high resolution, ~1:3,000,000)
- `GSHHS_i_L1`: 중간 (intermediate resolution)
- `GSHHS_l_L1`: 낮음 (low resolution)
- `GSHHS_c_L1`: 조악함 (coarse resolution)

**레벨별 L 번호**:
- `L1`: 육지-해양 경계
- `L2`: 호수
- `L3`: 호수 내 섬
- `L4`: 호수 내 섬의 연못
- `L5`: 연못 내 섬
- `L6`: 섬의 빙하 경계

**사용 예시**:
```matlab
% 고해상도 해안선 + 호수
coastline = {'GSHHS_f_L1', 'GSHHS_f_L2'};

% 저해상도 글로벌 메쉬
coastline = 'GSHHS_l_L1';
```

### 8.2 사용자 정의 Shapefile

**QGIS/ArcGIS에서 준비**:
1. **좌표계**: WGS84 (EPSG:4326)로 변환
2. **지오메트리**: Polygon 타입
3. **닫힘**: 모든 폴리곤이 닫혀 있는지 확인
4. **유효성 검사**: "Fix geometries" 도구 실행
5. **저장**: .shp, .shx, .dbf 파일 모두 포함

**필수 파일**:
- `yourfile.shp` - 지오메트리
- `yourfile.shx` - 인덱스
- `yourfile.dbf` - 속성

---

## 9. 문제 해결

### 9.1 일반적인 오류

#### 오류 1: "Empty objects in shapefile"
**원인**: Shapefile에 빈 피처가 있음

**해결**: 자동으로 제거됨 (Read_shapefile.m:137-140)
```matlab
if any(cellfun(@isempty,tmpC(:,1)))
    warning('Empty objects in shapefile have been removed')
    tmpC = tmpC(~cellfun(@isempty,tmpC(:,1)),:);
end
```

#### 오류 2: 폴리곤이 메쉬에 나타나지 않음
**원인**: 면적이 최소 임계값보다 작음

**해결**:
- h0 값을 증가시키거나
- 더 큰 폴리곤 사용
- 면적 확인:
```matlab
area = shoelace(polygon(:,1), polygon(:,2));
min_area_inner = 4 * h0^2;      % 섬
min_area_mainland = 100 * h0^2;  % 본토
```

#### 오류 3: 닫히지 않은 폴리곤
**원인**: 첫 점 ≠ 마지막 점

**해결**: 폴리곤 닫기
```matlab
if ~all(polygon(1,:) == polygon(end,:))
    polygon(end+1,:) = polygon(1,:);
end
```

#### 오류 4: 자오선 교차 문제
**원인**: bbox가 180°/-180° 자오선을 교차함

**해결**: 자동으로 처리됨 (Read_shapefile.m:25-33)
```matlab
if bbox(1,2) > 180 && bbox(1,1) < 180
    % bbox가 180/-180 자오선을 교차함
    loop = 2;  % 두 번 읽기
end
```

### 9.2 성능 최적화

#### 팁 1: 적절한 h0 선택
- **너무 작은 h0**: 처리 시간 증가, 많은 작은 피처
- **너무 큰 h0**: 중요한 피처 누락
- **권장**: 예상 메쉬 해상도의 0.5~2배

#### 팁 2: bbox 크기
- **정확한 bbox 사용**: 불필요한 피처 읽기 방지
- **패딩 추가**: bbox를 약간 확장하여 경계 효과 방지

#### 팁 3: 해상도 선택
- **GSHHS 해상도**: 영역 크기에 맞게 선택
  - 작은 영역 (<100km): `GSHHS_f_L1`
  - 중간 영역 (100-1000km): `GSHHS_h_L1` or `GSHHS_i_L1`
  - 큰 영역 (>1000km): `GSHHS_l_L1` or `GSHHS_c_L1`

---

## 10. 고급 기능

### 10.1 폴리곡 병합
중복되는 mainland와 inner 폴리곤 병합:

```matlab
% polyshape 또는 polybool 필요
if exist('polybool','file') || exist('polyshape','file')
    polyout = union(polyshape(mainland), polyshape(inner));
    merged_polygon = polyout.Vertices;
end
```

**코드 위치**: Read_shapefile.m:254-281

### 10.2 조악화 (Coarsening)
bbox 외부의 점들을 조악화하여 메모리 절약:

**처리 영역**: bbox의 1.1배 외부 영역

**목적**: 메쉬 생성에 영향을 주지 않으면서 메모리 사용량 감소

### 10.3 위어 (Weirs) 추가
서브그리드 스케일 구조물 추가:

```matlab
% 위어 크레스트라인 정의
weir_lines = [...];  % [x1 y1 x2 y2] 형식

gdat = geodata('shp', coastline, 'bbox', bbox, 'h0', h0, ...
               'weirs', weir_lines);
```

---

## 11. 코드 참조

### 11.1 주요 함수 위치

| 함수 | 파일 경로 | 라인 |
|------|-----------|------|
| **Read_shapefile** | @geodata/private/Read_shapefile.m | 1-297 |
| **geodata 생성자** | @geodata/geodata.m | 68-350 |
| **shoelace** | @geodata/private/shoelace.m | 1-10 |

### 11.2 중요 코드 섹션

**닫힘 검증** (Read_shapefile.m:212-216):
```matlab
if all(points(1,:) == points(end,:))
    area = shoelace(points(:,1),points(:,2));
else
    area = 999; % 폴리곤이 아님
end
```

**분류 로직** (Read_shapefile.m:217-241):
```matlab
if length(find(In == 1)) == length(points)
    % 완전히 bbox 내부 → INNER
    if area < 4*h0^2
        continue;  % 너무 작음
    end
    % 섬으로 설정
else
    % 부분적으로 bbox 내부 → MAINLAND
    if area < 100*h0^2
        continue;  % 너무 작음
    end
    % 본토로 설정
end
```

**갭 채우기** (Read_shapefile.m:104-109):
```matlab
[latout,lonout] = my_interpm(polygon_struct.outer(:,2), ...
                             polygon_struct.outer(:,1), h0/2);
```

---

## 12. 완전한 예제

### 예제 1: 기본 메쉬 생성
```matlab
clearvars; clc; close all

%% 1. 메쉬 범위 및 매개변수 설정
bbox = [
    120 125    % 경도: 동경 120° ~ 125°
    22  28     % 위도: 북위 22° ~ 28°
];
min_el = 1000;   % 최소 해상도: 1km
max_el = 50000;  % 최대 해상도: 50km

%% 2. 지리 데이터 로드
coastline = 'GSHHS_f_L1';
gdat = geodata('shp', coastline, 'bbox', bbox, 'h0', min_el);

%% 3. 에지 함수 생성
fh = edgefx('geodata', gdat, 'max_el', max_el);

%% 4. 메쉬 생성
mshopts = meshgen('ef', fh, 'bou', gdat, 'plot_on', 1);
mshopts = mshopts.build;

%% 5. 경계 조건 설정
m = mshopts.grd;
m = make_bc(m, 'auto', gdat);
plot(m, 'type', 'bd');
```

### 예제 2: 다중 해상도 메쉬
```matlab
%% 넓은 영역 (저해상도)
bbox1 = [115 130; 15 35];
min_el1 = 5000;
gdat1 = geodata('shp', 'GSHHS_h_L1', 'bbox', bbox1, 'h0', min_el1);
fh1 = edgefx('geodata', gdat1, 'max_el', 100e3);

%% 정밀 영역 (고해상도)
bbox2 = [119 126; 21 26];
min_el2 = 500;
gdat2 = geodata('shp', 'GSHHS_f_L1', 'bbox', bbox2, 'h0', min_el2, ...
                'high_fidelity', 1);
fh2 = edgefx('geodata', gdat2, 'max_el', 10e3);

%% 에지 함수 결합
fh = fh1 + fh2;

%% 메쉬 생성
mshopts = meshgen('ef', fh, 'bou', {gdat1, gdat2}, 'plot_on', 1);
mshopts = mshopts.build;
```

### 예제 3: 3D Shapefile 사용
```matlab
%% 높이 속성이 있는 shapefile
coastline_3d = 'my_3d_coastline.shp';
gdat = geodata('shp', coastline_3d, 'bbox', bbox, 'h0', min_el, ...
               'shapefile_3d', 1);

%% 피처 타입 확인
if ~isempty(gdat.mainlandb_type)
    disp('본토 피처 타입:');
    disp(gdat.mainlandb_type);
end

if ~isempty(gdat.innerb_type)
    disp('섬 피처 타입:');
    disp(gdat.innerb_type);
end
```

---

## 13. 요약

### 필수 체크리스트

격자 생성용 shapefile을 준비할 때 다음 사항을 확인하세요:

- [ ] **좌표계**: WGS84 (EPSG:4326)
- [ ] **지오메트리 타입**: Polygon
- [ ] **닫힌 폴리곤**: 첫 점 = 마지막 점
- [ ] **자체 교차 없음**: 선분이 교차하지 않음
- [ ] **최소 면적**: 섬 ≥ 4×h0², 본토 ≥ 100×h0²
- [ ] **필수 파일**: .shp, .shx, .dbf
- [ ] **유효성 검증**: QGIS/ArcGIS에서 검증 완료

### 권장 작업 순서

1. **데이터 준비**: GSHHS 다운로드 또는 사용자 정의 shapefile 준비
2. **bbox 정의**: 관심 영역 정의
3. **h0 선택**: 최소 에지 길이 결정
4. **geodata 생성**: `geodata('shp', ...)`
5. **검증**: 출력된 경고 메시지 확인
6. **조정**: 필요시 h0 또는 bbox 조정
7. **메쉬 생성**: edgefx 및 meshgen 사용

---

**문서 작성일**: 2025-11-20
**작성자**: Claude (AI Assistant)
**OceanMesh2D 버전**: 현재 main 브랜치
**참조 파일**: Read_shapefile.m, geodata.m, Examples/
