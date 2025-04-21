import os
import re
import json

from . import gm_cart_aux as aux


class PostgisImporter:
    """Importador de cartografia"""

    def __init__(self, schema, base, mapping, cod_field, ndd, forceGeom, forcePolygon, forceClose, cellHeaderOrigin, use_layerName, save_src, writer, srsid, vrs):
        self.schema = schema
        self.base = base
        self.mapping = mapping
        self.cod_field = cod_field
        self.ndd = ndd
        self.forceGeom = forceGeom
        self.forcePolygon = forcePolygon
        self.cellHeaderOrigin = cellHeaderOrigin
        self.forceClose = forceClose
        self.writer = writer

        self.use_layerName = use_layerName
        self.srsid = srsid
        
        self.vrs = vrs

        self.save_src = save_src
        self.errors_processing = {
            'incompatible_geom': {}, 'conversion_error': {}}

    def print_err_report(self):
        for errtype in self.errors_processing:
            if len(self.errors_processing[errtype]) > 0:
                self.writer('\n\tOcorreram ' +
                            str(len(self.errors_processing[errtype])) + ' erros do tipo \'' + errtype + '\'')
                for err in self.errors_processing[errtype]:
                    self.writer('\t\t[Warning] ' + self.errors_processing[errtype][err]['msg'] +
                                '\n\t\t Ocorreu ' + str(self.errors_processing[errtype][err]['times']) + ' vezes')

    def get_field(self, nome, dtype, opcional, ignore_optional=False, geom_3D=True):
        result = ['\"' + nome + '\"']
        geom = 'geometry(GEOMETRYZ, ' + str(self.srsid) + ')' if geom_3D else 'geometry(GEOMETRY, ' + str(self.srsid) + ')'
        if dtype == 'UUID':
            result.append('uuid')
        elif dtype == 'ID':
            result.append('uuid')
        elif dtype == 'DataTempo':
            result.append('timestamp without time zone')
        elif dtype == 'Data/hora':
            result.append('timestamp without time zone')
        elif dtype == 'Data':
            result.append('date')
        elif dtype == 'Texto':
            result.append('varchar(255)')
        elif dtype == 'Texto2':
            result.append('varchar')
        elif dtype == 'Inteiro':
            result.append('int4')
        elif dtype == 'Real':
            result.append('real')
        elif dtype == 'Booleano':
            result.append('bool')
        elif dtype == 'Lista de códigos':
            result.append('varchar(255)')
        elif dtype == 'Geometria (ponto)':
            result.append(geom)
        elif dtype == 'Geometria (linha)':
            result.append(geom)
        elif dtype == 'Geometria (polígono)':
            result.append(geom)
        elif dtype == 'Geometria (ponto; polígono)':
            result.append(geom)
        elif dtype == 'Geometria (linha; polígono)':
            result.append(geom)
        elif dtype == 'Geometria (multipolígono)':
            result.append(geom)
        elif dtype == 'serial':
            result.append('serial not')
        elif dtype == 'smallint':
            result.append('smallint')
        elif dtype == 'geometry':
            result.append('geometry(GEOMETRYZ, ' + str(self.srsid) + ')')
        elif dtype == 'json':
            result.append('json')
        else:
            self.writer(
                '\t [Warning] Encontrado tipo de dados não reconhecido \'' + dtype + '\'')
            result.append('varchar(255)')

        if opcional or ignore_optional:
            result.append('null')
        else:
            result.append('not null')

        if dtype == 'UUID':
            result.append('default uuid_generate_v1mc()')

        return ' '.join(result)

    def get_constraint(self, tbname, ctype, field):
        result = ['constraint ' + tbname + '_' + ctype]
        if ctype == 'pkey':
            result.append('primary key('+field+')')

        return ' '.join(result)

    def process_geom_error(self, feat, errtype, msg):
        feat['err_type'] = errtype
        feat['err_msg'] = msg

        if errtype in self.errors_processing['conversion_error']:
            self.errors_processing['conversion_error'][errtype]['times'] += 1
        else:
            error = 'Erro de conversão.'
            error += '\n\t\t Vista 1ª vez na feature ' + \
                str(json.loads(feat['data'].ExportToJson())['properties'])
            self.errors_processing['conversion_error'][errtype] = {
                'msg': msg,
                'times': 1
            }
        return (None, False, {'type': errtype, 'msg': msg})

    def get_geom(self, layer, feature, enforce):
        is_3D = True if feature.GetGeometryRef().Is3D() != 0 else False
        geom_type = aux.FeatureTypes[
            aux.OGRwkbGeomTypes[feature.GetGeometryRef().GetGeometryType()]]

        if self.forceClose is True:
            feature.GetGeometryRef().CloseRings()

        geom = "'srid=" + str(self.srsid) + ";" + feature.GetGeometryRef().ExportToWkt() + "'"

        for pp in layer.post_process:
            if pp['type'] == 'python':
                geom = pp['src'].get_feature(feature)
            is_3D = (pp['output_dim'] ==
                     '3D') if pp['output_dim'] != 'any' else is_3D
            geom_type = pp['output_type'] if pp['output_type'] != 'any' else geom_type

        if not layer.create_atable and self.forcePolygon and geom_type.lower() == 'line' and 'polygon' in layer.geom_type.lower():
            aux.read_post_process(
                self.base, layer.name, self.schema, self.save_src,
                {
                    "op": "polygonize",
                    "type": "sql",
                    "path": "polygonize.sql",
                    "input_types": ["line"],
                    "output_type": "polygon",
                    "output_dim": "any"
                }, True)
            layer.create_atable = True

        auxtable = layer.create_atable

        if layer.create_atable and self.forcePolygon and geom_type.lower() == 'line' and 'polygon' in layer.geom_type.lower():
            auxtable = True
            geom_type = 'polygon'

        if feature.GetGeometryRef().IsEmpty():
            return (None, auxtable, {'type': 'Geometry type', 'msg': 'Geometry is empty'})

        if geom_type.lower() in layer.geom_type.lower() or not enforce:
            if self.forceGeom and layer.is_3D() and not is_3D\
                    and not layer.name.startswith('_skipped') and not layer.name.startswith('_import_error'):
                return "ST_Force3D(ST_GeomFromEWKT(" + geom + "))", auxtable, None
            elif self.forceGeom and not layer.is_3D() and is_3D\
                    and not layer.name.startswith('_skipped') and not layer.name.startswith('_import_error'):
                return "ST_Force2D(ST_GeomFromEWKT(" + geom + "))", auxtable, None
            elif is_3D == layer.is_3D() or not enforce:
                return geom, auxtable, None
            else:
                return (None, auxtable, {'type': 'Geometry dimensions', 'msg': 'Incompatible geometry dimensions'})
        else:
            return (None, auxtable, {'type': 'Geometry type', 'msg': 'Incompatible geometry type'})

    def get_feature(self, layer, fields, feature, cod=None, src=None, enforce=True, support_ref=True):
        result = ['(']

        auxtable = False
        out_fields = []
        for field in fields:
            if field['op'] == 'eq':
                if field['src'] == '1_geom':
                    if feature['data'].GetGeometryRef() is not None:
                        geom, auxtable, err = self.get_geom(
                            layer, feature['data'], enforce)

                        if geom is not None:
                            out_fields.append(geom)
                        else:
                            layer.elements.remove(feature)
                            return self.process_geom_error(feature, err['type'], err['msg'])
                    else:
                        return self.process_geom_error(feature, 'null_geom', 'Geometry is null')

                elif feature['data'].IsFieldSet(field['src']) and feature['data'].GetFieldType(field['src']) in [4, 6]:
                    out_fields.append('\'' + feature['data'].GetFieldAsBinary(
                        field['src']).decode('latin1').replace('\'', '\'\'') + '\'')

                elif feature['data'].IsFieldSet(field['src']) and feature['data'].GetFieldType(field['src']) in [1, 3, 5, 7, 13]:
                    out_fields.append(
                        '\'' + feature['data'].GetFieldAsString(field['src']) + '\'')

                else:
                    f = feature['data'].GetFieldAsString(
                        field['src']) if feature['data'].IsFieldSet(field['src']) else 'null'
                    out_fields.append(f)

            elif field['op'] == 'dropz':
                if field['src'] == '1_geom':
                    geom = feature['data'].GetGeometryRef()
                    geom.FlattenTo2D()
                    out_fields.append(
                        "'srid=" + str(self.srsid) + ";" + geom.ExportToWkt() + "'")

            elif field['op'] == 'addz':
                if field['src'] == '1_geom':
                    if feature['data'].GetGeometryRef() is None:
                        out_fields.append('null')
                    elif not feature['data'].GetGeometryRef().Is3D():
                        geom = feature['data'].GetGeometryRef()
                        out_fields.append(
                            "ST_Force3D(ST_GeomFromEWKT('srid=" + str(self.srsid) + ";" + geom.ExportToWkt() + "'))")
                    elif feature['data'].GetGeometryRef() is not None:
                        geom, auxtable, err = self.get_geom(
                            layer, feature['data'], enforce)

                        if geom is not None:
                            out_fields.append(geom)
                        else:
                            layer.elements.remove(feature)
                            return self.process_geom_error(feature, err['type'], err['msg'])

            elif field['op'] == 'getz':
                if field['src'] == '1_geom':
                    if feature['data'].GetGeometryRef().Is3D():
                        out_fields.append(
                            str(feature['data'].GetGeometryRef().GetZ()))
                    else:
                        if 'd3ds2d' in self.errors_processing['incompatible_geom']:
                            self.errors_processing['incompatible_geom']['d3ds2d']['times'] += 1
                        else:
                            error = 'Incompatibilidade de geometria. Pedido 3D no destino e origem é 2D.'
                            error += '\n\t\t Vista 1ª vez na feature ' + \
                                str(json.loads(feature['data'].ExportToJson())
                                    ['properties'])
                            self.errors_processing['incompatible_geom']['d3ds2d'] = {
                                'msg': error,
                                'times': 1
                            }

                        out_fields.append(str(-1))

            elif field['op'] == 'point_f':
                if field['src'] == '1_geom':
                    out_fields.append(
                        "'srid=" + str(self.srsid) + ";POINT " + str(feature['data'].GetGeometryRef().GetPoint()).replace(',', '') + "'")

            elif field['op'] == 'dnow':
                out_fields.append("now()")

            elif field['op'] == 'dset':
                format = field['value'] if 'format' in field else 'YYYY-MM-DD'
                out_fields.append(
                    "to_date('" + field['value'] + "', '" + format + "')")

            elif field['op'] == 'set':
                ftype = type(field['value'])
                if ftype == str:
                    out_fields.append('\'' + field['value'] + '\'')
                elif ftype == dict:
                    if self.ndd in field['value']:
                        out_fields.append('\'' + field['value'][self.ndd] + '\'')
                    else:
                        layer.elements.remove(feature)
                        return self.process_geom_error(feature, "NdD", "Feature not represented at this level of detail")
                elif ftype == list:
                    out_fields.append('\'' + ', '.join(field['value']) + '\'')
                else:
                    out_fields.append(str(field['value']))

        if cod is not None and 'references' in self.mapping[cod]['map'][0]:
            ref_json = self.mapping[cod]['map'][0]['references']
            nf = {}
            for m in ref_json:
                if type(m['fields']) == list:
                    for f in m['fields']:
                        if "value" in f:
                            ftype = type(f['value'])
                            if ftype == dict:
                                nf[f['dst']] = f['value'][self.ndd]
                            # if ftype == str:
                            #     nf[f['dst']] = f['value']
                            # elif ftype == dict:
                            #     nf[f['dst']] = f['value'][self.ndd]
                            # elif ftype == list:
                            #     nf[f['dst']] = str(f['value'])
                            # else:
                            #     nf[f['dst']] = str(f['value'])
                            else:
                                nf[f['dst']] = f['value']
                    m['fields'] = nf
            out_fields.append("'" + json.dumps(ref_json) + "'")
        elif support_ref:
            out_fields.append('null')

        if self.save_src:
            if cod:
                out_fields.append('\'' + cod + '\'')
            elif feature['data'].IsFieldSet(self.cod_field):
                val = feature['src'] if self.use_layerName else feature['data'].GetFieldAsString(self.cod_field)
                try:
                    clinkj = json.loads(val)
                    out_fields.append(
                        '\'' + val + '\'')
                except ValueError as e:
                    out_fields.append(
                        '\'{"cod": "' + val + '"}\'')
            if src:
                out_fields.append('\'' + src + '\'')

        result.append(', '.join(out_fields))
        result.append(')')

        return (' '.join(result), auxtable, None)

    def create_table(self, out_file, layer_name, layer, aux=False):
        out_file.write('create table ' + self.schema +
                       '.' + layer_name + '(\n')
        fields = []

        if self.save_src and not aux:
            layer.add_field({
                'nome': 'import_ref',
                'tipo': 'Texto',
                'opcional': True
            })
            layer.add_field({
                'nome': 'import_mcod',
                'tipo': 'Texto2',
                'opcional': True
            })
            layer.add_field({
                'nome': 'import_src',
                'tipo': 'Texto',
                'opcional': True
            })
        for field in layer.get_fields():
            fields.append(
                self.get_field(field['nome'], field['tipo'], field['opcional'], True, layer.is_3D()))
        out_file.write('\n, '.join(fields))

        constraints = []
        if len(layer.get_constraints()) > 0:
            constraints.append('')
        for constraint in layer.get_constraints():
            constraints.append(self.get_constraint(
                layer_name, constraint, layer.get_constraints()[constraint]))
        out_file.write('\n, '.join(constraints))

        out_file.write('\n);\n')

    def save_styles(self, path):
        bp = os.path.dirname(os.path.realpath(__file__))
        try:
            with open(path, "w", encoding='utf-8') as base_sql_file:
                with open(bp + '/processing/layer_styles.sql', encoding='utf-8') as pp_file:
                    pp_src = pp_file.read()
                    # base_sql_file.write(pp_src.format(schema=self.schema))
                    base_sql_file.write(
                        re.sub(r"{schema}", self.schema, pp_src))
        except Exception as e:
            self.writer(
                'Erro a guardar ficheiro de estilos: \'' + str(e) + '\'')

    def save_base(self, path, srsid):
        bp = os.path.dirname(os.path.realpath(__file__))
        try:
            with open(path, "w", encoding='utf-8') as base_sql_file:
                base_sql_file.write(
                    'create schema if not exists ' + self.schema + ';\n')
                base_sql_file.write(
                    'create extension if not exists "postgis";\n')
                base_sql_file.write(
                    'create extension if not exists "uuid-ossp";\n\n')

                for layer in self.base:
                    if layer == '_import_error':
                        self.create_table(base_sql_file, layer,
                                          self.base[layer], True)
                    elif len(self.base[layer].get_elements()) > 0 and self.base[layer].do_save():
                        self.create_table(
                            base_sql_file, layer, self.base[layer])
                        atable = False
                        for pp in self.base[layer].post_process:
                            if 'op' in pp and pp['op'] == 'polygonize':
                                atable = True

                        if atable or self.base[layer].create_atable:
                            self.create_table(
                                base_sql_file, self.base[layer].atable, self.base[layer], True)

                with open(bp + '/' + '/processing/' + self.vrs + '/_base_references.sql', encoding='utf-8') as pp_file:
                    pp_src = pp_file.read()
                    aux = re.sub(r"{schema}", self.schema, pp_src)
                    aux = re.sub(r", 3763", ', ' + str(srsid), aux)
                    base_sql_file.write( aux )

        except Exception as e:
            self.writer('Erro a guardar ficheiro base: \'' + str(e) + '\'')

    def save_datasource(self, path):
        try:
            with open(path, "w") as feat_sql_file:
                mss = {}
                for lyr_key in self.base:
                    lry = self.base[lyr_key]
                    if not lry.is_remaining():
                        for feature in lry.get_elements():
                            if feature['key'] in self.mapping and 'map' in self.mapping[feature['key']]:
                                map_ops = self.mapping[feature['key']]['map']
                                for op in map_ops:
                                    cols = [f['dst'] for f in op['fields']]
                                    cols_string = ', '.join(cols)
                                    if op['table'] in self.base:
                                        geom_type = aux.FeatureTypes[aux.OGRwkbGeomTypes[
                                            feature["data"].GetGeometryRef().GetGeometryType()]]
                                        insert_key = op['table'] + \
                                            cols_string+geom_type
                                        if insert_key not in mss:
                                            mss[insert_key] = {
                                                'layer': lry, 'table': op['table'], 'atable': lry.atable, 'cols': cols, 'elementos': []}
                                        mss[insert_key]['elementos'].append(
                                            feature)

                for mss_key in mss:
                    if len(mss[mss_key]['elementos']) > 0:
                        save_cols = mss[mss_key]['cols']
                        save_cols.append('import_ref')
                        if self.save_src:
                            save_cols.append('import_mcod')
                            save_cols.append('import_src')

                        first = True
                        for feat in mss[mss_key]['elementos']:
                            # print(feature)
                            # print(str(json.loads(feature['data'].ExportToJson())['properties']))
                            # print(feature['data'].GetFieldAsString('ulink'))
                            # print(feature['data'].GetGeometryRef().GetGeometryType())
                            # print(aux.OGRwkbGeomTypes[feature['data'].GetGeometryRef().GetGeometryType()])

                            auxtable = False
                            cfeat, auxtable, cerr = self.get_feature(
                                mss[mss_key]['layer'], feat['map_ops']['fields'], feat, feat['key'], feat['src'])

                            itable = mss[mss_key]['atable'] if auxtable else mss[mss_key]['table']
                            if cerr is None:
                                if not first:
                                    feat_sql_file.write(', ')
                                else:
                                    feat_sql_file.write(
                                        'insert into ' + self.schema + '.' + itable + '(' + ', '.join(save_cols) + ') values ')
                                    first = False
                                feat_sql_file.write(cfeat)
                                feat_sql_file.write('\n')
                            elif not feat['data'].GetGeometryRef().IsEmpty():
                                self.base['_import_error'].add_element(feat)
                            else:
                                print("Empty geometry")

                        feat_sql_file.write(';\n')
        except Exception as e:
            self.writer('Erro a guardar ficheiro \'' + path + '\': ' + str(e))

    def save_post_processing(self, path):
        bp = os.path.dirname(os.path.realpath(__file__))
        try:
            with open(path, "a") as feat_sql_file:
                for lyr in self.base:
                    if len(self.base[lyr].post_process) > 0:
                        for pp in self.base[lyr].post_process:
                            if pp['type'] == 'sql' and pp['src'] is not None:
                                feat_sql_file.write('\n\n')
                                feat_sql_file.write(pp['src'])

                with open(bp + '/' + '/processing/' + self.vrs + '/_cleanup.sql', encoding='utf-8') as pp_file:
                    pp_src = pp_file.read()
                    feat_sql_file.write( re.sub(r"{schema}", self.schema, pp_src) )
        except Exception as e:
            self.writer(
                'Erro a guardar ficheiro de features: \'' + str(e) + '\'')

    # def solve_recart_referances(self, base, path):
    #     for table in base.keys():
    #         if table not in ['restantes', '_import_error'] \
    #                 and not table.startswith('_skipped'):
    #             print(table)
    #     exit()

    def save_remaining(self, path):
        try:
            with open(path, "w", encoding='utf-8') as remaining_sql_file:
                for lyr in self.base:
                    if self.base[lyr].is_remaining() and self.base[lyr].do_save() and lyr != '_import_error':
                        fields = []
                        for f in self.base[lyr].get_fields():
                            if not f['nome'] in ['ogc_fid', 'wkb_geometry', 'import_mcod', 'import_src', 'import_ref']:
                                fields.append(
                                    {"src": f['nome'], "dst": '\"' + f['nome'] + '\"', "op": "eq"})
                        fields.append(
                            {"src": "1_geom", "dst": "wkb_geometry", "op": "addz"})
                        op = {"table": lyr, "fields": fields}

                        if not len(self.base[lyr].get_elements()) > 0:
                            break

                        cols = [f['dst'] for f in op['fields']]
                        if self.save_src:
                            cols.append('import_mcod')
                            cols.append('import_src')
                        first = True

                        for feature in self.base[lyr].get_elements():
                            # print(feature)
                            # print(str(json.loads(feature['data'].ExportToJson())['properties']))
                            # print(feature['data'].GetFieldAsString('ulink'))
                            # print(feature['data'].GetGeometryRef().GetGeometryType())
                            # print(aux.OGRwkbGeomTypes[feature['data'].GetGeometryRef().GetGeometryType()])

                            if feature['data'].GetGeometryRef().IsEmpty():
                                continue

                            if not first:
                                remaining_sql_file.write(', ')
                            else:
                                remaining_sql_file.write(
                                    'insert into ' + self.schema + '.' + op['table'] + '(' + ', '.join(cols) + ') values ')
                                first = False

                            if feature['data'].GetGeometryRef() is not None:
                                if aux.OGRwkbGeomTypes[feature['data'].GetGeometryRef().GetGeometryType()] in ['Polygon', 'Polygon25D']:
                                    feature['data'].GetGeometryRef(
                                    ).CloseRings()

                            cfeat, auxtable, cerr = self.get_feature(
                                self.base[lyr], op['fields'], feature, None, feature['src'], False, False)
                            if cerr is None:
                                remaining_sql_file.write(cfeat)
                                remaining_sql_file.write('\n')
                            else:
                                self.base['_import_error'].add_element(feature)
                        remaining_sql_file.write(';')
        except Exception as e:
            self.writer(
                'Erro a guardar ficheiro de remaining: \'' + str(e) + '\'')

    def save_errors(self, path):
        self.print_err_report()
        try:
            with open(path, "w", encoding='utf-8') as error_sql_file:
                first = True
                cols = [f['nome']
                        for f in self.base['_import_error'].get_fields() if f['nome'] != 'id']
                for f in self.base['_import_error'].get_elements():
                    out = []
                    if not first:
                        error_sql_file.write('\n, ')
                    else:
                        error_sql_file.write(
                            'insert into ' + self.schema + '._import_error' + '(' + ', '.join(cols) + ') values ')
                        first = False

                    out.append('\'' + f['err_type'] + '\'')
                    out.append('\'' + f['err_msg'] + '\'')
                    out.append(
                        '\'' + str(json.loads(f['data'].ExportToJson())['properties']).replace('\'', '\'\'') + '\'')
                    if f['data'].IsFieldSet(self.cod_field):
                        try:
                            val = f["src"] if self.use_layerName else f['data'].GetFieldAsString(self.cod_field)
                            clinkj = json.loads(val)
                            out.append(
                                '\'' + val + '\'')
                        except ValueError as e:
                            out.append(
                                '\'{"cod": "' + val + '"}\'')
                    else:
                        out.append('\'\'')
                    out.append('\'' + f['src'] + '\'')
                    out.append('\'' + f['map_ops']['table'] + '\'')
                    if f['data'].GetGeometryRef() is not None:
                        out.append("ST_Force3D(ST_GeomFromEWKT('srid=" + str(self.srsid) + ";" +
                                   f['data'].GetGeometryRef().ExportToWkt() + "'))")
                    else:
                        out.append('null')

                    error_sql_file.write('(')
                    error_sql_file.write(', '.join(out))
                    error_sql_file.write(')')
                if not first:
                    error_sql_file.write(';')
        except Exception as e:
            self.writer('Erro a guardar ficheiro de erros: \'' + str(e) + '\'')
