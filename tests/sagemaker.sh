aws sagemaker-runtime invoke-endpoint \
    --endpoint-name mskluev-sagemaker-endpoint \
    --content-type application/json \
    --body fileb://tests/sagemaker.json \
    output.json
cat output.json | jq