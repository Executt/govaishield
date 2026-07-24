package govaishield.ai_policy

test_allow_nacional {
    allow with input as {
        "ai_provider": "maritaca-mara",
        "data_classification": "DADO_PESSOAL",
        "user_authenticated": true,
    } with data.approved_providers.nacionais as ["maritaca-mara"]
}

test_deny_dado_classificado_fora_govnet {
    count(deny) > 0 with input as {
        "data_classification": "SECRETO",
        "destination_network": "INTERNET",
    }
}
