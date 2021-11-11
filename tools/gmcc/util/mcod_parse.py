#!/usr/bin/python3
import os
import re
import json

import argparse

from osgeo import gdal


def parse_cat(file_path, temas):
    with open(file_path, 'r', encoding="latin-1") as catFile:
        name = os.path.splitext(file_path)[0].split('/')[-1]
        print('Processando ficheiro catálogo \'' + name + '\'')

        currTema = {'name': 'Geral', 'camadas': []}
        currCamada = {}
        for line in catFile:
            if line.startswith('//'):
                if currTema:
                    temas.append(currTema)
                currTema = {'name': line[2:].strip(), 'camadas': []}
            elif re.match(r'\s*"[^"]+"\s*{', line) and 'camadas' in currTema:
                currCamada = {'name': re.sub(
                    r'[\s{"]', '', line), 'features': []}
                currTema['camadas'].append(currCamada)
            elif re.match(r'\s*\d+\s*{', line) and 'features' in currCamada:
                feat = {
                    'code': int(re.match(r'\s*(\d+)', line).group(1)),
                    'name': re.match(r'\s*\d+\s*{.*name[^"]"([^"]+)', line).group(1)
                }
                currCamada['features'].append(feat)
        temas.append(currTema)
    print('Terminado processamento do ficheiro')


def parse_shp(file_path, temas, mcod_field):
    name = os.path.splitext(file_path)[0].split('/')[-1]
    print('Processando shapefile \'' + name + '\'')
    print('\tCampo com multi-código: \'' + mcod_field + '\'')

    data_source = gdal.OpenEx(file_path, gdal.OF_VECTOR)
    if data_source is None:
        print("\t[Erro] Falhou leitura do ficheiro.\n\t\tVerifique que o ficheiro existe\
    e tem um formato de dados suportado.")
        exit(1)

    layer_count = data_source.GetLayerCount()
    if layer_count > 0:
        currTema = {'name': 'Geral', 'camadas': []}
        currCamada = {'name': os.path.splitext(
            file_path)[0].split('/')[-1], 'features': []}

        features = []
        for li in range(layer_count):
            layer = data_source.GetLayerByIndex(li)
            layer.ResetReading()

            fields = []
            feat_defn = layer.GetLayerDefn()
            for fi in range(feat_defn.GetFieldCount()):
                field_defn = feat_defn.GetFieldDefn(fi)
                fields.append(field_defn.GetName())
            if mcod_field not in fields:
                print(
                    'Encontrada layer sem o campo de multi-código definido')
                break

            for feature in layer:
                if feature.IsFieldSet(mcod_field):
                    clink = feature.GetFieldAsString(mcod_field)
                    if clink not in features:
                        features.append(clink)

            for mcod in features:
                feat = {
                    'code': mcod,
                    'name': str(mcod)
                }
                currCamada['features'].append(feat)
            currTema['camadas'].append(currCamada)
        temas.append(currTema)
    print('Terminado processamento do ficheiro')


parser = argparse.ArgumentParser(
    description='Importador de cartografia para o modelo RECART')
parser.add_argument('-f', '--ficheiro', help='ficheiro a processar')
parser.add_argument('-d', '--dir', help='directório com ficheiros a processar')
parser.add_argument('-cf', '--campo_cod', help='campo com multi-código')
args = parser.parse_args()

mcod_field = args.campo_cod if args.campo_cod is not None else 'ulink'
temas = []
process_files = []

if args.dir is not None:
    process_files = [os.path.join(args.dir, f) for f in os.listdir(args.dir) if os.path.isfile(
        os.path.join(args.dir, f)) and (f.lower().endswith('.cat') or f.lower().endswith('.shp'))]
elif args.ficheiro is not None:
    process_files.append(args.ficheiro)
else:
    print('Configuração inválida')
    exit(1)

try:
    for pfile in process_files:
        if os.path.isfile(os.path.join(pfile)):
            if pfile.lower().endswith('.cat'):
                parse_cat(pfile, temas)
            elif pfile.lower().endswith('.shp'):
                parse_shp(pfile, temas, mcod_field)
            else:
                print('Ficheiro de tipo não suportado')
                exit(1)
        else:
            print('Ficheiro inválido')
            exit(1)

    mapping = {}
    for t in temas:
        for c in t['camadas']:
            for f in c['features']:
                mapping[f['code']] = {
                    'tema': t['name'],
                    'camada': c['name'],
                    'nome': f['name'],
                    'map': [{'table': '', 'fields': [{'src': '1_geom', 'dst': 'geometria', 'op': 'eq'}]}]
                }

    dir_path = 'mapping_draft'
    for mp in mapping:
        if not os.path.exists(dir_path):
            os.mkdir(dir_path)
        with open(os.path.join(dir_path, str(mp)+'.json'), 'w') as mapfile:
            mapfile.write(json.dumps(
                mapping[mp], indent=4, ensure_ascii=False))

except Exception as e:
    print(str(e))
