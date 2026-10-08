# PMI 글로벌 전략 동향 — Bedrock AI 대시보드

Philip Morris International(PMI)의 글로벌 사업 전략 동향을 Amazon Bedrock
LLM으로 요약·분석하고, 자연어 Q&A를 제공하는 웹 페이지입니다.

## 구성

- `pmi-strategy-dashboard.html` — 프론트엔드 대시보드 (5개 탭)
- `pmi_bedrock_server.py` — Bedrock 호출 백엔드 프록시 (Flask)
- `requirements.txt` — 의존성

AWS 자격증명은 백엔드에서만 사용되며 브라우저에 노출되지 않습니다.
자격증명이 없으면 **데모 모드**로 동작하여 UI를 그대로 확인할 수 있습니다.

## 실행 방법

### 1. 의존성 설치
```bash
pip install -r requirements.txt
```

### 2. (선택) AWS 자격증명 및 Bedrock 설정
실제 AI 분석을 사용하려면:
```bash
aws configure            # 또는 환경변수 AWS_ACCESS_KEY_ID 등 설정
export AWS_REGION=us-east-1
```
그리고 AWS 콘솔 → Amazon Bedrock → Model access 에서 사용할 모델
(기본값: `anthropic.claude-3-5-sonnet-20240620-v1:0`) 액세스를 활성화하세요.

> 자격증명이 없거나 모델 액세스가 없으면 자동으로 데모 응답을 반환합니다.

### 3. 서버 실행
```bash
python pmi_bedrock_server.py
```
기본 주소: http://localhost:5000

브라우저에서 위 주소를 열면 대시보드가 표시됩니다.
(GitHub Codespaces에서는 PORTS 탭에서 5000 포트를 열어 접속)

## 환경변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `AWS_REGION` | `us-east-1` | Bedrock 리전 |
| `BEDROCK_MODEL_ID` | `anthropic.claude-3-5-sonnet-20240620-v1:0` | 사용할 모델 |
| `PMI_SERVER_PORT` | `5000` | 서버 포트 |

## API

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/api/health` | 서버/Bedrock 연결 상태 |
| POST | `/api/summarize` | `{"text": "..."}` 전략 자료 요약 |
| POST | `/api/ask` | `{"question": "..."}` 자연어 질문 답변 |

## 주의

- 수치·분석은 데모/참고용이며 투자 판단의 근거가 아닙니다.
- 생성형 AI 결과는 오류를 포함할 수 있으므로 원문 검증이 필요합니다.
- Bedrock 사용 요금은 모델별 토큰 사용량 기준으로 과금됩니다
  (AWS Bedrock 요금 페이지 참고).
