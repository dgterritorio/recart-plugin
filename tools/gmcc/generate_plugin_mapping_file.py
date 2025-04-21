#!/usr/bin/python3
import os
import sys
import json
import re

supported_versions = ['1.1.2', '2.0.1', '2.0.2']

for version in supported_versions:
    map_files = [os.path.join('./mapping/' + version, f) for f in os.listdir('./mapping/' + version) if os.path.isfile(
        os.path.join('./mapping/' + version, f)) and f.lower().endswith('.json')]

    mapping = {}

    total = 0
    mapped = 0
    for mfile in map_files:
        try:
            with open(mfile) as map_file:
                mfp = json.load(map_file)
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

    print('Encontrados ' + str(total) +
        ' ficheiros para mapeamento. {} ({:.2f}%)'.format(mapped, (mapped*100)/total) +
        ' estão mapeados.')

    res = {key: val for key, val in sorted(mapping.items(), key = lambda ele: ele[0])}
    # print("cmap = {}".format( json.dumps(res, indent=4, ensure_ascii=False) ) )

    try:
        with open("../../plugin/convert/mapping_" + version.replace('.', '') + ".py", "w", encoding='utf-8') as base:
            base.write( "cmap = {}".format( json.dumps(res, indent=4, ensure_ascii=False) ) )
    except Exception as e:
        print('Erro a guardar ficheiro de mapping para o plugin: \'' + str(e) + '\'')
