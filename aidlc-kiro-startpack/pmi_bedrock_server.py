"""
PMI 글로벌 전략 동향 — Amazon Bedrock AI 백엔드 프록시
=====================================================

프론트엔드(pmi-strategy-dashboard.html)의 요청을 받아 Amazon Bedrock의
LLM을 호출하는 간단한 Flask 서버입니다.

AWS 자격증명은 이 서버(서버사이드)에서만 사용되며, 브라우저에 노출되지 않습니다.

엔드포인트
----------
- POST /api/summarize : 전략 관련 텍스트를 요약하고 테마별 인사이트 생성
- POST /api/ask       : PMI 전략에 대한 자연어 질문에 답변
- GET  /api/health    : 서버 및 Bedrock 연결 상태 확인

실행
----
    pip install -r requirements.txt
    # (선택) AWS 자격증명 설정: aws configure  또는 환경변수
    python pmi_bedrock_server.py

환경변수
--------
- AWS_REGION           : Bedrock 리전 (기본값: us-east-1)
- BEDROCK_MODEL_ID     : 사용할 모델 ID (기본값: anthropic.claude-3-5-sonnet-20240620-v1:0)
- PMI_SERVER_PORT      : 서버 포트 (기본값: 5000)

자격증명이 없거나 Bedrock 호출이 실패하면 데모(mock) 응답으로 폴백하여
UI 동작을 확인할 수 있습니다.
"""

import json
import os

from flask import Flask, jsonify, request, send_from_directory

try:
    import boto3
    from botocore.exceptions import BotoCoreError, ClientError, NoCredentialsError
    _BOTO3_AVAILABLE = True
except ImportError:  # boto3 미설치 시에도 데모 모드로 동작
    _BOTO3_AVAILABLE = False

# ----------------------------------------------------------------------------
# 설정
# ----------------------------------------------------------------------------
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
BEDROCK_MODEL_ID = os.environ.get(
    "BEDROCK_MODEL_ID", "anthropic.claude-3-5-sonnet-20240620-v1:0"
)
SERVER_PORT = int(os.environ.get("PMI_SERVER_PORT", "5000"))
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

app = Flask(__name__, static_folder=BASE_DIR)

# 전략 테마 (프론트엔드와 공유되는 분류 체계)
STRATEGY_THEMES = [
    "무연 제품 전환 (Smoke-Free)",
    "니코틴 파우치 / ZYN",
    "지역별 시장 전략",
    "M&A 및 투자",
    "ESG / 규제 대응",
    "재무 성과",
]

SYSTEM_PROMPT = (
    "당신은 글로벌 담배/니코틴 산업 전문 전략 애널리스트입니다. "
    "대상 기업은 Philip Morris International(PMI)입니다. "
    "답변은 반드시 한국어로, 객관적이고 간결하게 작성하세요. "
    "추측이 포함될 경우 '추정'임을 명시하고, 투자 판단의 근거가 아닌 참고 정보임을 전제로 합니다."
)


# ----------------------------------------------------------------------------
# Bedrock 클라이언트
# ----------------------------------------------------------------------------
def get_bedrock_client():
    """Bedrock Runtime 클라이언트를 생성한다. 실패 시 None."""
    if not _BOTO3_AVAILABLE:
        return None
    try:
        return boto3.client("bedrock-runtime", region_name=AWS_REGION)
    except Exception as exc:  # noqa: BLE001
        app.logger.warning("Bedrock 클라이언트 생성 실패: %s", exc)
        return None


def invoke_bedrock(user_prompt, max_tokens=1200):
    """
    Bedrock Converse API로 LLM을 호출한다.

    반환값: (text, used_bedrock: bool)
    자격증명/호출 실패 시 데모 응답과 함께 used_bedrock=False 반환.
    """
    client = get_bedrock_client()
    if client is None:
        return _demo_response(user_prompt), False

    try:
        response = client.converse(
            modelId=BEDROCK_MODEL_ID,
            system=[{"text": SYSTEM_PROMPT}],
            messages=[{"role": "user", "content": [{"text": user_prompt}]}],
            inferenceConfig={"maxTokens": max_tokens, "temperature": 0.3},
        )
        text = response["output"]["message"]["content"][0]["text"]
        return text, True
    except (NoCredentialsError, ClientError, BotoCoreError, KeyError) as exc:
        app.logger.warning("Bedrock 호출 실패, 데모 모드로 폴백: %s", exc)
        return _demo_response(user_prompt), False
    except Exception as exc:  # noqa: BLE001
        app.logger.warning("예상치 못한 오류, 데모 모드로 폴백: %s", exc)
        return _demo_response(user_prompt), False


def _demo_response(user_prompt):
    """Bedrock 미사용 시 반환할 데모 텍스트."""
    return (
        "⚠️ [데모 모드] 현재 Amazon Bedrock에 연결되지 않아 샘플 응답을 표시합니다.\n\n"
        "PMI(필립모리스 인터내셔널)는 'Smoke-Free Future' 비전 아래 전통 궐련에서 "
        "IQOS 등 가열담배와 ZYN 등 니코틴 파우치 중심으로 포트폴리오를 전환하고 있습니다. "
        "무연 제품 매출 비중이 지속적으로 확대되고 있으며, 미국 시장에서 ZYN의 "
        "성장세가 두드러집니다.\n\n"
        "주요 시사점(추정):\n"
        "1. 무연 제품으로의 전환 가속화로 규제 환경 대응이 핵심 변수.\n"
        "2. 미국·EU 등 선진 시장과 신흥 시장의 차별화된 전략 필요.\n"
        "3. ESG 및 공중보건 규제 대응이 브랜드 신뢰도에 직결.\n\n"
        "실제 AI 분석을 사용하려면 서버에 AWS 자격증명을 설정하고 Bedrock 모델 "
        "액세스를 활성화하세요. (README 참고)\n\n"
        f"[요청 요약] {user_prompt[:160]}..."
    )


# ----------------------------------------------------------------------------
# 라우트
# ----------------------------------------------------------------------------
@app.route("/")
def index():
    return send_from_directory(BASE_DIR, "pmi-strategy-dashboard.html")


@app.route("/<path:filename>")
def static_files(filename):
    return send_from_directory(BASE_DIR, filename)


@app.route("/api/health", methods=["GET"])
def health():
    client = get_bedrock_client()
    return jsonify(
        {
            "status": "ok",
            "boto3_available": _BOTO3_AVAILABLE,
            "bedrock_client": client is not None,
            "region": AWS_REGION,
            "model_id": BEDROCK_MODEL_ID,
        }
    )


@app.route("/api/summarize", methods=["POST"])
def summarize():
    data = request.get_json(silent=True) or {}
    content = (data.get("text") or "").strip()

    if not content:
        return jsonify({"error": "분석할 텍스트(text)가 비어 있습니다."}), 400

    prompt = (
        "다음은 Philip Morris International(PMI)의 글로벌 사업 전략과 관련된 "
        "자료입니다. 아래 작업을 수행하세요.\n\n"
        "1) 핵심 내용을 5줄 이내로 요약\n"
        "2) 아래 전략 테마 중 관련 있는 테마를 선택하여 각 테마별 시사점 제시\n"
        f"   테마 목록: {', '.join(STRATEGY_THEMES)}\n"
        "3) 주목할 변화와 잠재 리스크를 각각 2~3개 bullet로 정리\n\n"
        "=== 자료 시작 ===\n"
        f"{content}\n"
        "=== 자료 끝 ==="
    )

    result, used_bedrock = invoke_bedrock(prompt)
    return jsonify({"result": result, "used_bedrock": used_bedrock})


@app.route("/api/ask", methods=["POST"])
def ask():
    data = request.get_json(silent=True) or {}
    question = (data.get("question") or "").strip()

    if not question:
        return jsonify({"error": "질문(question)이 비어 있습니다."}), 400

    prompt = (
        "다음은 Philip Morris International(PMI)의 글로벌 사업 전략에 대한 "
        "질문입니다. 전문 애널리스트 관점에서 한국어로 답변하세요. "
        "확실하지 않은 수치는 '추정'임을 밝히세요.\n\n"
        f"[질문] {question}"
    )

    result, used_bedrock = invoke_bedrock(prompt)
    return jsonify({"result": result, "used_bedrock": used_bedrock})


if __name__ == "__main__":
    print(f"PMI Bedrock AI 서버 시작: http://localhost:{SERVER_PORT}")
    print(f"  - 리전: {AWS_REGION}")
    print(f"  - 모델: {BEDROCK_MODEL_ID}")
    print(f"  - boto3 사용 가능: {_BOTO3_AVAILABLE}")
    app.run(host="0.0.0.0", port=SERVER_PORT, debug=False)
