# 실제 API JSON 계약 명세

## 문서 목적
이 문서는 현재 프로그램이 실제 API에서 받아야 하는 JSON 응답 형식을 구체적으로 정의한다.

특히 아래 3가지를 명확히 하는 것이 목적이다.

1. 어떤 JSON 형식을 API가 반환해야 하는가
2. 각 필드에서 무엇이 필수이고, 무엇이 선택인지
3. LLM에게 어떤 프롬프트를 줘서 그 형식으로 안정적으로 반환하게 할 것인가

---

## 1. 현재 프로그램이 이해하는 API 응답 종류

현재 프로그램은 실제 API 응답을 크게 3종류로 해석한다.

### 1. 일반 대화 응답
자동화를 실행하지 않고, 그냥 요약/안내/질문을 반환하는 형태다.

예:
- “지금은 로그인 정보가 필요합니다.”
- “어떤 결과를 원하시나요?”
- “검색은 완료했지만 다음 행동을 선택해 주세요.”

### 2. Legacy JSON Plan 응답
기존 자동화 엔진이 이해하는 저수준 step 기반 응답이다.

예:
- navigate
- click
- fill
- press
- extract

### 3. Pattern Task 응답
현재 새 패턴 엔진이 이해하는 고수준 작업 의미 기반 응답이다.

예:
- `keyword_search`
- `paired_lookup`
- `form_fill`

실제 서비스에서는 장기적으로 **Pattern Task 응답을 기본값으로 가는 것**을 권장한다.

---

## 2. 응답 형식 1: 일반 대화 응답

이 응답은 자동화 실행을 바로 하지 않고, 앱이 사용자에게 문장을 보여주기 위한 형태다.

### 2.1 JSON 예시

```json
{
  "transcript": "유튜브에서 고양이 영상 찾아줘",
  "summary": "유튜브 검색을 시작할 수 있습니다.",
  "follow_up": "바로 검색을 진행할까요?",
  "pending_action": "search_youtube",
  "pending_target": "고양이 영상",
  "status": "success",
  "completes_follow_up": false,
  "is_error": false,
  "raw_text": "유튜브 검색을 시작할 수 있습니다."
}
```

### 2.2 필드 설명

#### 필수값
- `summary`
  - 타입: `string`
  - 의미: 사용자에게 바로 보여줄 핵심 한 줄 요약
  - 예시: `"유튜브 검색을 시작할 수 있습니다."`

- `status`
  - 타입: `string`
  - 허용값: `"success"`, `"warning"`, `"error"`
  - 의미: 응답 상태
  - 예시: `"success"`

#### 선택값
- `transcript`
  - 타입: `string`
  - 의미: 사용자의 원문 또는 정리된 명령
  - 예시: `"유튜브에서 고양이 영상 찾아줘"`

- `follow_up`
  - 타입: `string`
  - 의미: 사용자의 추가 답변이 필요한 경우 보여줄 문장
  - 예시: `"바로 검색을 진행할까요?"`

- `pending_action`
  - 타입: `string`
  - 의미: 다음 단계에서 이어질 작업 식별자
  - 예시: `"search_youtube"`

- `pending_target`
  - 타입: `string`
  - 의미: 다음 단계에서 사용할 대상
  - 예시: `"고양이 영상"`

- `completes_follow_up`
  - 타입: `boolean`
  - 의미: 이전 후속 질문 상태를 종료하는지 여부
  - 예시: `false`

- `is_error`
  - 타입: `boolean`
  - 의미: 오류 응답인지 여부
  - 예시: `false`

- `raw_text`
  - 타입: `string`
  - 의미: 원본 텍스트 응답 또는 디버깅용 텍스트
  - 예시: `"유튜브 검색을 시작할 수 있습니다."`

### 2.3 언제 이 형식을 쓰는가
- 자동화가 아니라 안내만 할 때
- 사용자 확인이 더 필요할 때
- 아직 구조화 자동화 응답을 만들기 애매할 때

---

## 3. 응답 형식 2: Legacy JSON Plan 응답

이 형식은 기존 JSON 자동화 엔진이 실행하는 방식이다.  
현재 프로그램은 아직 이 형식을 계속 지원한다.

### 3.1 JSON 예시

```json
{
  "task_id": "naver_map_route",
  "goal": "송내역에서 서울역 가는 경로",
  "site": "https://map.naver.com",
  "steps": [
    {
      "step": 1,
      "type": "navigate",
      "args": {
        "url": "https://map.naver.com"
      }
    },
    {
      "step": 2,
      "type": "click",
      "target": {
        "description": "길찾기 버튼"
      }
    }
  ]
}
```

### 3.2 필드 설명

#### 필수값
- `task_id`
  - 타입: `string`
  - 의미: 자동화 계획 식별자
  - 예시: `"naver_map_route"`

- `steps`
  - 타입: `array`
  - 의미: 실제 실행할 저수준 step 목록
  - 예시: `[{ "step": 1, "type": "navigate", ... }]`

#### 선택값
- `goal`
  - 타입: `string`
  - 의미: 작업 목표 설명
  - 예시: `"송내역에서 서울역 가는 경로"`

- `site`
  - 타입: `string`
  - 의미: 진입할 사이트 URL
  - 예시: `"https://map.naver.com"`

### 3.3 step 필드 설명

step object의 주요 필드는 아래다.

- `step`
  - 타입: `number`
  - 의미: 순서 번호

- `type`
  - 타입: `string`
  - 허용 예시: `navigate`, `click`, `fill`, `press`, `wait_for`, `extract`, `finish`

- `target`
  - 타입: `object`
  - 의미: 찾고 싶은 대상 설명 또는 fallback 정보

- `args`
  - 타입: `object`
  - 의미: step 실행 인자

### 3.4 이 형식의 장단점

장점:
- 실행기가 바로 이해하기 쉽다
- 특정 시나리오를 정밀하게 제어할 수 있다

단점:
- API/LLM이 step을 세세하게 만들어야 한다
- 흔들릴 가능성이 크다
- 비용과 유지보수 부담이 크다

---

## 4. 응답 형식 3: Pattern Task 응답

이 형식이 앞으로의 기본 추천 형식이다.  
이 형식에서는 API가 저수준 step을 만드는 대신, 작업 의미만 반환한다.

### 4.1 직접 반환 형식 예시

```json
{
  "site": "https://www.youtube.com",
  "user_request": "유튜브에서 고양이 영상 찾아줘",
  "intent": {
    "task_type": "keyword_search",
    "slots": {
      "query": "고양이 영상"
    },
    "risk_level": "low",
    "confidence": 0.93
  },
  "host_bias": {
    "host": "www.youtube.com",
    "primary_action_label_preferences": ["search"]
  },
  "metadata": {
    "planner_mode": "pattern_task_v1",
    "prompt_version": "pattern_task_prompt_v1"
  }
}
```

### 4.2 래핑 반환 형식 예시

```json
{
  "kind": "pattern_task",
  "task": {
    "site": "https://www.naver.com",
    "user_request": "네이버에서 오늘 날씨 검색해줘",
    "intent": {
      "task_type": "keyword_search",
      "slots": {
        "query": "오늘 날씨"
      },
      "risk_level": "low",
      "confidence": 0.91
    }
  }
}
```

현재 프로그램은 **두 형식 모두 처리 가능**하다.

### 4.3 Pattern Task 최상위 필드 설명

#### 필수값
- `site`
  - 타입: `string`
  - 의미: 진입할 사이트 URL
  - 예시: `"https://www.youtube.com"`

또는

- `user_request`
  - 타입: `string`
  - 의미: 사용자의 원문 요청
  - 예시: `"유튜브에서 고양이 영상 찾아줘"`

또는

- `intent`
  - 타입: `object`
  - 의미: 구조화된 작업 의미

실무적으로는 **`site + user_request + intent`를 모두 주는 것**을 권장한다.

#### 선택값
- `host_bias`
  - 타입: `object`
  - 의미: 특정 호스트에서 점수/정책을 조금 보정하는 힌트

- `metadata`
  - 타입: `object`
  - 의미: 프롬프트 버전, planner 버전 등 추적용 메타데이터

### 4.4 intent 필드 설명

#### 필수값
- `task_type`
  - 타입: `string`
  - 현재 추천값:
    - `keyword_search`
    - `paired_lookup`
    - `form_fill`
    - `select_from_list`
    - `filter_results`
    - `authenticate`
    - `download_resource`
    - `read_result_summary`
  - 예시: `"keyword_search"`

- `slots`
  - 타입: `object`
  - 의미: 작업에 필요한 핵심 값
  - 예시:
    - 검색: `{ "query": "오늘 날씨" }`
    - 길찾기: `{ "source": "송내역", "target": "서울역" }`

- `risk_level`
  - 타입: `string`
  - 허용값: `low`, `medium`, `high`
  - 예시: `"low"`

- `confidence`
  - 타입: `number`
  - 범위: `0.0 ~ 1.0`
  - 의미: LLM이 이 intent를 얼마나 확신하는지
  - 예시: `0.91`

#### 선택값
- `domain_hint`
  - 타입: `string`
  - 의미: 특정 도메인 힌트
  - 예시: `"video_search"`

### 4.5 host_bias 필드 설명

#### 선택값
- `host`
  - 타입: `string`
  - 의미: 대상 호스트
  - 예시: `"map.naver.com"`

- `prefer_panel_ui`
  - 타입: `number`
  - 의미: 패널 UI 선호 가중치
  - 예시: `1.2`

- `autocomplete_confirm_weight`
  - 타입: `number`
  - 의미: 자동완성 확정 중요도 가중치
  - 예시: `1.15`

- `timeout_multiplier`
  - 타입: `number`
  - 의미: 대기 시간 보정
  - 예시: `1.0`

- `preferred_result_landmarks`
  - 타입: `array<string>`
  - 의미: 결과 영역 선호 landmark
  - 예시: `["main", "results"]`

- `primary_action_label_preferences`
  - 타입: `array<string>`
  - 의미: 주 action 라벨 선호
  - 예시: `["search"]`

### 4.6 host_bias에서 넣으면 안 되는 값
아래는 넣으면 안 된다.

- CSS selector
- XPath
- step sequence
- `먼저 A 누르고 다음 B 누른다` 같은 매크로

즉 host_bias는 **점수 보정용 힌트**여야지, **사이트 전용 시나리오 스크립트**가 되면 안 된다.

---

## 5. 현재 프로그램이 받아오는 JSON 스키마 구현 상태

현재 프로그램에는 아래 스키마 구현이 들어가 있다.

### 5.1 메시지 응답 모델
- 파일: [response_models.dart](/C:/Users/USER/Desktop/Navi_front_DEV/lib/shared/models/response_models.dart:1)
- 역할: 일반 대화 응답 파싱

### 5.2 API 응답 통합 모델
- 파일: [agent_api_models.dart](/C:/Users/USER/Desktop/Navi_front_DEV/lib/shared/models/agent_api_models.dart:1)
- 역할:
  - 일반 메시지 응답
  - Legacy JSON plan 응답
  - Pattern task 응답
  를 하나의 파서로 해석

주요 클래스는 아래다.

- `AgentApiPatternIntent`
- `AgentApiHostBias`
- `AgentApiPatternTask`
- `AgentApiLegacyPlan`
- `AgentApiResponseEnvelope`

### 5.3 실제 연결 지점
- 파일: [session_controller.dart](/C:/Users/USER/Desktop/Navi_front_DEV/lib/features/session/application/session_controller.dart:161)

현재 흐름은 이렇다.

1. API 응답 수신
2. `AgentApiResponseEnvelope.parse(...)`로 응답 형식 판별
3. legacy plan이면 기존 JSON 실행기 호출
4. pattern task면 새 pattern 실행기 호출
5. 일반 메시지면 UI 응답으로 사용

즉 이제 프로그램이 “받아오는 현재 JSON 형식”은 코드 상으로도 구분 가능하게 되어 있다.

---

## 6. 최종적으로 LLM에게 줄 프롬프트

현재 구조 기준으로 LLM은 **저수준 step**이 아니라 **Pattern Task JSON**을 반환하는 것이 가장 적절하다.

### 6.1 프롬프트 설계 목표
- selector를 만들지 않게 한다
- Playwright 코드를 만들지 않게 한다
- step 배열을 만들지 않게 한다
- task_type과 slots만 구조화하게 한다
- 필요할 때만 가벼운 host_bias를 추가하게 한다

### 6.2 최종 추천 프롬프트

```text
당신은 웹 자동화 실행기를 위한 planner 역할이다.

목표:
- 사용자 요청을 저수준 브라우저 step이 아니라 Pattern Task JSON으로 변환한다.

중요 규칙:
- JSON만 반환한다.
- 설명, 마크다운, 코드블록을 포함하지 않는다.
- CSS selector를 생성하지 않는다.
- XPath를 생성하지 않는다.
- Playwright 코드를 생성하지 않는다.
- click, fill, press 같은 저수준 step 배열을 생성하지 않는다.
- task_type은 아래 목록 중 하나만 선택한다.
  - keyword_search
  - paired_lookup
  - form_fill
  - select_from_list
  - filter_results
  - authenticate
  - download_resource
  - read_result_summary
- slots에는 작업에 필요한 최소 정보만 넣는다.
- risk_level은 low, medium, high 중 하나를 사용한다.
- confidence는 0.0~1.0 숫자로 넣는다.
- host_bias는 정말 필요할 때만 넣는다.
- host_bias에는 selector, xpath, step 순서, 사이트 전용 매크로를 넣지 않는다.

반환 JSON 형식:
{
  "site": "string",
  "user_request": "string",
  "intent": {
    "task_type": "string",
    "slots": {},
    "risk_level": "low|medium|high",
    "confidence": 0.0,
    "domain_hint": "string (optional)"
  },
  "host_bias": {
    "host": "string",
    "prefer_panel_ui": 1.0,
    "autocomplete_confirm_weight": 1.0,
    "timeout_multiplier": 1.0,
    "preferred_result_landmarks": [],
    "primary_action_label_preferences": []
  },
  "metadata": {
    "planner_mode": "pattern_task_v1",
    "prompt_version": "pattern_task_prompt_v1"
  }
}

반드시 지킬 것:
- site를 알 수 있으면 넣는다.
- user_request는 가능한 한 원문 그대로 유지한다.
- keyword_search는 slots에 query를 넣는다.
- paired_lookup은 slots에 source, target을 넣는다.
- form_fill은 slots에 fields 객체를 넣는다.
- 불확실하면 가장 보수적인 task_type과 낮은 confidence를 사용한다.
```

---

## 7. 프롬프트 예시 출력

### 7.1 네이버 검색

입력:
`네이버에서 오늘 날씨 검색해줘`

출력 예시:

```json
{
  "site": "https://www.naver.com",
  "user_request": "네이버에서 오늘 날씨 검색해줘",
  "intent": {
    "task_type": "keyword_search",
    "slots": {
      "query": "오늘 날씨"
    },
    "risk_level": "low",
    "confidence": 0.91
  },
  "metadata": {
    "planner_mode": "pattern_task_v1",
    "prompt_version": "pattern_task_prompt_v1"
  }
}
```

### 7.2 네이버지도 길찾기

입력:
`네이버 지도로 송내역에서 서울역 가는 경로 알려줘`

출력 예시:

```json
{
  "site": "https://map.naver.com",
  "user_request": "네이버 지도로 송내역에서 서울역 가는 경로 알려줘",
  "intent": {
    "task_type": "paired_lookup",
    "slots": {
      "source": "송내역",
      "target": "서울역"
    },
    "risk_level": "low",
    "confidence": 0.94
  },
  "host_bias": {
    "host": "map.naver.com",
    "prefer_panel_ui": 1.2,
    "autocomplete_confirm_weight": 1.15,
    "primary_action_label_preferences": ["route"]
  },
  "metadata": {
    "planner_mode": "pattern_task_v1",
    "prompt_version": "pattern_task_prompt_v1"
  }
}
```

### 7.3 유튜브 검색

입력:
`유튜브에서 고양이 영상 찾아줘`

출력 예시:

```json
{
  "site": "https://www.youtube.com",
  "user_request": "유튜브에서 고양이 영상 찾아줘",
  "intent": {
    "task_type": "keyword_search",
    "slots": {
      "query": "고양이 영상"
    },
    "risk_level": "low",
    "confidence": 0.93
  },
  "host_bias": {
    "host": "www.youtube.com",
    "primary_action_label_preferences": ["search"]
  },
  "metadata": {
    "planner_mode": "pattern_task_v1",
    "prompt_version": "pattern_task_prompt_v1"
  }
}
```

---

## 8. 실무 기준 추천 결론

실무적으로 가장 추천하는 방향은 아래다.

1. API는 장기적으로 Legacy JSON plan보다 Pattern Task JSON을 기본 응답으로 사용한다.
2. 일반 안내 응답은 기존 메시지 형식을 유지한다.
3. LLM은 step 생성기가 아니라 task/slot planner로 제한한다.
4. host_bias는 가볍게 유지하고, 사이트 전용 매크로로 키우지 않는다.

이렇게 해야:

- 비용을 줄일 수 있고
- 응답 흔들림을 줄일 수 있고
- 로컬 패턴 엔진 개선 효과를 여러 사이트에 재사용할 수 있다

---

## 9. 추천 다음 단계

1. API 서버 응답을 이 문서의 Pattern Task 형식으로 맞춘다.
2. connected mode에서 실제 API 응답으로 `네이버 검색`, `네이버지도 길찾기`, `유튜브 검색`을 검증한다.
3. 이후 결과 추출 품질과 follow-up 액션 지원 범위를 확장한다.
