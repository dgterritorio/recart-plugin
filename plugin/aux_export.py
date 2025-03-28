displayList = {
    'freguesia': {'index': 110, 'alias': 'Freguesia', 'name': '[01] UNIDADES ADMINISTRATIVAS', 'geom': ['MULTIPOLYGON']},
    'concelho': {'index': 120, 'alias': 'Concelho', 'name': '[01] UNIDADES ADMINISTRATIVAS', 'geom': ['MULTIPOLYGON']},
    'distrito': {'index': 130, 'alias': 'Distrito', 'name': '[01] UNIDADES ADMINISTRATIVAS', 'geom': ['MULTIPOLYGON']},
    'fronteira': {'index': 140, 'alias': 'Fronteira', 'name': '[01] UNIDADES ADMINISTRATIVAS', 'geom': ['LINESTRING']},
    'designacao_local': {'index': 210, 'alias': 'Designação local', 'name': '[02] TOPONÍMIA', 'geom': ['POINT']},
    'curva_de_nivel': {'index': 310, 'alias': 'Curva de nível', 'name': '[03] ALTIMETRIA', 'geom': ['LINESTRINGZ']},
    'linha_de_quebra': {'index': 320, 'alias': 'Linha de quebra', 'name': '[03] ALTIMETRIA', 'geom': ['LINESTRINGZ']},
    'ponto_cotado': {'index': 330, 'alias': 'Ponto cotado', 'name': '[03] ALTIMETRIA', 'geom': ['POINTZ']},
    'agua_lentica': {'index': 410, 'alias': 'Água lêntica', 'name': '[04] HIDROGRAFIA', 'geom': ['POLYGONZ']},
    'barreira': {'index': 420, 'alias': 'Barreira', 'name': '[04] HIDROGRAFIA', 'geom': ['LINESTRING', 'POLYGON']},
    'curso_de_agua_area': {'index': 430, 'alias': 'Curso de água - área', 'name': '[04] HIDROGRAFIA', 'geom': ['POLYGONZ']},
    'curso_de_agua_eixo': {'index': 440, 'alias': 'Curso de água - eixo', 'name': '[04] HIDROGRAFIA', 'geom': ['LINESTRINGZ']},
    'fronteira_terra_agua': {'index': 450, 'alias': 'Fronteira terra-água', 'name': '[04] HIDROGRAFIA', 'geom': ['LINESTRINGZ']},
    'margem': {'index': 460, 'alias': 'Margem', 'name': '[04] HIDROGRAFIA', 'geom': ['POLYGON']},
    'nascente': {'index': 470, 'alias': 'Nascente', 'name': '[04] HIDROGRAFIA', 'geom': ['POINTZ']},
    'no_hidrografico': {'index': 480, 'alias': 'Nó hidrográfico', 'name': '[04] HIDROGRAFIA', 'geom': ['POINTZ']},
    'queda_de_agua': {'index': 490, 'alias': 'Queda de água', 'name': '[04] HIDROGRAFIA', 'geom': ['POINTZ']},
    'zona_humida': {'index': 491, 'alias': 'Zona húmida', 'name': '[04] HIDROGRAFIA', 'geom': ['POLYGONZ']},
    'area_infra_trans_aereo': {'index': 510, 'alias': 'Área da infraestrutura de transporte aéreo', 'name': '[05] TRANSPORTES', 'geom': ['POLYGON']},
    'infra_trans_aereo': {'index': 511, 'alias': 'Infraestrutura de transporte aéreo', 'name': '[05] TRANSPORTES', 'geom': ['POINT']},
    'area_infra_trans_ferrov': {'index': 520, 'alias': 'Área da infraestrutura de transporte ferroviário', 'name': '[05] TRANSPORTES', 'geom': ['POLYGON']},
    'infra_trans_ferrov': {'index': 521, 'alias': 'Infraestrutura de transporte ferroviário', 'name': '[05] TRANSPORTES', 'geom': ['POINT']},
    'linha_ferrea': {'index': 522, 'alias': 'Linha férrea', 'name': '[05] TRANSPORTES', 'geom': []},
    'no_trans_ferrov': {'index': 523, 'alias': 'Nó de transporte ferroviário', 'name': '[05] TRANSPORTES', 'geom': ['POINTZ']},
    'seg_via_ferrea': {'index': 524, 'alias': 'Segmento da via-férrea', 'name': '[05] TRANSPORTES', 'geom': ['LINESTRINGZ']},
    'area_infra_trans_cabo': {'index': 530, 'alias': 'Área da infraestrutura de transporte por cabo', 'name': '[05] TRANSPORTES', 'geom': ['POLYGON']},
    'seg_via_cabo': {'index': 531, 'alias': 'Segmento da via por cabo', 'name': '[05] TRANSPORTES', 'geom': ['LINESTRING']},
    'area_infra_trans_via_navegavel': {'index': 540, 'alias': 'Área da infraestrutura de transporte por via navegável', 'name': '[05] TRANSPORTES', 'geom': ['POLYGON']},
    'infra_trans_via_navegavel': {'index': 541, 'alias': 'Infraestrutura de transporte por via navegável', 'name': '[05] TRANSPORTES', 'geom': ['POINT']},
    'area_infra_trans_rodov': {'index': 550, 'alias': 'Área da infraestrutura de transporte rodoviário', 'name': '[05] TRANSPORTES', 'geom': ['POLYGON']},
    'infra_trans_rodov': {'index': 551, 'alias': 'Infraestrutura de transporte rodoviário', 'name': '[05] TRANSPORTES', 'geom': ['POINT']},
    'no_trans_rodov': {'index': 552, 'alias': 'Nó de transporte rodoviário', 'name': '[05] TRANSPORTES', 'geom': ['POINTZ']},
    'seg_via_rodov': {'index': 553, 'alias': 'Segmento da via rodoviária', 'name': '[05] TRANSPORTES', 'geom': ['LINESTRINGZ']},
    'via_rodov': {'index': 554, 'alias': 'Via rodoviária', 'name': '[05] TRANSPORTES', 'geom': []},
    'via_rodov_limite': {'index': 555, 'alias': 'Via rodoviária - Limite', 'name': '[05] TRANSPORTES', 'geom': ['LINESTRINGZ']},
    'obra_arte': {'index': 560, 'alias': 'Obra de arte', 'name': '[05] TRANSPORTES', 'geom': ['POLYGONZ']},
    'constru_linear': {'index': 610, 'alias': 'Construção linear', 'name': '[06] CONSTRUÇÕES', 'geom': ['LINESTRING']},
    'constru_polig': {'index': 620, 'alias': 'Construção poligonal', 'name': '[06] CONSTRUÇÕES', 'geom': ['POINT', 'POLYGON']},
    'edificio': {'index': 630, 'alias': 'Edifício', 'name': '[06] CONSTRUÇÕES', 'geom': ['POINT', 'POLYGON']},
    'nome_edificio': {'index': 631, 'alias': 'Nome da construção', 'name': '[06] CONSTRUÇÕES', 'geom': []},
    'ponto_interesse': {'index': 640, 'alias': 'Ponto de interesse', 'name': '[06] CONSTRUÇÕES', 'geom': ['POINT', 'POLYGON']},
    'sinal_geodesico': {'index': 650, 'alias': 'Sinal geodésico', 'name': '[06] CONSTRUÇÕES', 'geom': ['POINTZ']},
    'area_agricola_florestal_mato': {'index': 710, 'alias': 'Área agrícola, florestal ou mato', 'name': '[07] OCUPAÇÃO DO SOLO', 'geom': ['POLYGON']},
    'areas_artificializadas': {'index': 720, 'alias': 'Área artificializada', 'name': '[07] OCUPAÇÃO DO SOLO', 'geom': ['POLYGON']},
    'adm_publica': {'index': 810, 'alias': 'Administração pública e órgãos de soberania', 'name': '[08] INFRAESTRUTURAS E SERVIÇOS DE INTERESSE PÚBLICO', 'geom': []},
    'cabo_electrico': {'index': 820, 'alias': 'Cabo elétrico', 'name': '[08] INFRAESTRUTURAS E SERVIÇOS DE INTERESSE PÚBLICO', 'geom': ['LINESTRING']},
    'conduta_de_agua': {'index': 830, 'alias': 'Conduta de água', 'name': '[08] INFRAESTRUTURAS E SERVIÇOS DE INTERESSE PÚBLICO', 'geom': ['LINESTRING']},
    'elem_assoc_agua': {'index': 840, 'alias': 'Elemento associado de água', 'name': '[08] INFRAESTRUTURAS E SERVIÇOS DE INTERESSE PÚBLICO', 'geom': ['POINT', 'POLYGON']},
    'elem_assoc_eletricidade': {'index': 850, 'alias': 'Elemento associado de electricidade', 'name': '[08] INFRAESTRUTURAS E SERVIÇOS DE INTERESSE PÚBLICO', 'geom': ['POINT', 'POLYGON']},
    'elem_assoc_pgq': {'index': 860, 'alias': 'Elemento associado de petróleo, gás e substâncias químicas', 'name': '[08] INFRAESTRUTURAS E SERVIÇOS DE INTERESSE PÚBLICO', 'geom': ['POINT', 'POLYGON']},
    'elem_assoc_telecomunicacoes': {'index': 870, 'alias': 'Elemento associado de telecomunicações', 'name': '[08] INFRAESTRUTURAS E SERVIÇOS DE INTERESSE PÚBLICO', 'geom': ['POINT']},
    'equip_util_coletiva': {'index': 880, 'alias': 'Equipamento de utilização coletiva', 'name': '[08] INFRAESTRUTURAS E SERVIÇOS DE INTERESSE PÚBLICO', 'geom': []},
    'inst_gestao_ambiental': {'index': 890, 'alias': 'Instalação de gestão ambiental', 'name': '[08] INFRAESTRUTURAS E SERVIÇOS DE INTERESSE PÚBLICO', 'geom': []},
    'inst_producao': {'index': 891, 'alias': 'Instalação de produção', 'name': '[08] INFRAESTRUTURAS E SERVIÇOS DE INTERESSE PÚBLICO', 'geom': []},
    'oleoduto_gasoduto_subtancias_quimicas': {'index': 892, 'alias': 'Oleoduto, gasoduto ou substâncias químicas', 'name': '[08] INFRAESTRUTURAS E SERVIÇOS DE INTERESSE PÚBLICO', 'geom': ['LINESTRING']},
    'mob_urbano_sinal': {'index': 910, 'alias': 'Mobiliário Urbano e sinalização', 'name': '[09] MOBILIÁRIO URBANO E SINALIZAÇÃO', 'geom': ['POINT', 'POLYGON']},
    'area_trabalho': {'index': 1110, 'alias': 'Área de trabalho', 'name': '[11] AUXILIAR', 'geom': ['POLYGON']}
}

recartStructure = {
    'freguesia': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'data_publicacao', 'dicofre', 'nome', 'geometria'],
        'ligs': [],
        'refs': []},
    'concelho': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'data_publicacao', 'dico', 'nome', 'geometria'],
        'ligs': [],
        'refs': []},
    'distrito': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'data_publicacao', 'di', 'nome', 'geometria'],
        'ligs': [],
        'refs': []},
    'fronteira': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'data_publicacao', 'geometria'],
        'ligs': [],
        'refs': ['valor_estado_fronteira']},
    'designacao_local': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'geometria'],
        'ligs': [],
        'refs': ['valor_local_nomeado']},
    'curva_de_nivel': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_curva']},
    'linha_de_quebra': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'artificial', 'geometria'],
        'ligs': [],
        'refs': ['valor_classifica', 'valor_natureza_linha']},
    'ponto_cotado': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_classifica_las']},
    'agua_lentica': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'cota_plena_armazenamento', 'data_fonte_dados', 'mare', 'origem_natural', 'profundidade_media', 'id_hidrografico', 'geometria'],
        'ligs': [],
        'refs': ['valor_agua_lentica', 'valor_persistencia_hidrologica']},
    'barreira': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'id_hidrografico', 'geometria'],
        'ligs': [],
        'refs': ['valor_barreira']},
    'curso_de_agua_area': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'delimitacao_conhecida', 'geometria'],
        'ligs': [],
        'refs': []},
    'curso_de_agua_eixo': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'comprimento', 'delimitacao_conhecida', 'ficticio', 'largura', 'id_hidrografico', 'id_curso_de_agua_area', 'ordem_hidrologica', 'origem_natural', 'geometria'],
        'ligs': [],
        'refs': ['valor_posicao_vertical', 'valor_persistencia_hidrologica', 'valor_curso_de_agua']},
    'fronteira_terra_agua': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'data_fonte_dados', 'ilha', 'geometria'],
        'ligs': [],
        'refs': []},
    'margem': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'id_hidrografico', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_margem']},
    'nascente': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'id_hidrografico', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_nascente', 'valor_persistencia_hidrologica']},
    'no_hidrografico': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'id_hidrografico', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_no_hidrografico']},
    'queda_de_agua': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'altura', 'id_hidrografico', 'geometria'],
        'ligs': [],
        'refs': []},
    'zona_humida': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'mare', 'id_hidrografico', 'geometria'],
        'ligs': [],
        'refs': ['valor_zona_humida']},
    'area_infra_trans_aereo': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_area_infra_trans_aereo']},
    'infra_trans_aereo': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'codigo_iata', 'codigo_icao', 'nome', 'geometria'],
        'ligs': [],
        'refs': ['valor_categoria_infra_trans_aereo', 'valor_restricao_infra_trans_aereo', 'valor_tipo_infra_trans_aereo']},
    'area_infra_trans_ferrov': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [(None, 'infra_trans_ferrov_id', True, [('valor_tipo_uso_infra_trans_ferrov', 'itf.v_tp_u'), ('valor_tipo_infra_trans_ferrov', 'itf.val_tp')])],
        'refs': []},
    'infra_trans_ferrov': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'codigo_infra_ferrov', 'nome', 'nplataformas', 'geometria'],
        'ligs': [('lig_infratransferrov_notransferrov', 'no_trans_ferrov',
                  False, [('valor_tipo_no_trans_ferrov', 'nf.val_tip')])],
        'refs': ['valor_tipo_uso_infra_trans_ferrov', 'valor_tipo_infra_trans_ferrov']},
    'linha_ferrea': {
        'fields': ['identificador', 'codigo_linha_ferrea', 'nome'],
        'ligs': [],
        'refs': []},
    'no_trans_ferrov': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_no_trans_ferrov']},
    'seg_via_ferrea': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'eletrific', 'gestao', 'velocidade_max', 'jurisdicao', 'geometria'],
        'ligs': [('lig_segviaferrea_linhaferrea', 'linha_ferrea', False, [])],
        'refs': ['valor_categoria_bitola', 'valor_estado_linha_ferrea', 'valor_posicao_vertical_transportes', 'valor_tipo_linha_ferrea', 'valor_tipo_troco_via_ferrea', 'valor_via_ferrea']},
    'area_infra_trans_cabo': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': []},
    'seg_via_cabo': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_via_cabo']},
    'area_infra_trans_via_navegavel': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_area_infra_trans_via_navegavel']},
    'infra_trans_via_navegavel': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'codigo_via_navegavel', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_infra_trans_via_navegavel']},
    'area_infra_trans_rodov': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [(None, 'infra_trans_rodov_id', True, [('valor_tipo_infra_trans_rodov', 'itr.v_tip')])],
        'refs': []},
    'infra_trans_rodov': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'geometria'],
        'ligs': [('lig_valor_tipo_servico_infra_trans_rodov', 'valor_tipo_servico',
                  True, []),
                 ('lig_infratransrodov_notransrodov', 'no_trans_rodov',
                  False, [('valor_tipo_no_trans_rodov', 'nr.val_tip')])],
        'refs': ['valor_tipo_infra_trans_rodov']},
    'no_trans_rodov': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_no_trans_rodov']},
    'seg_via_rodov': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'gestao', 'largura_via_rodov', 'multipla_faixa_rodagem', 'num_vias_transito', 'pavimentado', 'velocidade_max', 'jurisdicao', 'geometria'],
        'ligs': [('lig_valor_tipo_circulacao_seg_via_rodov', 'valor_tipo_circulacao',
                  True, []),
                 ('lig_segviarodov_viarodov', 'via_rodov',
                  False, []),
                 ('lig_segviarodov_viarodovlimite', 'via_rodov_limite',
                  False, [('valor_tipo_limite', 'vrl.val_tp')])],
        'refs': ['valor_caract_fisica_rodov', 'valor_estado_via_rodov', 'valor_posicao_vertical_transportes', 'valor_restricao_acesso', 'valor_sentido', 'valor_tipo_troco_rodoviario']},
    'via_rodov': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'codigo_via_rodov', 'data_cat', 'fonte_aquisicao_dados', 'nome', 'nome_alternativo', 'tipo_via_rodov_abv', 'tipo_via_rodov_c', 'tipo_via_rodov_d'],
        'ligs': [],
        'refs': []},
    'via_rodov_limite': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_limite']},
    'obra_arte': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_obra_arte']},
    'constru_linear': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'suporte', 'largura', 'geometria'],
        'ligs': [],
        'refs': ['valor_construcao_linear']},
    'constru_polig': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_construcao']},
    'edificio': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'altura_edificio', 'data_const', 'geometria'],
        'ligs': [('lig_valor_utilizacao_atual_edificio', 'valor_utilizacao_atual', True, []),
                 ('nome_edificio', None, True, []),
                 ('numero_policia_edificio', None, True, []),
                 (None, 'inst_producao_id', True, [
                     ('valor_instalacao_producao', 'ip.v_inst')]),
                 (None, 'inst_gestao_ambiental_id', True, [
                     ('valor_instalacao_gestao_ambiental', 'ga.v_inst')]),
                 ('lig_adm_publica_edificio', 'adm_publica',
                  False, [('valor_tipo_adm_publica', 'ap.val_tip')]),
                 ('lig_equip_util_coletiva_edificio', 'equip_util_coletiva', False, [('lig_valor_tipo_equipamento_coletivo_equip_util_coletiva', 'valor_tipo_equipamento_coletivo', 'uc.val_tp')])],
        'refs': ['valor_condicao_const', 'valor_elemento_edificio_xy', 'valor_elemento_edificio_z', 'valor_forma_edificio']
    },
    'ponto_interesse': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_ponto_interesse']},
    'sinal_geodesico': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'data_revisao', 'nome', 'geometria'],
        'ligs': [],
        'refs': ['valor_local_geodesico', 'valor_ordem', 'valor_tipo_sinal_geodesico']},
    'area_agricola_florestal_mato': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'geometria'],
        'ligs': [],
        'refs': ['valor_areas_agricolas_florestais_matos']},
    'areas_artificializadas': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'geometria'],
        'ligs': [(None, 'inst_producao_id', True, [
                 ('valor_instalacao_producao', 'ip.v_inst')]),
                 (None, 'inst_gestao_ambiental_id', True, [
                     ('valor_instalacao_gestao_ambiental', 'ga.v_inst')]),
                 (None, 'equip_util_coletiva_id', True, [('lig_valor_tipo_equipamento_coletivo_equip_util_coletiva', 'valor_tipo_equipamento_coletivo', 'uc.val_tp')])],
        'refs': ['valor_areas_artificializadas']},
    'adm_publica': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'ponto_de_contacto'],
        'ligs': [],
        'refs': ['valor_tipo_adm_publica']},
    'cabo_electrico': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'tensao_nominal', 'geometria'],
        'ligs': [],
        'refs': ['valor_designacao_tensao', 'valor_posicao_vertical']},
    'conduta_de_agua': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'diametro', 'geometria'],
        'ligs': [],
        'refs': ['valor_conduta_agua', 'valor_posicao_vertical']},
    'elem_assoc_agua': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_elemento_associado_agua']},
    'elem_assoc_eletricidade': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_elemento_associado_electricidade']},
    'elem_assoc_pgq': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_elemento_associado_pgq']},
    'elem_assoc_telecomunicacoes': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_elemento_associado_telecomunicacoes']},
    'equip_util_coletiva': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'ponto_de_contacto'],
        'ligs': [('lig_valor_tipo_equipamento_coletivo_equip_util_coletiva', 'valor_tipo_equipamento_coletivo', True, [])],
        'refs': []},
    'inst_gestao_ambiental': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome'],
        'ligs': [],
        'refs': ['valor_instalacao_gestao_ambiental']},
    'inst_producao': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'nome', 'descricao_da_funcao'],
        'ligs': [],
        'refs': ['valor_instalacao_producao']},
    'oleoduto_gasoduto_subtancias_quimicas': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'diametro', 'geometria'],
        'ligs': [],
        'refs': ['valor_gasoduto_oleoduto_sub_quimicas', 'valor_posicao_vertical']},
    'mob_urbano_sinal': {
        'fields': ['identificador', 'inicio_objeto', 'fim_objeto', 'geometria'],
        'ligs': [],
        'refs': ['valor_tipo_de_mob_urbano_sinal']},
    'area_trabalho': {
        'fields': ['identificador', '"data"', 'nivel_de_detalhe', 'nome', 'nome_proprietario', 'nome_produtor', 'data_homologacao', 'geometria'],
        'ligs': [],
        'refs': []}
}

joins = {
    'lig_segviarodov_viarodov': {
        'join_table': 'via_rodov',
        'join_field': 'identificador',
        'target_field': 'via_rodov_id',
        'joined_fields': ['nome'],
        'memory_cache': True,
        'prefix': 'vr_'
    },
    'lig_segviaferrea_linhaferrea': {
        'join_table': 'Linha férrea',
        'join_field': 'identificador',
        'target_field': 'linha_ferrea_id',
        'joined_fields': ['nome'],
        'memory_cache': True,
        'prefix': 'lf_'
    },
    'lig_adm_publica_edificio': {
        'join_table': 'adm_publica',
        'join_field': 'identificador',
        'target_field': 'linha_ferrea_id',
        'joined_fields': ['nome', 'ponto_de_contacto', 'valor_tipo_adm_publica'],
        'memory_cache': True,
        'prefix': 'ap_'
    },
    'lig_equip_util_coletiva_edificio': {
        'join_table': 'equip_util_coletiva',
        'join_field': 'identificador',
        'target_field': 'linha_ferrea_id',
        'joined_fields': ['nome', 'ponto_de_contacto'],
        'memory_cache': True,
        'prefix': 'euc_'
    }
}

fieldNameMap = {
    'freguesia': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'data_publicacao': 'dt_pub'
    },
    'concelho': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'data_publicacao': 'dt_pub'
    },
    'distrito': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'data_publicacao': 'dt_pub'
    },
    'fronteira': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'data_publicacao': 'dt_pub',
        'valor_estado_fronteira': 'val_e_frt'
    },
    'designacao_local': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_local_nomeado': 'val_loc_nm'
    },
    'curva_de_nivel': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_curva': 'val_tipo'
    },
    'linha_de_quebra': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_classifica': 'val_class',
        'valor_natureza_linha': 'val_nat_ln'
    },
    'ponto_cotado': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_classifica_las': 'val_cl_las'
    },
    'agua_lentica': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'cota_plena_armazenamento': 'ct_pln_arm',
        'data_fonte_dados': 'dt_fnt_dad',
        'origem_natural': 'orig_nat',
        'profundidade_media': 'pro_media',
        'id_hidrografico': 'id_hidr',
        'valor_agua_lentica': 'val_ag_len',
        'valor_persistencia_hidrologica': 'val_p_hidr'
    },
    'barreira': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'id_hidrografico': 'id_hidr',
        'valor_barreira': 'val_barr'
    },
    'curso_de_agua_area': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'delimitacao_conhecida': 'del_conhec',
    },
    'curso_de_agua_eixo': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'comprimento': 'comprmnto',
        'delimitacao_conhecida': 'del_conhec',
        'id_hidrografico': 'id_hidr',
        'id_curso_de_agua_area': 'id_c_ag_ar',
        'ordem_hidrologica': 'ordem_hidr',
        'origem_natural': 'orig_nat',
        'valor_posicao_vertical': 'val_pos_vt',
        'valor_persistencia_hidrologica': 'val_ps_hdr',
        'valor_curso_de_agua': 'val_crs_ag'
    },
    'fronteira_terra_agua': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'data_fonte_dados': 'dt_fnt_dad'
    },
    'margem': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'id_hidrografico': 'id_hidr',
        'valor_tipo_margem': 'val_tipo'
    },
    'nascente': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'id_hidrografico': 'id_hidr',
        'valor_tipo_nascente': 'val_tipo',
        'valor_persistencia_hidrologica': 'val_ps_hdr'
    },
    'no_hidrografico': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'id_hidrografico': 'id_hidr',
        'valor_tipo_no_hidrografico': 'val_tipo',
    },
    'queda_de_agua': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'id_hidrografico': 'id_hidr',
    },
    'zona_humida': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'id_hidrografico': 'id_hidr',
        'valor_zona_humida': 'val_zn_hum'
    },
    'area_infra_trans_aereo': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_area_infra_trans_aereo': 'val_tipo'
    },
    'infra_trans_aereo': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'codigo_iata': 'cod_iata',
        'codigo_icao': 'cod_icao',
        'valor_categoria_infra_trans_aereo': 'val_cat',
        'valor_restricao_infra_trans_aereo': 'valor_rstr',
        'valor_tipo_infra_trans_aereo': 'val_tipo',
    },
    'area_infra_trans_ferrov': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj'
    },
    'infra_trans_ferrov': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'codigo_infra_ferrov': 'cod_infra',
        'nplataformas': 'nplat',
        'valor_tipo_uso_infra_trans_ferrov': 'val_tp_uso',
        'valor_tipo_infra_trans_ferrov': 'val_tipo',
        'infra_trans_ferrov.identificador': 'itf.id',
        'infra_trans_ferrov.inicio_objeto': 'itf.i_obj',
        'infra_trans_ferrov.codigo_infra_ferrov': 'itf.cd_ifr',
        'infra_trans_ferrov.nplataformas': 'itf.nplat'
    },
    'linha_ferrea': {
        'identificador': 'identifica',
        'codigo_linha_ferrea': 'cod_ln_fr',
        'linha_ferrea.identificador': 'lf.id',
        'linha_ferrea.codigo_linha_ferrea': 'lf.c_ln_fr',
        'linha_ferrea.nome': 'lf.nome',
    },
    'no_trans_ferrov': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_no_trans_ferrov': 'val_tipo',
        'no_trans_ferrov.identificador': 'nf.id',
    },
    'seg_via_ferrea': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'velocidade_max': 'vel_max',
        'valor_categoria_bitola': 'val_cat_bi',
        'valor_estado_linha_ferrea': 'val_est_ln',
        'valor_posicao_vertical_transportes': 'val_p_vert',
        'valor_tipo_linha_ferrea': 'val_tip_ln',
        'valor_tipo_troco_via_ferrea': 'val_tip_tr',
        'valor_via_ferrea': 'val_via_fe'
    },
    'area_infra_trans_cabo': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj'
    },
    'seg_via_cabo': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_via_cabo': 'val_tipo'
    },
    'area_infra_trans_via_navegavel': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_area_infra_trans_via_navegavel': 'val_tipo'
    },
    'infra_trans_via_navegavel': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'codigo_via_navegavel': 'cod_v_nav',
        'valor_tipo_infra_trans_via_navegavel': 'val_tipo'
    },
    'area_infra_trans_rodov': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj'
    },
    'infra_trans_rodov': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_infra_trans_rodov': 'val_tipo',
        'infra_trans_rodov.identificador': 'itr.id',
        'infra_trans_rodov.nome': 'itr.nome'
    },
    'valor_tipo_servico': {
        'valor_tipo_servico.descricao': 'val_tp_ser'
    },
    'no_trans_rodov': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_no_trans_rodov': 'val_tipo',
        'no_trans_rodov.identificador': 'nr.id'
    },
    'seg_via_rodov': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'largura_via_rodov': 'larg_via',
        'multipla_faixa_rodagem': 'mult_fx_rd',
        'num_vias_transito': 'n_vias',
        'pavimentado': 'paviment',
        'velocidade_max': 'vel_max',
        'valor_caract_fisica_rodov': 'val_cara_f',
        'valor_estado_via_rodov': 'val_estado',
        'valor_posicao_vertical_transportes': 'val_p_vert',
        'valor_restricao_acesso': 'val_restr',
        'valor_sentido': 'val_sentid',
        'valor_tipo_troco_rodoviario': 'val_tipo'
    },
    'via_rodov': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'codigo_via_rodov': 'cod_v_r',
        'fonte_aquisicao_dados': 'fnt_dados',
        'nome_alternativo': 'nome_alt',
        'tipo_via_rodov_abv': 'tipo_abv',
        'tipo_via_rodov_c': 'tipo_c',
        'tipo_via_rodov_d': 'tipo_d',
        'via_rodov.identificador': 'vr.id',
        'via_rodov.codigo_via_rodov': 'vr.cod_v_r',
        'via_rodov.data_cat': 'vr.dt_cat',
        'via_rodov.fonte_aquisicao_dados': 'vr.fnt_dds',
        'via_rodov.nome': 'vr.nome',
        'via_rodov.nome_alternativo': 'vr.nm_alt',
        'via_rodov.tipo_via_rodov_abv': 'vr.tip_abv',
        'via_rodov.tipo_via_rodov_c': 'vr.tipo_c',
        'via_rodov.tipo_via_rodov_d': 'vr.tipo_d'
    },
    'via_rodov_limite': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_limite': 'val_tipo',
        'via_rodov_limite.identificador': 'vrl.id',
        'via_rodov_limite.valor_tipo_limite': 'vrl.val_tp'
    },
    'obra_arte': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_obra_arte': 'val_tipo'
    },
    'constru_linear': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_construcao_linear': 'val_c_lin'
    },
    'constru_polig': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_construcao': 'val_tipo'
    },
    'edificio': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_condicao_const': 'val_cond_c',
        'valor_elemento_edificio_xy': 'val_eed_xy',
        'valor_elemento_edificio_z': 'val_eed_z',
        'valor_forma_edificio': 'val_frm_ed',
        'altura_edificio': 'altura_ed'
    },
    'valor_utilizacao_atual': {
        'valor_utilizacao_atual.descricao': 'val_util_a'
    },
    'nome_edificio': {
        'nome_edificio.nome': 'nome'
    },
    'numero_policia_edificio': {
        'numero_policia_edificio.numero_policia': 'nm_policia'
    },
    'ponto_interesse': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_ponto_interesse': 'val_tipo'
    },
    'sinal_geodesico': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'data_revisao': 'dt_revisao',
        'valor_local_geodesico': 'val_lc_geo',
        'valor_ordem': 'val_ordem',
        'valor_tipo_sinal_geodesico': 'val_tipo'
    },
    'area_agricola_florestal_mato': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_areas_agricolas_florestais_matos': 'val_ar_afm'
    },
    'areas_artificializadas': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_areas_artificializadas': 'val_ar_art'
    },
    'adm_publica': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'ponto_de_contacto': 'pt_cont',
        'valor_tipo_adm_publica': 'val_tipo',
        'adm_publica.identificador': 'ap.id',
        'adm_publica.inicio_objeto': 'ap.ini_obj',
        'adm_publica.fim_objeto': 'ap.fim_obj',
        'adm_publica.nome': 'ap.nome',
        'adm_publica.ponto_de_contacto': 'ap.pt_cont'
    },
    'cabo_electrico': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'tensao_nominal': 'tensao_nom',
        'valor_designacao_tensao': 'val_tensao',
        'valor_posicao_vertical': 'val_p_vert'
    },
    'conduta_de_agua': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_conduta_agua': 'val_cdt_ag',
        'valor_posicao_vertical': 'val_p_vert'
    },
    'elem_assoc_agua': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_elemento_associado_agua': 'val_el_ag'
    },
    'elem_assoc_eletricidade': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_elemento_associado_electricidade': 'val_el_ele'
    },
    'elem_assoc_pgq': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_elemento_associado_pgq': 'val_el_pgq'
    },
    'elem_assoc_telecomunicacoes': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_elemento_associado_telecomunicacoes': 'val_el_tel'
    },
    'equip_util_coletiva': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'ponto_de_contacto': 'pt_cont',
        'equip_util_coletiva.identificador': 'uc.id',
        'equip_util_coletiva.inicio_objeto': 'uc.ini_obj',
        'equip_util_coletiva.fim_objeto': 'uc.fim_obj',
        'equip_util_coletiva.nome': 'uc.nome',
        'equip_util_coletiva.ponto_de_contacto': 'uc.pc'
    },
    'valor_tipo_equipamento_coletivo': {
        'valor_tipo_equipamento_coletivo.descricao': 'val_tipo'
    },
    'inst_gestao_ambiental': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_instalacao_gestao_ambiental': 'v_inst',
        'inst_gestao_ambiental.identificador': 'ga.id',
        'inst_gestao_ambiental.inicio_objeto': 'ga.ini_obj',
        'inst_gestao_ambiental.fim_objeto': 'ga.fim_obj',
        'inst_gestao_ambiental.nome': 'ga.nome',
    },
    'inst_producao': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'descricao_da_funcao': 'des_func',
        'valor_instalacao_producao': 'v_inst',
        'inst_producao.identificador': 'ip.id',
        'inst_producao.inicio_objeto': 'ip.ini_obj',
        'inst_producao.fim_objeto': 'ip.fim_obj',
        'inst_producao.nome': 'ip.nome',
        'inst_producao.descricao_da_funcao': 'ip.desc_f'
    },
    'oleoduto_gasoduto_subtancias_quimicas': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_gasoduto_oleoduto_sub_quimicas': 'val_gosq',
        'valor_posicao_vertical': 'val_p_vert'
    },
    'mob_urbano_sinal': {
        'identificador': 'identifica',
        'inicio_objeto': 'ini_obj',
        'valor_tipo_de_mob_urbano_sinal': 'val_tipo'
    },
    'area_trabalho': {
        'identificador': 'identifica',
        'nivel_de_detalhe': 'ndd',
        'nome_proprietario': 'nm_propr',
        'nome_produtor': 'nm_produt',
        'data_homologacao': 'dt_homlg',
    }
}
