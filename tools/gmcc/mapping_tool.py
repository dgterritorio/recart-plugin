#!/usr/bin/python3
import os
import sys
import json
import re

import gm_cart_aux as aux

bpaths = [os.path.join('./base', f) for f in os.listdir('./base')
          if os.path.isfile(os.path.join('./base', f)) and f.lower().endswith('.json')]
map_files = [os.path.join('./mapping', f) for f in os.listdir('./mapping') if os.path.isfile(
    os.path.join('./mapping', f)) and f.lower().endswith('.json')]

base_files = {}
mapping = {}

base = 0
for bpath in bpaths:
    try:
        with open(bpath) as base_file:
            if bpath.split('/')[-1] == 'relacoes.json':
                continue
            bfp = json.load(base_file)
            aux.validate_base_dict(bfp)

            objecto = bfp['objecto']
            ccname = re.sub(r'(?<!^)(?=[A-Z])', '_', objecto['objeto']).lower()

            bf = {}
            if 'Tema' in objecto:
                bf['tema'] = objecto['Tema'].lower()
            if 'Característica geográfica' in objecto:
                bf['geo_caract'] = objecto['Característica geográfica'].lower()
            if 'Definição' in objecto:
                bf['def'] = objecto['Definição'].lower()

            bf['attr'] = []
            for attr in objecto['Atributos']:
                attr['Atributo'] = re.sub(
                    r'iD', 'id', attr['Atributo'])
                attr['Atributo'] = re.sub(
                    r'LAS', 'Las', attr['Atributo'])
                attr['Atributo'] = re.sub(
                    r'XY', 'Xy', attr['Atributo'])
                bf['attr'].append({
                    'nome': re.sub(r'(?<!^)(?=[A-Z])', '_', attr['Atributo']).lower(),
                    'mult': attr['Multip.'],
                    'tipo': attr['Tipo'],
                    'd1': attr['D1'],
                    'd2': attr['D2']
                })

            if 'listas de códigos' in objecto:
                bf['lst_cod'] = []
                for lc in objecto['listas de códigos']:
                    blc = {'nome': re.sub(
                        r'(?<!^)(?=[A-Z])', '_', lc['nome']).lower(), 'vals': []}
                    for vlc in lc['valores']:
                        blc['vals'].append({
                            'val': vlc['Valores'].lower(),
                            'def': vlc['Definição'].lower(),
                            'd1': vlc['D1'].lower(),
                            'd2': vlc['D2'].lower()
                        })
                    bf['lst_cod'].append(blc)

            base_files[ccname] = bf
            base += 1

    except Exception as e:
        print("Falhou leitura de ficheiros configuração.\n" + str(e))
        sys.exit(1)

# print(json.dumps(base_files, indent=4, ensure_ascii=False))
# exit(0)
print('Encontrados ' + str(base) + ' ficheiros objectos base.')

total = 0
mapped = 0
for mfile in map_files:
    try:
        with open(mfile) as map_file:
            mfp = json.load(map_file)
            aux.validate_mapping_dict(mfp)

            has_map = False
            for mp in mfp['map']:
                if mp['table']:
                    has_map = True
                    break
            if has_map:
                mapped += 1

            cod = os.path.splitext(os.path.basename(mfile))[0]
            mapping[cod] = mfp
            total += 1
    except Exception as e:
        print("Falhou leitura de ficheiros configuração: \'" + mfile + "\'\n" + str(e))
        sys.exit(1)

# print(json.dumps(mapping, indent=4, ensure_ascii=False))
# exit(0)

print('Encontrados ' + str(total) +
      ' ficheiros para mapeamento. {} ({:.2f}%)'.format(mapped, (mapped*100)/total) +
      ' estão mapeados.')


def search_base(str_list):
    mcount = 0
    chosen = None
    for key in base_files:
        bf = base_files[key]
        fcount = 0
        fcount += len([w for w in str_list if w in bf['tema']])*0.5
        fcount += len([w for w in str_list if w in bf['def']])*0.5

        if 'lst_cod' in bf:
            for lc in bf['lst_cod']:
                for lcv in lc['vals']:
                    fcount += len([w for w in str_list if w in lcv['def']])*2

        if fcount > mcount:
            mcount = fcount
            chosen = key

    return chosen


def get_default(attr):
    value = ''
    if attr['tipo'].lower() == 'datatempo':
        value = "make_date(1, 1, 1)"
    elif attr['tipo'].lower() == 'data':
        value = "make_date(1, 1, 1)"
    elif attr['tipo'].lower() == 'texto':
        value = "SEM DADOS"
    elif attr['tipo'].lower() == 'real':
        value = "-99999"
    elif attr['tipo'].lower() == 'inteiro':
        value = "-99999"
    elif attr['tipo'].lower() == 'booleano':
        value = False
    elif attr['tipo'].lower() == 'lista de códigos':
        value = "888"
    else:
        print('Tipo de dados desconhecido \'' + attr['tipo'] + '\'')
    return value


def create_mapping(map_key, base_key):
    print('Criar mapeamento')
    mapng = mapping[map_key]
    base_obj = base_files[base_key]
    mapng['map'][0] = {
        "table": base_key,
        "fields": [
            {
                "src": "1_geom",
                "dst": "geometria",
                "op": "eq"
            }
        ]
    }

    for attr in base_obj['attr']:
        if attr['nome'] not in ['identificador', 'geometria'] \
            and (attr['d1'] == 'x' or attr['d2'] == 'x') \
                and (attr['mult'] != '[0..1]' and attr['mult'] != '[0..*]'):
            print('\nCampo: \'' + attr['nome'] + '\'')
            f = {}
            src = input('Atributo fonte (\'Enter\' para deixar vazio): ')
            op = input('Operação (set, dnow, nddset): ')
            f['src'] = src
            f['dst'] = attr['nome']
            f['op'] = op
            if op == 'set':
                if attr['nome'] in [lc['nome'] for lc in base_obj['lst_cod']]:
                    print('\tValores possíveis:')
                    for vlc in [lc['vals'] for lc in base_obj['lst_cod'] if lc['nome'] == attr['nome']][0]:
                        print('\t' + str(vlc))
                value = input(
                    'Valor (\'Enter\' para introduzir valor \'vazio\'): ')
                if not value:
                    value = get_default(attr)
                f['value'] = value
            if op == 'nddset':
                f['op'] = 'set'
                if attr['nome'] in [lc['nome'] for lc in base_obj['lst_cod']]:
                    print('\tValores possíveis:')
                    for vlc in [lc['vals'] for lc in base_obj['lst_cod'] if lc['nome'] == attr['nome']][0]:
                        print('\t' + str(vlc))
                valuendd1 = input(
                    'Valor no NdD1 (\'Enter\' para introduzir valor \'vazio\'): ')
                if not valuendd1:
                    valuendd1 = get_default(attr)
                valuendd2 = input(
                    'Valor no NdD2 (\'Enter\' para introduzir valor \'vazio\'): ')
                if not valuendd2:
                    valuendd2 = get_default(attr)
                f['value'] = {
                    'ndd1': valuendd1,
                    'ndd2': valuendd2
                }

            mapng['map'][0]['fields'].append(f)

    with open(str(map_key)+'.json', 'w') as mapfile:
        mapfile.write(json.dumps(mapng, indent=4, ensure_ascii=False))
        print('\nMapeamento criado em \'' + str(map_key) + '.json\'')


def do_map(cod):
    if str(cod) in mapping:
        mp = mapping[str(cod)]
        print('\nEncontrado código a mapear: \'' + str(cod) + '\'')
        print([attr+': ' + mp[attr] for attr in mp if attr != 'map'])

        string_list = []
        # if 'dominio' in mp and mp['dominio']:
        #     string_list += [s.lower()
        #                     for s in mp['dominio'].split() if len(s) > 2]
        # if 'subdominio' in mp and mp['subdominio']:
        #     string_list += [s.lower()
        #                     for s in mp['subdominio'].split() if len(s) > 2]
        if 'familia' in mp and mp['familia']:
            string_list += [s.lower()
                            for s in mp['familia'].split() if len(s) > 2]
        if 'objeto' in mp and mp['objeto']:
            string_list += [s.lower()
                            for s in mp['objeto'].split() if len(s) > 2]
        sugg = search_base(string_list)
        if sugg is not None:
            print('Encontrada sugestão: ')
            print(sugg + ' -> ' + str([attr+': ' + base_files[sugg][attr]
                                       for attr in base_files[sugg] if attr in ['tema', 'geo_caract', 'def']]))

        obj = input(
            '\nIntroduzir objecto de mapeamento (ex. sinal_geodesico, \'Enter\' para ignorar): ')
        if obj not in base_files:
            print('Objecto não encontrado')
            return
        create_mapping(str(cod), obj)
    else:
        print('Código não encontrado')


mp_keys = list(mapping.keys())
current = 0
exit = False
while not exit:
    try:
        print('\nModo de execução: 1 - Escolher ficheiro a mapear | 2 - Próximo não mapeado | 0 - Sair')
        mode = int(input('Escolher [1] ou [2]: '))
        if mode == 1:
            cod = int(input('Introduzir código a mapear: '))
            do_map(cod)
        elif mode == 2:
            for i in range(current, len(mp_keys)):
                found = False
                for mp in mapping[mp_keys[current]]['map']:
                    if not mp['table']:
                        found = True
                        break
                    else:
                        current += 1
                if found:
                    break
            if current < len(mp_keys):
                do_map(mp_keys[current])
                current += 1
        elif mode == 0:
            exit = True
        else:
            print('Escolha inválida')
    except ValueError:
        print("Escolha inválida")
    except Exception:
        print("Erro a gerar mapeamento")
