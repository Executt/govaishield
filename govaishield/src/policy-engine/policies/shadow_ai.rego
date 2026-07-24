package govaishield.ai_policy

import future.keywords.in

default allow := false

# Modelo nacional homologado e dado não ultrassecreto → permite
allow {
    input.ai_provider in data.approved_providers.nacionais
    input.data_classification != "ULTRASSECRETO"
    input.user_authenticated == true
}

# Bloqueia IA não homologada para dado sensível
deny[msg] {
    input.data_classification in ["DADO_PESSOAL_SENSIVEL", "DADO_SAUDE"]
    not input.ai_provider in data.approved_providers.homologados
    msg := sprintf("IA %s não homologada para dado sensível", [input.ai_provider])
}

# Dados classificados nunca saem da GOVNET
deny[msg] {
    input.data_classification in ["ULTRASSECRETO", "SECRETO", "RESERVADO"]
    input.destination_network != "GOVNET"
    msg := "Dados classificados não podem sair da GOVNET"
}

# Quota
deny[msg] {
    input.daily_tokens_used > input.quota_max_tokens
    msg := "Quota diária de tokens excedida"
}

# Agentes autônomos exigem aprovação humana
deny[msg] {
    input.request_type == "AGENT_AUTONOMOUS"
    not input.has_human_approval
    msg := "Agente autônomo requer aprovação humana (Marco Legal IA, Art. 12)"
}
