#!/usr/bin/python3
from osgeo import gdal
import argparse
import json
import re
import os
import sys
import csv

try:
    sys.path.insert(1, os.path.join(sys.path[0], '..'))
    import gm_cart_aux as aux
except Exception as e:
    print(e)
    exit(1)

if __name__ == '__main__':
    kwargs = {}

    parser = argparse.ArgumentParser(
        description='Criação de alias de códigos para DWG')
    parser.add_argument(
        '-f', '--file', help='ficheiro DWG', required=True)
    parser.add_argument(
        '-a', '--attr', help='atributo com código a mapear', required=True)
    parser.add_argument(
        '-o', '--out', help='nome ficheiro de output')

    args = parser.parse_args()

    # fp = '../exemplos/Amarante/vetor/994pl.dwg'
    # cod_field = 'Layer'.lower()
    fp = args.file
    cod_field = args.attr.lower()
    outname = args.out if args.out else 'map.json'

    layers = []
    map_layers = {}

    print("Iniciar leitura do ficheiro '" + fp + "'")
    data_source = gdal.OpenEx(fp, gdal.OF_VECTOR)
    if data_source is None:
        errstr = "\t[Erro]\tFalhou leitura do ficheiro."
        errstr += "\n\t\tVerifique que o ficheiro existe e tem um formato de dados suportado."
        print(errstr)
        exit(1)

    layer_count = data_source.GetLayerCount()
    print("Analisar Dataset")
    print(aux.dataSource_tostring(data_source, layer_count))

    if layer_count > 0:
        for li in range(layer_count):
            layer = data_source.GetLayerByIndex(li)
            layer.ResetReading()

            fields = []
            feat_defn = layer.GetLayerDefn()
            for fi in range(feat_defn.GetFieldCount()):
                field_defn = feat_defn.GetFieldDefn(fi)
                fields.append({
                    'nome': field_defn.GetName(),
                    'tipo': aux.OGRFieldTypes[field_defn.GetType()]
                })

            print(fields)

            if cod_field not in [f['nome'].lower() for f in fields]:
                print(
                    '\tEncontrada layer sem o campo de multi-código definido. Skipping...')
                break

            save_layer = {
                'nome': layer.GetName(),
                'geometria': aux.OGRwkbGeomTypes[layer.GetGeomType()],
                'campos': fields,
                'elementos': layer.GetFeatureCount(),
                'data': layer
            }

            print("\n\tAnalizar camada " + str(li+1))
            print(aux.layer_tostring(save_layer))

            layers.append(save_layer)

        for layer in layers:
            layer['data'].ResetReading()
            for feature in layer['data']:
                if feature.IsFieldSet(cod_field):
                    clink = feature.GetFieldAsString(cod_field)
                    try:
                        d = json.loads(clink)
                        for cod in d["6549"]:
                            if cod["key"] not in map_layers:
                                map_layers[cod["key"]] = ''
                    except:
                        if clink not in map_layers:
                            map_layers[clink] = ''

        with open(os.path.join('.', outname), 'w') as mapfile:
            mapfile.write(json.dumps(
                map_layers, indent=4, ensure_ascii=False))
        # with open(os.path.join('.', 'map.csv'), 'w') as csvfile:
        #     fieldnames = ['layer', 'cod']
        #     writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

        #     writer.writeheader()
        #     for layer in map_layers:
        #         writer.writerow({'layer': layer, 'cod': ''})
