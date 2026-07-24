from dlp_engine.rules_br import cpf_valid, cnpj_valid, scan, decide


def test_cpf_valido_e_invalido():
    assert cpf_valid("529.982.247-25") is True
    assert cpf_valid("111.111.111-11") is False
    assert cpf_valid("123.456.789-00") is False


def test_cnpj_valido():
    assert cnpj_valid("11.222.333/0001-81") is True
    assert cnpj_valid("00.000.000/0000-00") is False


def test_scan_e_decide_block():
    f = scan("Veja o CPF 529.982.247-25 e o documento RESERVADO anexo.")
    types = {x.entity for x in f}
    assert "BR_CPF" in types and "BR_DADO_CLASSIFICADO" in types
    assert decide(f) == "BLOCK"


def test_scan_allow():
    assert scan("Nenhum dado sensivel aqui, apenas texto comum.") == []
