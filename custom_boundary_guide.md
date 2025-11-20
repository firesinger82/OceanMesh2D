# OceanMesh2D 사용자 정의 경계 가이드

## 개요

OceanMesh2D는 **사각형 bbox 외에도 임의의 폴리곤 형태**로 경계를 지정할 수 있습니다. 이를 통해 **반원, 원, 타원, 또는 임의의 곡선** 형태의 경계를 만들 수 있습니다.

---

## 1. 기본 개념

### 1.1 bbox 매개변수의 두 가지 형식

OceanMesh2D의 `geodata` 클래스는 `bbox`를 두 가지 방식으로 처리합니다:

| 형식 | 크기 | 용도 | 처리 |
|------|------|------|------|
| **사각형 bbox** | 2×2 | 일반적인 직사각형 영역 | 자동으로 5×2 폴리곤으로 변환 |
| **폴리곤 bbox** | N×2 (N>2) | 사용자 정의 임의 형태 | 그대로 사용 |

**코드 위치**: `@geodata/geodata.m:277-289`
```matlab
if size(obj.bbox,1) == 2
    % 사각형 bbox → boubox로 변환
    obj.boubox = bbox_to_bou(obj.bbox);
else
    % 사용자 정의 폴리곤
    obj.boubox = obj.bbox;
    if ~isnan(obj.boubox(end,1))
        obj.boubox(end+1,:) = [NaN NaN];  % NaN 구분자 추가
    end
end
```

### 1.2 필수 요구사항

사용자 정의 폴리곤 경계는 다음 조건을 만족해야 합니다:

✅ **닫힌 폴리곤**: 첫 번째 점 = 마지막 점
✅ **반시계방향(CCW)**: 폴리곤은 반시계방향으로 순회
✅ **자체 교차 없음**: 선분이 서로 교차하지 않음
✅ **최소 3개 점**: 삼각형 이상의 형태

---

## 2. 반원 경계 생성

### 2.1 기본 반원

```matlab
% 반원 중심 및 반지름
center_lon = 125.0;
center_lat = 35.0;
radius = 2.0;  % 도 단위

% 반원 호 생성 (0° ~ 180°)
n_points = 100;
theta = linspace(0, pi, n_points);

semicircle_lon = center_lon + radius * cos(theta);
semicircle_lat = center_lat + radius * sin(theta);

% 직선 부분 (지름)
base_lon = linspace(semicircle_lon(end), semicircle_lon(1), 20);
base_lat = ones(1, 20) * center_lat;

% 완전한 닫힌 폴리곤
bbox_semicircle = [
    semicircle_lon', semicircle_lat'
    base_lon', base_lat'
    semicircle_lon(1), semicircle_lat(1)  % 닫기
];

% geodata 생성
gdat = geodata('shp', coastline, 'bbox', bbox_semicircle, 'h0', min_el);
```

### 2.2 방향이 다른 반원

#### 위쪽 반원 (0° ~ 180°)
```matlab
theta = linspace(0, pi, n_points);  % 북쪽 반원
semicircle_lon = center_lon + radius * cos(theta);
semicircle_lat = center_lat + radius * sin(theta);
```

#### 아래쪽 반원 (180° ~ 360°)
```matlab
theta = linspace(pi, 2*pi, n_points);  % 남쪽 반원
semicircle_lon = center_lon + radius * cos(theta);
semicircle_lat = center_lat + radius * sin(theta);
```

#### 왼쪽 반원 (90° ~ 270°)
```matlab
theta = linspace(pi/2, 3*pi/2, n_points);  % 서쪽 반원
semicircle_lon = center_lon + radius * cos(theta);
semicircle_lat = center_lat + radius * sin(theta);
```

#### 오른쪽 반원 (-90° ~ 90°)
```matlab
theta = linspace(-pi/2, pi/2, n_points);  % 동쪽 반원
semicircle_lon = center_lon + radius * cos(theta);
semicircle_lat = center_lat + radius * sin(theta);
```

### 2.3 타원 반원

```matlab
% 타원 매개변수
a = 3.0;  % 장축 반경 (경도 방향)
b = 1.5;  % 단축 반경 (위도 방향)

theta = linspace(0, pi, n_points);
ellipse_lon = center_lon + a * cos(theta);
ellipse_lat = center_lat + b * sin(theta);

% 직선 부분
base_lon = linspace(ellipse_lon(end), ellipse_lon(1), 20);
base_lat = ones(1, 20) * center_lat;

bbox_ellipse = [
    ellipse_lon', ellipse_lat'
    base_lon', base_lat'
    ellipse_lon(1), ellipse_lat(1)
];
```

---

## 3. 완전한 원 경계

### 3.1 기본 원

```matlab
% 원 생성
center_lon = 125.0;
center_lat = 35.0;
radius = 2.0;

% 완전한 원 (0° ~ 360°)
n_points = 200;
theta = linspace(0, 2*pi, n_points+1);  % +1 for closure
theta(end) = [];  % 마지막 점 제거 (중복 방지)

circle_lon = center_lon + radius * cos(theta);
circle_lat = center_lat + radius * sin(theta);

% 닫힌 폴리곤 생성
bbox_circle = [
    circle_lon', circle_lat'
    circle_lon(1), circle_lat(1)  % 명시적 닫기
];

% geodata 생성
gdat = geodata('shp', coastline, 'bbox', bbox_circle, 'h0', min_el);
```

### 3.2 타원

```matlab
% 타원 생성
a = 3.0;  % 장축
b = 1.5;  % 단축

theta = linspace(0, 2*pi, n_points+1);
theta(end) = [];

ellipse_lon = center_lon + a * cos(theta);
ellipse_lat = center_lat + b * sin(theta);

bbox_ellipse = [
    ellipse_lon', ellipse_lat'
    ellipse_lon(1), ellipse_lat(1)
];
```

### 3.3 회전된 타원

```matlab
% 타원 회전
a = 3.0;
b = 1.5;
rotation_angle = pi/4;  % 45도 회전

theta = linspace(0, 2*pi, n_points+1);
theta(end) = [];

% 회전 행렬 적용
x = a * cos(theta);
y = b * sin(theta);

x_rot = x * cos(rotation_angle) - y * sin(rotation_angle);
y_rot = x * sin(rotation_angle) + y * cos(rotation_angle);

ellipse_lon = center_lon + x_rot;
ellipse_lat = center_lat + y_rot;

bbox_rotated = [
    ellipse_lon', ellipse_lat'
    ellipse_lon(1), ellipse_lat(1)
];
```

---

## 4. 임의의 곡선 경계

### 4.1 스플라인 곡선

```matlab
% 제어점 정의
control_points = [
    124.0, 34.0
    125.0, 35.5
    126.5, 35.0
    127.0, 33.5
    126.0, 32.0
    124.0, 34.0  % 닫기
];

% 스플라인 보간
t = 1:size(control_points, 1);
t_fine = linspace(1, size(control_points, 1), 200);

spline_lon = spline(t, control_points(:,1), t_fine);
spline_lat = spline(t, control_points(:,2), t_fine);

bbox_spline = [spline_lon', spline_lat'];
% 닫힘 확인
bbox_spline(end+1,:) = bbox_spline(1,:);
```

### 4.2 베지어 곡선

```matlab
% 베지어 곡선 함수
function [x, y] = bezier_curve(control_points, n_points)
    n = size(control_points, 1) - 1;
    t = linspace(0, 1, n_points);

    x = zeros(1, n_points);
    y = zeros(1, n_points);

    for i = 0:n
        B = nchoosek(n, i) * (1-t).^(n-i) .* t.^i;
        x = x + control_points(i+1, 1) * B;
        y = y + control_points(i+1, 2) * B;
    end
end

% 사용 예
control_points = [
    124.0, 34.0
    125.5, 36.0
    127.0, 35.0
    126.0, 33.0
];

[bez_lon, bez_lat] = bezier_curve(control_points, 100);

% 닫힌 경계로 만들기
bbox_bezier = [
    bez_lon', bez_lat'
    bez_lon(1), bez_lat(1)
];
```

### 4.3 삼각함수 기반 곡선

```matlab
% 파동 경계
n_points = 200;
t = linspace(0, 2*pi, n_points);

% 기본 원에 사인파 변조
amplitude = 0.3;  % 파동 진폭
frequency = 5;    % 파동 빈도

radius_modulated = radius * (1 + amplitude * sin(frequency * t));

wave_lon = center_lon + radius_modulated .* cos(t);
wave_lat = center_lat + radius_modulated .* sin(t);

bbox_wave = [
    wave_lon', wave_lat'
    wave_lon(1), wave_lat(1)
];
```

---

## 5. 복합 형태 경계

### 5.1 다각형 + 곡선

```matlab
% 육각형 기본 형태
n_sides = 6;
angles = linspace(0, 2*pi, n_sides+1);
hex_lon = center_lon + radius * cos(angles(1:end-1));
hex_lat = center_lat + radius * sin(angles(1:end-1));

% 각 모서리를 곡선으로 부드럽게
smoothed_corners = [];
corner_radius = 0.2;  % 모서리 둥근 정도

for i = 1:n_sides
    % 직선 부분
    straight_lon = linspace(hex_lon(i), hex_lon(mod(i,n_sides)+1), 20);
    straight_lat = linspace(hex_lat(i), hex_lat(mod(i,n_sides)+1), 20);

    % 모서리 부드럽게 (평활화)
    smoothed_corners = [smoothed_corners; straight_lon', straight_lat'];
end

% 전체 폴리곤 평활화
smoothed_lon = smooth(smoothed_corners(:,1), 10);
smoothed_lat = smooth(smoothed_corners(:,2), 10);

bbox_smooth = [
    smoothed_lon, smoothed_lat
    smoothed_lon(1), smoothed_lat(1)
];
```

### 5.2 여러 곡선 결합

```matlab
% 상단: 반원
top_theta = linspace(0, pi, 50);
top_lon = center_lon + radius * cos(top_theta);
top_lat = center_lat + radius * sin(top_theta);

% 오른쪽: 직선
right_lon = ones(1, 20) * (center_lon + radius);
right_lat = linspace(center_lat, center_lat - radius, 20);

% 하단: 포물선
bottom_x = linspace(radius, -radius, 50);
bottom_y = -0.3 * bottom_x.^2 / radius;  % 포물선
bottom_lon = center_lon + bottom_x;
bottom_lat = center_lat + bottom_y;

% 왼쪽: 직선
left_lon = ones(1, 20) * (center_lon - radius);
left_lat = linspace(center_lat - radius, center_lat, 20);

% 모두 결합
bbox_composite = [
    top_lon', top_lat'
    right_lon', right_lat'
    bottom_lon', bottom_lat'
    left_lon', left_lat'
    top_lon(1), top_lat(1)  % 닫기
];
```

---

## 6. 실전 예제

### 6.1 만 (Bay) 형태

```matlab
% 만 입구의 반원 + 내부의 직사각형
bay_width = 2.0;
bay_depth = 3.0;
entrance_radius = 1.0;

% 입구 (반원)
theta = linspace(0, pi, 50);
entrance_lon = center_lon + entrance_radius * cos(theta);
entrance_lat = center_lat + entrance_radius * sin(theta);

% 왼쪽 측면
left_lon = ones(1, 20) * (center_lon - entrance_radius);
left_lat = linspace(center_lat, center_lat - bay_depth, 20);

% 바닥
bottom_lon = linspace(center_lon - entrance_radius, center_lon + entrance_radius, 30);
bottom_lat = ones(1, 30) * (center_lat - bay_depth);

% 오른쪽 측면
right_lon = ones(1, 20) * (center_lon + entrance_radius);
right_lat = linspace(center_lat - bay_depth, center_lat, 20);

bbox_bay = [
    entrance_lon', entrance_lat'
    right_lon', right_lat'
    bottom_lon', bottom_lat'
    left_lon', left_lat'
    entrance_lon(1), entrance_lat(1)
];
```

### 6.2 하구 (Estuary) 형태

```matlab
% 넓은 입구에서 좁은 하천으로
estuary_length = 5.0;
entrance_width = 3.0;
river_width = 0.5;

% 왼쪽 경계 (테이퍼링)
x = linspace(0, estuary_length, 100);
left_width = entrance_width/2 - (entrance_width/2 - river_width/2) * (x/estuary_length).^2;

left_lon = center_lon - left_width;
left_lat = center_lat + x;

% 오른쪽 경계 (대칭)
right_lon = center_lon + fliplr(left_width);
right_lat = center_lat + x;

% 입구 닫기
entrance_lon = linspace(left_lon(1), right_lon(end), 20);
entrance_lat = ones(1, 20) * center_lat;

bbox_estuary = [
    entrance_lon', entrance_lat'
    right_lon', right_lat'
    flipud([left_lon', left_lat'])
    entrance_lon(1), entrance_lat(1)
];
```

### 6.3 섬 주변 영역 (도넛 형태)

```matlab
% 외부 원
outer_radius = 3.0;
theta = linspace(0, 2*pi, 200);
outer_lon = center_lon + outer_radius * cos(theta);
outer_lat = center_lat + outer_radius * sin(theta);

% 내부 원 (구멍)
inner_radius = 1.0;
theta_inner = linspace(0, 2*pi, 100);
inner_lon = center_lon + inner_radius * cos(theta_inner);
inner_lat = center_lat + inner_radius * sin(theta_inner);

% 외부 경계
bbox_outer = [
    outer_lon', outer_lat'
    outer_lon(1), outer_lat(1)
];

% 내부 경계는 'pslg'로 전달
inner_boundary = [
    inner_lon', inner_lat'
    NaN, NaN
];

% geodata 생성 시 inner를 명시적으로 전달
gdat = geodata('bbox', bbox_outer, 'pslg', inner_boundary, 'h0', min_el);
```

---

## 7. 주의사항 및 팁

### 7.1 좌표계 고려

**위도-경도 좌표계에서의 거리**:
- 위도 1도 ≈ 111km (일정)
- 경도 1도 = 111km × cos(위도) (위도에 따라 변함)

**타원 보정**:
```matlab
% 위도에서 경도 보정 계산
lat_correction = cos(center_lat * pi/180);

% 원을 위도-경도 좌표계에서 올바르게 표현
circle_lon = center_lon + radius * cos(theta) / lat_correction;
circle_lat = center_lat + radius * sin(theta);
```

### 7.2 점 밀도 선택

| 경계 복잡도 | 권장 점 개수 | 예시 |
|-------------|--------------|------|
| 단순 (원, 타원) | 100-200 | 원, 반원 |
| 중간 (부드러운 곡선) | 200-500 | 스플라인, 베지어 |
| 복잡 (급격한 변화) | 500-1000 | 복합 곡선, 하구 |

**규칙**: 점 간격이 `h0/2`보다 작아야 합니다.

```matlab
% 필요한 최소 점 개수 계산
perimeter = 2 * pi * radius;  % 원 둘레
min_points = ceil(perimeter / (h0/2));

n_points = max(min_points, 100);  % 최소 100개
```

### 7.3 와인딩 순서 확인

**반시계방향(CCW) 확인**:
```matlab
% 폴리곤 면적 계산 (shoelace 공식)
function signed_area = polygon_area(lon, lat)
    n = length(lon) - 1;  % 마지막 점 제외
    area = 0;
    for i = 1:n
        area = area + (lon(i) * lat(i+1) - lon(i+1) * lat(i));
    end
    signed_area = area / 2;
end

% 사용
area = polygon_area(bbox(:,1), bbox(:,2));
if area < 0
    % 시계방향 → 반시계방향으로 뒤집기
    bbox = flipud(bbox);
end
```

### 7.4 경계 시각화 및 검증

```matlab
% 경계 시각화
figure;
plot(bbox(:,1), bbox(:,2), 'b-', 'LineWidth', 2);
hold on;
plot(bbox(1,1), bbox(1,2), 'go', 'MarkerSize', 10);  % 시작점
plot(bbox(end,1), bbox(end,2), 'ro', 'MarkerSize', 10);  % 끝점

% 점 번호 표시 (디버깅용)
for i = 1:10:size(bbox,1)
    text(bbox(i,1), bbox(i,2), num2str(i), 'FontSize', 8);
end

xlabel('Longitude'); ylabel('Latitude');
title('Custom Boundary Verification');
axis equal; grid on;

% 닫힘 확인
is_closed = all(bbox(1,:) == bbox(end,:));
if is_closed
    disp('✓ 폴리곤이 올바르게 닫혀 있습니다.');
else
    warning('✗ 폴리곤이 닫혀 있지 않습니다!');
end
```

---

## 8. 완전한 작업 예제

### 예제: 반원 영역의 해양 메쉬 생성

```matlab
clearvars; clc; close all

%% 1. 반원 경계 정의
center_lon = 127.0;
center_lat = 37.0;
radius = 1.5;

n_points = 150;
theta = linspace(0, pi, n_points);

semicircle_lon = center_lon + radius * cos(theta);
semicircle_lat = center_lat + radius * sin(theta);

base_lon = linspace(semicircle_lon(end), semicircle_lon(1), 30);
base_lat = ones(1, 30) * center_lat;

bbox_semicircle = [
    semicircle_lon', semicircle_lat'
    base_lon', base_lat'
    semicircle_lon(1), semicircle_lat(1)
];

%% 2. 경계 검증
area = polygon_area(bbox_semicircle(:,1), bbox_semicircle(:,2));
fprintf('폴리곤 면적: %.4f 제곱도\n', abs(area));
fprintf('와인딩 방향: %s\n', area > 0 ? 'CCW (올바름)' : 'CW (뒤집기 필요)');

if area < 0
    bbox_semicircle = flipud(bbox_semicircle);
end

%% 3. 메쉬 매개변수
min_el = 10e3;   % 10 km
max_el = 100e3;  % 100 km
grade = 0.20;

%% 4. geodata 생성
coastline = 'GSHHS_h_L1';
gdat = geodata('shp', coastline, 'bbox', bbox_semicircle, 'h0', min_el);

%% 5. 에지 함수 생성
fh = edgefx('geodata', gdat, ...
    'max_el', max_el, ...
    'max_el_ns', 20e3, ...
    'g', grade, ...
    'fs', 3);

%% 6. 메쉬 생성
mshopts = meshgen('ef', fh, 'bou', gdat, ...
    'plot_on', 1, ...
    'proj', 'lambert', ...
    'nscreen', 5);
mshopts = mshopts.build;

%% 7. 경계 조건 및 수심 보간
m = mshopts.grd;
m = make_bc(m, 'auto', gdat, 'both');  % 거리+수심 기반

% DEM이 있는 경우
if ~isempty(gdat.Fb)
    m = interp(m, gdat, 'mindepth', 1);
end

%% 8. 시각화
figure;
subplot(2,2,1);
plot(bbox_semicircle(:,1), bbox_semicircle(:,2), 'r-', 'LineWidth', 2);
title('1. Semicircle Boundary'); axis equal; grid on;

subplot(2,2,2);
plot(gdat, 'proj', 'lambert');
title('2. Geodata');

subplot(2,2,3);
plot(fh, 'proj', 'lambert');
title('3. Edge Function');

subplot(2,2,4);
plot(m, 'type', 'bd', 'proj', 'lambert');
title('4. Final Mesh with BCs');

%% 9. 저장
write(m, 'semicircle_mesh');
save('semicircle_mesh.mat', 'm');

disp('메쉬 생성 완료!');
```

---

## 9. 트러블슈팅

### 문제 1: "Polygon is not closed"
**원인**: 첫 점 ≠ 마지막 점

**해결**:
```matlab
if ~all(bbox(1,:) == bbox(end,:))
    bbox(end+1,:) = bbox(1,:);
end
```

### 문제 2: 메쉬가 경계 밖으로 확장됨
**원인**: 와인딩 방향이 시계방향(CW)

**해결**:
```matlab
area = polygon_area(bbox(:,1), bbox(:,2));
if area < 0
    bbox = flipud(bbox);  % 반시계방향으로 뒤집기
end
```

### 문제 3: 경계가 메쉬에 제대로 반영되지 않음
**원인**: 점 간격이 너무 넓음

**해결**:
```matlab
% 점 간격 확인
distances = sqrt(diff(bbox(:,1)).^2 + diff(bbox(:,2)).^2);
max_dist = max(distances);
fprintf('최대 점 간격: %.6f도\n', max_dist);

% h0과 비교
h0_degrees = min_el / 111e3;
fprintf('h0/2 = %.6f도\n', h0_degrees/2);

if max_dist > h0_degrees/2
    warning('점 간격이 너무 넓습니다. 더 많은 점이 필요합니다.');
end
```

### 문제 4: 자오선(180°) 교차 문제
**원인**: 경도가 -180°와 180° 사이를 교차

**해결**: 모든 경도를 0-360 범위로 변환
```matlab
if any(bbox(:,1) < 0) && any(bbox(:,1) > 0) && ...
   max(bbox(:,1)) - min(bbox(:,1)) > 180
    % -180~180을 0~360으로 변환
    bbox(bbox(:,1) < 0, 1) = bbox(bbox(:,1) < 0, 1) + 360;
end
```

---

## 10. 고급 기법

### 10.1 동적 점 밀도

복잡한 영역에는 더 많은 점을 배치:

```matlab
% 곡률 기반 점 분포
function bbox = adaptive_boundary(control_points, h0, curvature_factor)
    % control_points: 제어점 [lon, lat]
    % h0: 최소 에지 길이
    % curvature_factor: 곡률 민감도 (1-10)

    n_seg = size(control_points, 1) - 1;
    bbox = [];

    for i = 1:n_seg
        p1 = control_points(i,:);
        p2 = control_points(i+1,:);

        % 세그먼트 길이
        seg_length = norm(p2 - p1);

        % 곡률 추정 (이전-현재-다음 점)
        if i > 1 && i < n_seg
            p0 = control_points(i-1,:);
            p3 = control_points(i+2,:);

            v1 = p1 - p0; v2 = p2 - p1; v3 = p3 - p2;
            angle1 = acos(dot(v1,v2)/(norm(v1)*norm(v2)));
            angle2 = acos(dot(v2,v3)/(norm(v2)*norm(v3)));

            curvature = (abs(angle1) + abs(angle2)) / 2;
        else
            curvature = 0;
        end

        % 곡률에 따라 점 개수 조정
        n_points = ceil(seg_length / (h0/2) * (1 + curvature_factor * curvature));
        n_points = max(n_points, 2);

        % 점 생성
        t = linspace(0, 1, n_points);
        seg_lon = p1(1) + t * (p2(1) - p1(1));
        seg_lat = p1(2) + t * (p2(2) - p1(2));

        bbox = [bbox; seg_lon', seg_lat'];
    end

    % 닫기
    bbox(end+1,:) = bbox(1,:);
end
```

### 10.2 다중 경계 (구멍이 있는 영역)

```matlab
% 외부 경계
outer_boundary = [...];  % 외부 폴리곤

% 내부 경계 (구멍)
hole1 = [...];
hole2 = [...];

% pslg로 결합 (NaN 구분자 사용)
combined_pslg = [
    outer_boundary
    NaN, NaN
    hole1
    NaN, NaN
    hole2
];

gdat = geodata('pslg', combined_pslg, 'h0', min_el);
```

---

## 11. 참조

### 관련 파일
- **geodata.m:277-289** - bbox 처리 로직
- **Read_shapefile.m:102-109** - boubox 조밀화
- **Example_3_ECGC.m:52** - 폴리곤 bbox 예제

### 도움 함수
- `bbox_to_bou()` - 사각형 bbox를 폴리곤으로 변환
- `my_interpm()` - 폴리곤 조밀화
- `shoelace()` - 폴리곤 면적 계산
- `inpoly()` - Point-in-polygon 테스트

---

## 12. 요약

### ✅ 가능한 경계 형태

- ✅ 반원, 원, 타원
- ✅ 스플라인, 베지어 곡선
- ✅ 삼각함수 기반 곡선
- ✅ 복합 형태 (다각형 + 곡선)
- ✅ 다중 경계 (구멍 포함)

### 📋 체크리스트

사용자 정의 경계를 만들 때:

- [ ] 첫 점 = 마지막 점 (닫힌 폴리곤)
- [ ] 반시계방향(CCW) 순서
- [ ] 자체 교차 없음
- [ ] 점 간격 ≤ h0/2
- [ ] 최소 3개 이상의 점
- [ ] 경계 시각화 확인
- [ ] 와인딩 방향 검증

### 💡 핵심 코드

```matlab
% 1. 반원 생성
theta = linspace(0, pi, 100);
lon = center_lon + radius * cos(theta);
lat = center_lat + radius * sin(theta);

% 2. 닫힌 폴리곤
bbox = [lon', lat'; base_points; lon(1), lat(1)];

% 3. geodata 생성
gdat = geodata('shp', coastline, 'bbox', bbox, 'h0', h0);

% 4. 메쉬 생성
fh = edgefx('geodata', gdat, 'max_el', max_el);
mshopts = meshgen('ef', fh, 'bou', gdat);
mshopts = mshopts.build;
```

---

**문서 작성일**: 2025-11-20
**작성자**: Claude (AI Assistant)
**OceanMesh2D 버전**: 현재 main 브랜치
