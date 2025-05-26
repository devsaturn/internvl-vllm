FROM vllm/vllm-openai:latest

ENTRYPOINT python3 -m vllm.entrypoints.openai.api_server \
    --port ${PORT:-8000} \
    --model ${MODEL_NAME:-OpenGVLab/InternVL3-14B} \
    ${REVISION:+--revision "$REVISION"}
