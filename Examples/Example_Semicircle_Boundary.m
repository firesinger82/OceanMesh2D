% Example_Semicircle_Boundary: 반원 형태의 경계로 메쉬 생성
% 이 예제는 사용자 정의 반원 폴리곤을 경계로 사용하는 방법을 보여줍니다.

clearvars; clc; close all

PREFIX = 'Semicircle';

%% STEP 1: 반원 경계 생성

% 반원 중심점 및 반지름 설정
center_lon = 125.0;   % 중심 경도
center_lat = 35.0;    % 중심 위도
radius = 2.0;         % 반지름 (도 단위)

% 반원 점들 생성 (0도에서 180도까지)
n_points = 100;  % 반원의 점 개수
theta = linspace(0, pi, n_points);  % 0 ~ π 라디안

% 극좌표를 직교좌표로 변환
semicircle_lon = center_lon + radius * cos(theta);
semicircle_lat = center_lat + radius * sin(theta);

% 직선 부분 추가 (반원의 지름)
base_lon = linspace(semicircle_lon(end), semicircle_lon(1), 20);
base_lat = ones(1, 20) * center_lat;

% 완전한 닫힌 폴리곤 생성 (첫 점 = 마지막 점)
bbox_semicircle = [
    semicircle_lon', semicircle_lat'
    base_lon', base_lat'
    semicircle_lon(1), semicircle_lat(1)  % 폴리곤 닫기
];

% 폴리곤 시각화
figure(1);
plot(bbox_semicircle(:,1), bbox_semicircle(:,2), 'r-', 'LineWidth', 2);
hold on;
plot(bbox_semicircle(1,1), bbox_semicircle(1,2), 'go', 'MarkerSize', 10, 'LineWidth', 2);
plot(bbox_semicircle(end,1), bbox_semicircle(end,2), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
xlabel('Longitude'); ylabel('Latitude');
title('Semicircle Boundary');
legend('Boundary', 'Start Point', 'End Point (same as start)');
grid on; axis equal;

%% STEP 2: 메쉬 매개변수 설정
min_el = 50e3;      % 최소 해상도 (50km)
max_el = 200e3;     % 최대 해상도 (200km)
grade = 0.15;       % 메쉬 그레이드

%% STEP 3: geodata 생성 (반원 bbox 사용)
coastline = 'GSHHS_l_L1';  % 저해상도 해안선 사용

% 반원 폴리곤을 bbox로 전달
gdat = geodata('shp', coastline, 'bbox', bbox_semicircle, 'h0', min_el);

% geodata 시각화
figure(2);
plot(gdat, 'proj', 'lambert');
title('Geodata with Semicircle Boundary');

%% STEP 4: 에지 함수 생성
fh = edgefx('geodata', gdat, 'max_el', max_el, 'g', grade);

% 에지 함수 시각화
figure(3);
plot(fh, 'proj', 'lambert');
title('Edge Function');

%% STEP 5: 메쉬 생성
mshopts = meshgen('ef', fh, 'bou', gdat, 'plot_on', 1, 'proj', 'lambert');
mshopts = mshopts.build;

%% STEP 6: 경계 조건 설정
m = mshopts.grd;
m = make_bc(m, 'auto', gdat, 'depth');  % 수심 기반 경계 분류

% 메쉬 시각화
figure(4);
plot(m, 'proj', 'lambert');
title('Generated Mesh');

figure(5);
plot(m, 'type', 'bd', 'proj', 'lambert');
title('Mesh with Boundary Conditions');

%% STEP 7: 메쉬 저장
save(sprintf('%s_msh.mat', PREFIX), 'm');
write(m, sprintf('%s_mesh', PREFIX));

disp('반원 경계 메쉬 생성 완료!');
