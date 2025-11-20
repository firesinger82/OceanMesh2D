# OceanMesh2D 경계 분류 및 경계 설정 시스템 검토

## 개요

OceanMesh2D는 ADCIRC 경계 유형 시스템을 사용하여 메쉬의 경계 조건을 관리합니다. 이 시스템은 `ibtype` 정수 코드를 사용하여 다양한 경계 유형을 구분합니다.

---

## 1. 핵심 파일 및 위치

### 주요 메서드
- **`@msh/msh.m:1307-2099`** - `make_bc()` 메서드: 경계 조건 설정의 진입점

### 유틸리티 함수
- **`utilities/extract_boundary.m`** - 경계 세그먼트 추출 및 와인딩 순서 정렬
- **`utilities/Nodal_Reduce_Matlab_Codes/detbndy.m`** - 요소 연결성에서 경계 에지 탐지
- **`utilities/Make_f15.m`** - fort.15 경계 조건 파일 생성
- **`utilities/Make_f19.m`** - fort.19 수위 경계 시계열 생성
- **`utilities/Make_f20.m`** - fort.20 플럭스/방사 경계 시계열 생성

### 입출력 함수
- **`@msh/private/readfort14.m`** - ADCIRC 그리드 + 경계 읽기
- **`@msh/private/writefort14.m`** - ADCIRC 그리드 + 경계 쓰기
- **`@msh/private/readfort15.m`** - ADCIRC 경계 조건 읽기
- **`@msh/private/writefort15.m`** - ADCIRC 경계 조건 쓰기

---

## 2. 경계 유형 (ibtype 코드)

### 주요 경계 유형

| ibtype | 명칭 | 용도 | 파일 위치 |
|--------|------|------|-----------|
| 0 | 개방 해양 경계 | 수위 지정 경계 | msh.m:1574, 1735, 1759 |
| 20 | 본토 무플럭스 | 외부 경계 (빨간색) | msh.m:1581, 1728, 1766 |
| 21 | 섬 무플럭스 | 내부 섬 경계 (녹색) | msh.m:1594, 1684 |
| 22 | 하천 플럭스 | 하천/유입구 경계 | Riverflux_distribution.m:37 |
| 24 | 위어/방벽 | 서브그리드 스케일 구조물 (노란색) | msh.m:1971, 2002, 2024 |

### 기타 지원되는 유형
- **0-5, 10-13, 20-25, 30, 52, 60, 61, 94, 101** - writefort14.m:74, 82, 99, 120, 126 참조

---

## 3. 경계 설정 모드 (`make_bc` 메서드)

### 3.1 'auto' 모드 (자동 분류)
**위치**: `msh.m:1376-1616`

**기능**: geodata 클래스를 기반으로 자동으로 수위 및 무플럭스 경계 조건 적용

**사용법**:
```matlab
obj = make_bc(obj, 'auto', gdat, classifier, param1, param2, param3)
```

**분류 방법**:
1. **'distance'** - 해안선으로부터의 거리 기반
   - `dist_lim`: 거리 임계값 (기본값: `10*gdat.gridspace`)
   - 임계값보다 먼 경계를 해양으로 분류

2. **'depth'** - 수심 기반
   - `depth_lim`: 수심 임계값 (기본값: 10m)
   - 임계값보다 깊은 경계를 해양으로 분류

3. **'both'** (기본값) - 거리와 수심 모두 고려
   - 거리 AND 수심 기준을 모두 만족해야 해양으로 분류
   - 가장 견고한 방법

**알고리즘** (msh.m:1455-1596):
```
1. 경계 에지 및 중점 가져오기 (extdom_edges2)
2. 각 경계 에지 분류:
   - 거리 기반: 육지로부터의 최근접 거리 계산
   - 수심 기반: 에지 중점의 평균 수심 계산
   - 결합: 두 기준 모두 만족해야 함
3. 경계 폴리곤 추출 (extdom_polygon)
4. 각 폴리곤에 대해:
   - 해양과 육지가 혼합된 경우 분할
   - 순수 섬인 경우 ibtype=21 할당
   - cut_lim보다 작은 해양 경계 제외 (기본값: 10 정점)
5. obj.op 및 obj.bd에 결과 저장
```

**주의사항**:
- 전역 메쉬에서는 사용 불가 (경도 -179~179 범위 초과 시)
- 수심 기반 분류는 메쉬에 수심 데이터(`obj.b`) 또는 gdat에 DEM(`gdat.Fb`) 필요

---

### 3.2 'inner' 모드 (섬 경계)
**위치**: `msh.m:1801-1865`

**기능**: 모든 내부 메쉬 폴리곤(즉, 섬)에 무플럭스 경계 조건 적용

**사용법**:
```matlab
obj = make_bc(obj, 'inner', ibtype)  % ibtype 기본값: 21
```

**알고리즘**:
```
1. 경계 에지 가져오기 (extdom_edges2)
2. 폴리곤 추출 (extdom_polygon)
3. 가장 큰 폴리곤 제거 (외부 경계)
4. 나머지 폴리곤을 섬으로 처리
5. 각 섬에 ibtype 할당 (기본값: 21)
```

---

### 3.3 'outer' 모드 (수동 외부 경계)
**위치**: `msh.m:1867-1906`

**기능**: 외부 메쉬 폴리곤의 세그먼트에 사용자 정의 경계 조건 적용

**사용법**:
```matlab
obj = make_bc(obj, 'outer', dir, vstart, vend, type, type2)
```

**매개변수**:
- `dir`: 방향 (0 = 반시계방향, 1 = 시계방향)
- `vstart`: 시작 정점 번호 (선택)
- `vend`: 종료 정점 번호 (선택)
- `type`: 플럭스(1) 또는 수위(2) 노드스트링
- `type2`: 플럭스인 경우, 무플럭스(20) 또는 하천(22)

**동작**:
- 매개변수가 제공되지 않으면 대화형 플롯 표시
- 사용자가 데이터 커서로 vstart 및 vend 선택
- `extract_boundary` 호출하여 경계 추출 및 obj.op/obj.bd 업데이트

---

### 3.4 'weirs' 모드 (위어 경계)
**위치**: `msh.m:1955-2095`

**기능**: gdat에 전달된 모든 위어에 위어 경계 조건(ibtype=24) 적용

**사용법**:
```matlab
obj = make_bc(obj, 'weirs', gdat, ar, hts)
```

**매개변수**:
- `gdat`: 크레스트라인이 전달된 geodata 클래스
- `ar`: 위어 크레스트 높이 입력 방법 (0=대화형, 1=고정값, 2=데이터셋)
- `hts`: 각 위어의 높이 배열

**알고리즘**:
```
1. gdat.ibconn_pts의 각 위어에 대해:
   a. 전면 노드 찾기 (ourKNNsearch)
   b. 후면 노드 찾기
   c. 거리가 1e-9 초과인 페어 제거
   d. 고유하지 않은 페어 제거
2. 경계 구조체에 추가:
   - nbvv에 전면 노드 저장
   - ibtype = 24 설정
   - ibconn에 후면 노드 저장
   - barinht, barincfsb, barincfsp 설정
```

**위어 속성**:
- `ibconn`: 후면 노드 연결성
- `barinht`: 지오이드 위 위어 크레스트 높이(미터)
- `barincfsb`, `barincfsp`: 표준 값 1

---

### 3.5 'delete' 모드 (경계 삭제)
**위치**: `msh.m:1908-1953`

**기능**: 사용자가 클릭한 육지/본토 경계 조건을 메쉬에서 삭제

**사용법**:
```matlab
obj = make_bc(obj, 'delete', index)
```

**동작**:
- 인덱스가 제공되지 않으면 대화형 플롯 표시
- 사용자가 삭제할 노드스트링 선택
- obj.bd에서 경계 제거

---

## 4. 데이터 구조

### 4.1 개방 경계 (obj.op)
```matlab
obj.op.nope      % 개방 경계 수
obj.op.neta      % 개방 경계 노드 총 수
obj.op.nvdll     % 각 개방 경계의 노드 수 (1 x nope)
obj.op.ibtype    % 경계 유형 (1 x nope, 일반적으로 모두 0)
obj.op.nbdv      % 경계 노드 인덱스 (max(nvdll) x nope)
```

### 4.2 육지 경계 (obj.bd)
```matlab
obj.bd.nbou      % 육지 경계 수
obj.bd.nvel      % 육지 경계 노드 총 수
obj.bd.nvell     % 각 육지 경계의 노드 수 (1 x nbou)
obj.bd.ibtype    % 경계 유형 (1 x nbou, 20/21/22/24 등)
obj.bd.nbvv      % 경계 노드 인덱스 (max(nvell) x nbou)

% 위어(ibtype=24, 4)의 경우 선택적:
obj.bd.ibconn    % 후면 노드 연결성 (max(nvell) x nbou)
obj.bd.barinht   % 위어 크레스트 높이 (max(nvell) x nbou)
obj.bd.barincfsb % 서브크리티컬 유량 계수 (max(nvell) x nbou)
obj.bd.barincfsp % 슈퍼크리티컬 유량 계수 (max(nvell) x nbou)
```

---

## 5. 헬퍼 함수

### 5.1 extract_boundary.m
**위치**: `utilities/extract_boundary.m:1-232`

**기능**: 경계 에지 세트 및 시작/종료 인덱스가 주어지면 와인딩 순서로 정렬하고 기존 opendat/boudat 구조체에 추가

**입력**:
- `v_start, v_end`: 추적할 경계의 시작/종료 인덱스
- `bnde`: 경계 에지 인덱스 (nbnde x 2)
- `pts`: 모든 점의 x,y 위치 (np x 2)
- `order`: 순회 순서 (0=반시계방향, 1=시계방향)
- `opendat, boudat`: 기존 경계 정보
- `type`: 플럭스(1) 또는 수위(2) BC
- `type2`: 플럭스인 경우, 무플럭스(20) 또는 하천(22)

**출력**:
- `poly`: 와인딩 순서로 정렬된 각 폴리곤의 경계
- `poly_idx`: 폴리곤 좌표의 인덱스
- `opendat, boudat`: 업데이트된 경계 정보

**알고리즘** (라인 32-113):
```
1. 방문하지 않은 에지 세그먼트 [v_start, v_next] 선택
2. v_next와 연결된 방문하지 않은 에지 찾기
3. 다른 정점을 폴리곤 루프에 추가
4. v_next를 새로 추가된 정점으로 재설정
5. v_start로 돌아올 때까지 반복
6. 부호 있는 면적으로 와인딩 순서 확인
7. 100k 노드 초과 시 경계 분할 (adcprep 제한)
```

**주의사항**:
- `exceed = 50e3`로 설정되어 각 경계가 50,000 노드를 초과하지 않도록 함 (라인 41)
- 와인딩 순서 확인을 위해 폴리곤 면적 계산 (라인 101-112)

---

### 5.2 extdom_edges2
경계 에지 및 경계 점 추출. `extdom_polygon`과 함께 사용됨.

### 5.3 extdom_polygon
경계 에지 세트를 와인딩 순서로 정렬된 폴리곤으로 변환.

---

## 6. 파일 형식 지원

### 6.1 fort.14 (메쉬 + 경계)
**읽기**: `readfort14.m:1-150`
**쓰기**: `writefort14.m:1-149`

**형식**:
```
제목
NE NP
노드 데이터...
요소 데이터...
NOPE = 개방 경계 수
NETA = 개방 경계 노드 총 수
각 개방 경계에 대해:
  NVDLL = 노드 수
  노드 인덱스...
NBOU = 육지 경계 수
NVEL = 육지 경계 노드 총 수
각 육지 경계에 대해:
  NVELL IBTYPE = 노드 수, 경계 유형
  노드 데이터 (ibtype에 따라 다름)
```

**ibtype별 노드 데이터**:
- **0,1,2,10,11,12,20,21,22,30,52,60,61,101**: 노드 인덱스만
- **3,13,23**: 노드 인덱스, barinht, barincfsp
- **4,24**: 노드 인덱스, ibconn, barinht, barincfsb, barincfsp
- **5,25**: (구현 예정)
- **94**: 노드 인덱스, ibconn

---

### 6.2 fort.15 (경계 조건)
**Make_f15.m**을 통해 생성됨. 시뮬레이션 매개변수 및 경계 조건 사양 포함.

---

## 7. 검토 결과 및 제안

### 7.1 발견된 문제점

#### 1. **일관성 없는 변수 명명**
- `readfort14.m:48`: `ibtypee` (개방 경계용)
- `readfort14.m:88`: `ibtype` (육지 경계용)
- 권장사항: 일관성을 위해 `ibtype_open` 및 `ibtype_land` 사용

#### 2. **하드코딩된 제한**
- `extract_boundary.m:41`: `exceed = 50e3`
- 권장사항: 사용자가 구성 가능한 매개변수로 만들기

#### 3. **전역 메쉬 제한**
- `msh.m:1449-1453`: 'auto' 모드는 전역 메쉬를 지원하지 않음
- 권장사항: 전역 메쉬용 특수 처리 구현

#### 4. **오류 처리**
- `extract_boundary.m:46`: v_start가 경계에 없으면 조용히 반환
- 권장사항: 더 나은 오류 메시지 및 유효성 검사

#### 5. **자동 분류의 모호한 사례**
- `msh.m:1536-1596`: 혼합 경계의 분할 로직이 복잡함
- 권장사항: 더 나은 문서화 및 잠재적인 단순화

#### 6. **하드코딩된 ibtype 목록**
- `Make_f15.m:152`, `readfort15.m:194`, `writefort15.m:180`: `ibtype = [2 12 22 32 52]`
- 권장사항: 중앙 집중식 구성 또는 상수

### 7.2 장점

1. **유연한 분류 시스템**
   - 여러 모드(auto, inner, outer, weirs, delete) 지원
   - 자동 분류를 위한 여러 기준(거리, 수심, 둘 다)

2. **견고한 와인딩 순서 처리**
   - `extract_boundary.m`의 면적 계산으로 올바른 방향 보장

3. **위어 지원**
   - 서브그리드 스케일 구조물에 대한 정교한 처리
   - 연결성 및 크레스트 높이 속성

4. **ADCIRC 호환성**
   - ADCIRC 표준 형식 따름
   - 다양한 ibtype 코드 지원

5. **대화형 모드**
   - 'outer' 및 'delete' 모드의 사용자 친화적 선택

### 7.3 개선 제안

#### 단기적
1. `extract_boundary.m`의 `exceed` 매개변수를 구성 가능하게 만들기
2. 일관성 없는 변수 명명 수정
3. 모호한 사례에 대한 문서 개선

#### 중기적
1. 전역 메쉬 지원 구현
2. 오류 처리 및 유효성 검사 개선
3. ibtype 코드를 중앙 집중식 구성으로 통합

#### 장기적
1. 자동 분류 알고리즘 최적화
2. 기계 학습 기반 경계 분류 고려
3. GUI 기반 경계 편집 도구 개발

---

## 8. 사용 예제

### 예제 1: 자동 경계 분류
```matlab
% gdat를 사용하여 메쉬 생성
m = msh();
m.p = points;
m.t = triangles;

% 거리와 수심 모두를 사용한 자동 분류
m = make_bc(m, 'auto', gdat);

% 또는 사용자 정의 매개변수 사용
dist_limit = 0.1;  % 도 단위
depth_limit = 15;  % 미터
min_vertices = 5;
m = make_bc(m, 'auto', gdat, 'both', dist_limit, depth_limit, min_vertices);
```

### 예제 2: 섬 경계 추가
```matlab
% 외부 경계가 이미 설정되어 있다고 가정
m = make_bc(m, 'inner', 21);  % ibtype=21로 모든 섬 설정
```

### 예제 3: 수동 경계 세그먼트
```matlab
% 정점 100에서 200까지 수위 경계 생성
m = make_bc(m, 'outer', 0, 100, 200, 2);

% 정점 300에서 400까지 하천 플럭스 경계 생성
m = make_bc(m, 'outer', 1, 300, 400, 1, 22);
```

### 예제 4: 위어 추가
```matlab
% gdat에 크레스트라인 전달했다고 가정
weir_heights = [2.5, 3.0, 2.8];  % 각 위어의 높이(미터)
m = make_bc(m, 'weirs', gdat, 1, weir_heights);
```

### 예제 5: 경계 삭제
```matlab
% 인덱스 5의 경계 삭제
m = make_bc(m, 'delete', 5);

% 또는 대화형 선택
m = make_bc(m, 'delete');
```

---

## 9. 참조

### ADCIRC 문서
- [ADCIRC 위키 - ibtype](https://wiki.adcirc.org/)
- [fort.14 파일 형식](https://wiki.adcirc.org/Fort.14_file_format)
- [fort.15 파일 형식](https://wiki.adcirc.org/Fort.15_file_format)

### 관련 함수
- `extdom_edges2`: 경계 에지 추출
- `extdom_polygon`: 경계 폴리곤 추출
- `ourKNNsearch`: K-최근접 이웃 검색

---

## 10. 요약

OceanMesh2D의 경계 분류 및 설정 시스템은 다음과 같은 특징을 가지고 있습니다:

**강점**:
- 포괄적이고 유연한 경계 관리
- 여러 분류 방법 지원
- ADCIRC 표준 준수
- 위어 및 복잡한 경계 구조 처리

**개선 영역**:
- 일부 하드코딩된 값 및 제한
- 전역 메쉬 지원 제한
- 문서화 개선 필요
- 오류 처리 강화 필요

전반적으로 시스템은 잘 설계되어 있으며 대부분의 사용 사례를 효과적으로 처리합니다. 제안된 개선 사항을 구현하면 견고성과 사용성이 더욱 향상될 것입니다.

---

**검토 작성일**: 2025-11-20
**검토자**: Claude (AI Assistant)
**OceanMesh2D 버전**: 현재 main 브랜치
