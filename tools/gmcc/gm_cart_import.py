#!/usr/bin/python3
import os
import sys
import json
import re
import argparse

import gm_cart_aux as aux
from gm_cart_postgis import PostgisImporter

from osgeo import gdal
from osgeo import ogr


class CartImporter:
    """Importador de cartografia"""

    def __init__(self, map_dir, **kwargs):
        self.map_dir = map_dir

        self.base_dir = kwargs.get('base_dir', './base')

        self.input_dir = kwargs.get('input_dir', './input')
        self.ulink_type = kwargs.get('ulink_type', '6549')
        self.cod_field = kwargs.get('cod_field', 'ulink')
        self.alias_file = kwargs.get('alias', None)
        self.force_geom = kwargs.get('force_geom', False)
        self.force_polygon = kwargs.get('force_polygon', False)
        self.force_close = kwargs.get('force_close', False)

        self.print_elems = False

        self.base = {}
        self.mapping = {}
        self.alias = {}

        self.errors_processing = {'invalid': {}, 'missing_map': {}}
        self.feat_process = 0

        self.datasources = []
        self.layers = []

        os.environ["DGN_ULINK_TYPE"] = self.ulink_type
        self.valid_extensions = ['.dgn', '.top', '.shp', '.dwg']
        self.schema = kwargs.get('schema', 'import')
        self.save_src = True

        self.base_pp = aux.base_pp

        self.ndd = kwargs.get('ndd', 'ndd1')

        self.build_base()
        self.build_mapping()

    def read_conf(self):
        try:
            with open('./conf.json', encoding='utf-8') as conf_file:
                cfp = json.load(conf_file)
                if 'ndd' in cfp:
                    self.ndd = cfp['ndd']
                if 'save_src' in cfp:
                    self.save_src = cfp['save_src']
                if 'schema' in cfp:
                    self.schema = cfp['schema']
                if 'post-processing' in cfp:
                    for pp in cfp['post-processing']:
                        for lyr in pp['layers']:
                            if lyr in self.base:
                                if 'op' in pp:
                                    if pp['op'] == 'polygonize':
                                        pp["type"] = "sql"
                                        pp["path"] = "processing/polygonize.sql"
                                        pp["input_types"] = ["line"]
                                        pp["output_type"] = "polygon"
                                        pp["output_dim"] = "any"
                                    elif pp['op'] == 'to3D':
                                        pp["type"] = "python"
                                        pp["path"] = "to3D"
                                        pp["input_types"] = ["any"]
                                        pp["output_type"] = "any"
                                        pp["output_dim"] = "3D"
                                    elif pp['op'] == 'to2D':
                                        pp["type"] = "python"
                                        pp["path"] = "to2D"
                                        pp["input_types"] = ["any"]
                                        pp["output_type"] = "any"
                                        pp["output_dim"] = "2D"
                                aux.read_post_process(
                                    self.base, lyr, self.schema, self.save_src, pp, False)
            for lyr, pp_cfg in self.base_pp:
                if lyr in self.base or lyr == '_base':
                    aux.read_post_process(
                        self.base, lyr, self.schema, self.save_src, pp_cfg, False)
        except Exception as e:
            print("Falhou leitura do ficheiro de configuração.\n" + str(e))
            sys.exit(1)

    def pp_conf(self):
        for lyr, pp_cfg in self.base_pp:
            if lyr in self.base or lyr == '_base':
                aux.read_post_process(
                    self.base, lyr, self.schema, self.save_src, pp_cfg, False)

    def build_base(self):
        """Carregar ficheiros base"""

        if not os.path.isdir(self.base_dir):
            print("Argumento inválido. Input tem de ser uma diretoria.\n")
            sys.exit(1)

        base_files = [os.path.join(self.base_dir, f) for f in os.listdir(self.base_dir) if os.path.isfile(
            os.path.join(self.base_dir, f)) and f.lower().endswith('.json')]
        for bfile in base_files:
            try:
                if bfile.split('/')[-1] == 'relacoes.json':
                    continue
                with open(bfile, encoding='utf-8') as base_file:
                    bfp = json.load(base_file)
                    aux.validate_base_dict(bfp)

                    objecto = bfp['objecto']
                    ccname = re.sub(r'(?<!^)(?=[A-Z][a-z])|(?=[A-Z]{3,})',
                                    '_', objecto['objeto']).lower()

                    constraints = {}
                    campos = []
                    geom_type = 'any'
                    is_3D = False
                    is_3D = True if 'Dim' in objecto and objecto['Dim'].lower() == '3d' else is_3D
                    is_3D = True if 'Dim.' in objecto and objecto['Dim.'].lower() == '3d' else is_3D
                    for attr in objecto['Atributos']:
                        if attr['Atributo'] == 'geometria':
                            geom_type = aux.get_geom_type(attr['Tipo'])
                        if attr['Atributo'] == 'identificador' and attr['Tipo'] == 'UUID':
                            constraints['pkey'] = attr['Atributo']
                        attr['Atributo'] = re.sub(
                            r'iD', 'id', attr['Atributo'])
                        attr['Atributo'] = re.sub(
                            r'LAS', 'Las', attr['Atributo'])
                        attr['Atributo'] = re.sub(
                            r'valorElementoAssociadoPGQ', 'valor_elemento_associado_pgq', attr['Atributo'])
                        attr['Atributo'] = re.sub(
                            r'XY', 'Xy', attr['Atributo'])
                        attr['Atributo'] = re.sub(
                            r'datahomologacao', 'data_homologacao', attr['Atributo'])
                        attr['Atributo'] = re.sub(
                            r'nomeDoProdutor', 'nome_produtor', attr['Atributo'])
                        attr['Atributo'] = re.sub(
                            r'nomeDoProprietario', 'nome_proprietario', attr['Atributo'])
                        campos.append({
                            'nome': re.sub(r'(?<!^)(?=[A-Z])', '_', attr['Atributo']).lower(),
                            'tipo': attr['Tipo'],
                            'opcional': False if attr['D1'] == 'x' and attr['D2'] == 'x' else True
                        })
                    self.base[ccname] = aux.Camada(
                        ccname, campos, constraints, geom_type, is_3D)
            except Exception as e:
                print("Falhou leitura de ficheiros configuração.\n" + str(e))
                sys.exit(1)
        self.base['restantes'] = aux.Camada(
            'restantes', [], {}, 'any', False, True, False)

    def build_mapping(self):
        """Carregar ficheiros mapping"""

        if not os.path.isdir(self.map_dir):
            print("Argumento inválido. Input tem de ser uma diretoria.\n")
            sys.exit(1)

        map_files = [os.path.join(self.map_dir, f) for f in os.listdir(self.map_dir) if os.path.isfile(
            os.path.join(self.map_dir, f)) and f.lower().endswith('.json')]
        for mfile in map_files:
            try:
                with open(mfile) as map_file:
                    mfp = json.load(map_file)
                    aux.validate_mapping_dict(mfp)

                    cod = os.path.splitext(os.path.basename(mfile))[0]
                    self.mapping[cod] = mfp
            except Exception as e:
                print("Falhou leitura de ficheiro configuração '" +
                      mfile + "'.\n" + str(e))
                sys.exit(1)

        if self.alias_file is not None:
            try:
                with open(self.alias_file, encoding='utf-8') as alias_file:
                    self.alias = json.load(alias_file)
            except Exception as e:
                print("Falhou leitura de ficheiro de alias.\n" + str(e))
                sys.exit(1)

    def read_datasources(self, source_dir):
        """Ler ficheiros origem"""

        if not os.path.isdir(self.map_dir):
            print("Argumento inválido. Input tem de ser uma diretoria.\n")
            sys.exit(1)

        file_list = [os.path.join(source_dir, f) for f in os.listdir(source_dir) if os.path.isfile(
            os.path.join(source_dir, f)) and f[-4:].lower() in self.valid_extensions]

        if not len(file_list) > 0:
            print("Não foram encontrados ficheiros compativeis.")

        for fp in file_list:
            print("Iniciar leitura do ficheiro '" + fp + "'")
            data_source = gdal.OpenEx(fp, gdal.OF_VECTOR)
            if data_source is None:
                print("\t[Erro] Falhou leitura do ficheiro.\n\t\tVerifique que o ficheiro existe\
            e tem um formato de dados suportado.")
                sys.exit(1)

            #
            # Caracterizar fonte de dados
            #
            self.datasources.append(data_source)
            layer_count = data_source.GetLayerCount()
            print("Analisar Dataset")
            print(aux.dataSource_tostring(data_source, layer_count))

            if layer_count > 0:
                for li in range(layer_count):
                    layer = data_source.GetLayerByIndex(li)
                    layer.ResetReading()
                    # feat = layer.GetNextFeature()

                    fields = []
                    feat_defn = layer.GetLayerDefn()
                    for fi in range(feat_defn.GetFieldCount()):
                        field_defn = feat_defn.GetFieldDefn(fi)
                        fields.append({
                            'nome': field_defn.GetName(),
                            'tipo': aux.OGRFieldTypes[field_defn.GetType()]
                        })

                    if self.cod_field.lower() not in [f['nome'].lower() for f in fields]:
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
                    self.layers.append(save_layer)

                    print("\n\tAnalisar camada " + str(li+1))
                    print(aux.layer_tostring(save_layer))

    def process_data(self):
        """Processar camadas"""

        print("Processar Dataset")
        for layer in self.layers:
            layer['data'].ResetReading()
            for feature in layer['data']:
                if self.print_elems:
                    print(json.loads(feature.ExportToJson())['properties'])
                if feature.IsFieldSet(self.cod_field):
                    clink = feature.GetFieldAsString(self.cod_field)
                    clinkj = json.loads(clink)

                    clinks = []
                    if isinstance(clinkj, dict):
                        if self.ulink_type in clinkj:
                            for cl in clinkj[self.ulink_type]:
                                clinks.append(cl["key"].lstrip("0"))
                    else:
                        clinks.append(str(clinkj).lstrip("0"))

                    # if aux.isListType(feature.GetFieldType(self.cod_field)):
                    #     clinks = aux.parse_ogr_list(clink)
                    # else:
                    #     clinks = [clink]

                    for cod in clinks:
                        if self.alias_file is not None\
                                and cod in self.alias and self.alias[cod]:
                            cod = self.alias[cod]
                        if cod in self.mapping and 'map' in self.mapping[cod]:
                            dst_map = self.mapping[cod]['map']
                            for map_op in dst_map:
                                if 'table' in map_op and map_op['table']:
                                    self.base[map_op['table']].add_element(
                                        {'key': cod, 'data': feature, 'map_ops': map_op, 'src': layer['nome']})
                                else:
                                    self.base['restantes'].add_element(
                                        {'data': feature, 'src': layer['nome']})
                                    self.process_error(
                                        cod, 'invalid', 'Encontrado código com mapeamento inválido', feature)
                        else:
                            self.base['restantes'].add_element(
                                {'data': feature, 'src': layer['nome']})
                            self.process_error(
                                cod, 'missing_map', 'Encontrado código sem mapeamento', feature, True)

                        self.feat_process += 1

        print('Foram processadas ' + str(self.feat_process) + ' features')

    def persist_data(self, bp, pf):
        """Guardar dados"""

        print("Converter dados")
        if len(self.base['restantes'].get_elements()) > 0:
            rtypes = {}
            rcount = 1
            for f in self.base['restantes'].get_elements():
                fields = []
                for fi in range(f['data'].GetFieldCount()):
                    field_defn = f['data'].GetFieldDefnRef(fi)
                    fields.append(field_defn.GetName())

                if ','.join(fields) not in rtypes:
                    campos = [
                        {'nome': 'ogc_fid', 'tipo': 'serial', 'opcional': False}]
                    for c in fields:
                        campos.append(
                            {'nome': c, 'tipo': 'Texto2', 'opcional': True})
                    campos.append(
                        {'nome': 'wkb_geometry', 'tipo': 'geometry', 'opcional': True})

                    rtkey = ','.join(fields)
                    rtypes[rtkey] = {
                        'tableref': str(rcount),
                        'campos': campos,
                        'constraints': {'pkey': 'ogc_fid'}
                    }

                    self.base['_skipped' + str(rcount)] = aux.Camada('_skipped' + str(
                        rcount), rtypes[rtkey]['campos'], rtypes[rtkey]['constraints'], 'any', False, True)
                    rcount += 1
                else:
                    tr = rtypes[','.join(fields)]['tableref']
                    self.base['_skipped' + tr].add_element(f)

        self.base['_import_error'] = aux.Camada('_import_error', [
            {'nome': 'id', 'tipo': 'serial', 'opcional': False},
            {'nome': 'etype', 'tipo': 'Texto', 'opcional': True},
            {'nome': 'msg', 'tipo': 'Texto', 'opcional': True},
            {'nome': 'feature', 'tipo': 'Texto2', 'opcional': True},
            {'nome': 'import_mcod', 'tipo': 'json', 'opcional': True},
            {'nome': 'import_src', 'tipo': 'Texto', 'opcional': True},
            {'nome': 'import_dst', 'tipo': 'Texto', 'opcional': True},
            {'nome': 'wkb_geometry', 'tipo': 'geometry', 'opcional': True}],
            {'pkey': 'id'}, 'any', False, True
        )

        prst_handler = PostgisImporter(
            self.schema, self.base, self.mapping, self.cod_field, self.ndd, self.force_geom, self.force_polygon, self.force_close, self.save_src)

        prst_handler.save_datasource(os.path.join(bp, pf + '_features.sql'))
        prst_handler.save_post_processing(
            os.path.join(bp, pf + '_features.sql'))
        prst_handler.save_remaining(os.path.join(bp, pf + '_remaining.sql'))
        prst_handler.save_errors(os.path.join(bp, pf + '_errors.sql'))
        prst_handler.save_base(os.path.join(bp, pf + '_base.sql'))

        # prst_handler.solve_recart_referances('features.sql')

    def print_summary(self):
        print("A correr importação\n")
        print("\tDirectório objectos RECART: '" + self.base_dir + "'")
        print("\tDirectório ficheiros mapping: '" + self.map_dir + "'")
        print("\tDirectório ficheiros input: '" + self.input_dir + "'")
        print("\tCampo multi-códigos: '" + self.cod_field + "'")
        print("\tTipo de .dgn user link: '" + self.ulink_type + "'")
        print("\n")

    def print_err_report(self):
        for errtype in self.errors_processing:
            if len(self.errors_processing[errtype]) > 0:
                print('\n\tOcorreram ' + str(
                    len(self.errors_processing[errtype])) + ' erros do tipo \'' + errtype + '\'')
                for err in self.errors_processing[errtype]:
                    print('\t\t[Warning] ' + self.errors_processing[errtype][err]['msg'] +
                          '\n\t\t Ocorreu ' + str(self.errors_processing[errtype][err]['times']) + ' vezes')

    def print_import_report(self):
        if self.feat_process > 0:
            total = 0
            for lyr in self.base:
                lc = len(self.base[lyr].get_elements())
                if not self.base[lyr].is_remaining() and lc > 0:
                    total += lc
                    print("\tForam convertidas " + str(lc) +
                          ' features para a camada ' + lyr)
            print("\n\tTotal convertido: " + str(total) +
                  ' features ({:.2f}%)'.format((total*100)/self.feat_process))

            remaining = len(self.base['restantes'].get_elements())
            if remaining > 0:
                print("\t" + str(remaining) +
                      " features ficaram por converter ({:.2f}%)".format((remaining*100)/self.feat_process))

            errors = len(self.base['_import_error'].get_elements())
            if errors > 0:
                print("\t" + str(errors) +
                      " features resultaram em erro ({:.2f}%)".format((errors*100)/self.feat_process))

    def process_error(self, err_key, err_type, msg, feature, print_feature=False):
        error = msg + ': ' + err_key
        if err_key not in self.errors_processing[err_type]:
            if print_feature:
                error += '\n\t\t Vista 1ª vez na feature ' + \
                    str(json.loads(feature.ExportToJson())['properties'])
            self.errors_processing[err_type][err_key] = {
                'msg': error, 'times': 1}
        else:
            self.errors_processing[err_type][err_key]['times'] += 1


if __name__ == '__main__':
    kwargs = {}

    parser = argparse.ArgumentParser(
        description='Importador de cartografia para o modelo RECART')
    parser.add_argument(
        '-b', '--base', help='directório com ficheiros de objectos RECART')
    parser.add_argument(
        '-m', '--mapping', help='directório com ficheiros de mapeamento', required=True)
    parser.add_argument(
        '-i', '--input', help='directório com ficheiros para importação', required=True)
    parser.add_argument(
        '-t', '--tipo', help='identificador do tipo de user link no dgn')
    parser.add_argument('-cf', '--campo_cod', help='campo com multi-código')
    parser.add_argument(
        '-a', '--alias', help='ficheiros com alias para mapeamento')

    args = parser.parse_args()
    if args.base is not None:
        kwargs['base_dir'] = args.base
    if args.tipo is not None:
        kwargs['ulink_type'] = args.tipo
    if args.campo_cod is not None:
        kwargs['cod_field'] = args.campo_cod
    if args.alias is not None:
        kwargs['alias'] = args.alias

    ci = CartImporter(args.mapping, **kwargs)
    ci.read_conf()
    ci.print_summary()
    ci.read_datasources(args.input)

    ci.process_data()
    ci.print_err_report()

    nl = args.input.split(os.sep)
    prf = nl[-1] if nl[-1] or len(nl) < 2 else nl[-2]

    ci.persist_data(os.path.dirname(os.path.realpath(__file__)), prf)
    ci.print_import_report()
