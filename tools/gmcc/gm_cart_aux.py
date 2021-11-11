import os
import sys
import importlib

import json

from jsonschema import validate, ValidationError

wkb25bit = -2147483648
sys.path.append(os.path.join(os.path.dirname(
    os.path.realpath(__file__)), 'processing'))

# Dictionary of acceptable OGRwkbGeometryTypes and their string names.
OGRwkbGeomTypes = {
    0: 'Unknown', 1: 'Point', 2: 'LineString', 3: 'Polygon',
    4: 'MultiPoint', 5: 'MultiLineString', 6: 'MultiPolygon', 7: 'GeometryCollection',
    8: 'CircularString', 9: 'CompoundCurve', 10: 'CurvePolygon', 11: 'MultiCurve',
    12: 'MultiSurface', 13: 'Curve', 14: 'Surface', 15: 'PolyhedralSurface',
    16: 'TIN', 17: 'Triangle', 100: 'None', 101: 'LinearRing',
    1008: 'CircularStringZ', 1009: 'CompoundCurveZ', 1010: 'CurvePolygonZ', 1011: 'MultiCurveZ',
    1012: 'MultiSurfaceZ', 1013: 'CurveZ', 1014: 'SurfaceZ', 1015: 'PolyhedralSurfaceZ',
    1016: 'TINZ', 1017: 'TriangleZ', 2001: 'PointM', 2002: 'LineStringM',
    2003: 'PolygonM', 2004: 'MultiPointM', 2005: 'MultiLineStringM', 2006: 'MultiPolygonM',
    2007: 'GeometryCollectionM', 2008: 'CircularStringM', 2009: 'CompoundCurveM', 2010: 'CurvePolygonM',
    2011: 'MultiCurveM', 2012: 'MultiSurfaceM', 2013: 'CurveM', 2014: 'SurfaceM',
    2015: 'PolyhedralSurfaceM', 2016: 'TINM', 2017: 'TriangleM', 3001: 'PointZM',
    3002: 'LineStringZM', 3003: 'PolygonZM', 3004: 'MultiPointZM', 3005: 'MultiLineStringZM',
    3006: 'MultiPolygonZM', 3007: 'GeometryCollectionZM', 3008: 'CircularStringZM', 3009: 'CompoundCurveZM',
    3010: 'CurvePolygonZM', 3011: 'MultiCurveZM', 3012: 'MultiSurfaceZM', 3013: 'CurveZM',
    3014: 'SurfaceZM', 3015: 'PolyhedralSurfaceZM', 3016: 'TINZM', 3017: 'TriangleZM',
    1 + wkb25bit: 'Point25D', 2 + wkb25bit: 'LineString25D', 3 + wkb25bit: 'Polygon25D', 4 + wkb25bit: 'MultiPoint25D',
    5 + wkb25bit: 'MultiLineString25D', 6 + wkb25bit: 'MultiPolygon25D', 7 + wkb25bit: 'GeometryCollection25D'
}

FeatureTypes = {
    'Point': 'point',
    'LineString': 'line',
    'MultiLineString': 'line',
    'MultiLineString25D': 'line',
    'Polygon': 'polygon',

    'MultiPolygon': 'polygon',
    'MultiPolygon25D': 'polygon',

    'CircularString': 'circularstring',
    'CircularStringZ': 'circularstring',
    'CurvePolygon': 'curvepolygon',
    'CurvePolygonZ': 'curvepolygon',

    'Point25D': 'point',
    'LineString25D': 'line',
    'Polygon25D': 'polygon'
}

OGRFieldTypes = {
    0: 'Int', 1: 'List<Int>',
    2: 'Float', 3: 'List<Float>',
    4: 'String', 5: 'List<String>',
    6: 'WString', 7: 'List<WString>',
    8: 'Binary', 9: 'Date',
    10: 'Time', 11: 'Datetime',
    12: 'Int64', 13: 'List<Int64>'
}

base_pp = [
    ('edificio', {
        "type": "sql",
                "path": "processing/edificio_references.sql",
                "input_types": ["any"],
                "output_type": "any",
                "output_dim": "any"
    }),
    ('area_infra_trans_rodov', {
        "type": "sql",
                "path": "processing/area_infra_trans_rodov_references.sql",
                "input_types": ["any"],
                "output_type": "any",
                "output_dim": "any"
    }),
    ('infra_trans_rodov', {
        "type": "sql",
                "path": "processing/infra_trans_rodov_references.sql",
                "input_types": ["any"],
                "output_type": "any",
                "output_dim": "any"
    }),
    ('seg_via_rodov', {
        "type": "sql",
                "path": "processing/seg_via_rodov_references.sql",
                "input_types": ["any"],
                "output_type": "any",
                "output_dim": "any"
    }),
    ('equip_util_coletiva', {
        "type": "sql",
                "path": "processing/equip_util_coletiva_references.sql",
                "input_types": ["any"],
                "output_type": "any",
                "output_dim": "any"
    })
]


class Camada:
    def __init__(self, name, fields, constraints, geom_type='any', is_3D=True, remaining=False, save=True):
        self.name = name
        self.fields = fields
        self.constraints = constraints
        self.geom_type = geom_type

        self.geom_3D = is_3D
        self.remaining = remaining
        self.save = save

        self.elements = []

        self.atable = '_aux_'+name
        self.create_atable = False
        self.post_process = []

    def get_fields(self):
        return self.fields

    def add_field(self, field):
        field_exists = False

        for f in self.fields:
            if f['nome'] == field['nome']:
                field_exists = True

        if not field_exists:
            self.fields.append(field)

    def get_constraints(self):
        return self.constraints

    def get_elements(self):
        return self.elements

    def add_element(self, elem):
        self.elements.append(elem)

    def get_geom_type(self):
        return self.geom_type

    def is_remaining(self):
        return self.remaining

    def do_save(self):
        return self.save

    def is_3D(self):
        return self.geom_3D

    def add_post_process(self, pp, frst):
        if frst is True:
            self.post_process.insert(0, pp)
        else:
            self.post_process.append(pp)


def get_geom_type(type):
    result = 'any'
    if type == 'Geometria (ponto)':
        result = 'point'
    elif type == 'Geometria (linha)':
        result = 'line'
    elif type == 'Geometria (polígono)':
        result = 'polygon'
    elif type == 'Geometria (ponto; polígono)':
        result = 'pointpolygon'
    elif type == 'Geometria (linha; polígono)':
        result = 'linepolygon'
    elif type == 'Geometria (multipolígono)':
        result = 'multipolygon'
    else:
        print(
            '\t [Warning] Encontrado tipo de geometria não reconhecido \'' + type + '\'')

    return result


def read_post_process(base, lyr, schema, save_src, pp, frst):
    bp = os.path.dirname(os.path.realpath(__file__))
    try:
        # print(pp)
        if pp['type'] == 'sql':
            with open(bp + '/' + pp['path']) as pp_file:
                pp_src = pp_file.read()
                cols = [f['nome'] for f in base[lyr].get_fields(
                ) if f['nome'] != 'identificador' and f['nome'] != 'geometria']
                if ('import_ref' not in cols):
                    cols.append('import_ref')
                if save_src:
                    if ('import_mcod' not in cols):
                        cols.append('import_mcod')
                    if ('import_src' not in cols):
                        cols.append('import_src')
                npp = {
                    'type': 'sql',
                    'output_dim': pp['output_dim'],
                    'output_type': pp['output_type'],
                    'src': pp_src.format(dtable=schema+'.'+lyr,
                                         stable=schema+'.' +
                                         base[lyr].atable,
                                         schema=schema,
                                         cols=', '.join(
                                             cols + ['geometria']),
                                         geom='geometria',
                                         attr=', '.join(cols),
                                         t1attr=', '.join(['t1.'+c for c in cols]))
                }
                if 'op' in pp:
                    npp['op'] = pp['op']

                base[lyr].add_post_process(npp, frst)
        elif pp['type'] == 'python':
            base[lyr].add_post_process({
                'type': 'python',
                'output_dim': pp['output_dim'],
                'output_type': pp['output_type'],
                'src': importlib.import_module(pp['path'])
            }, frst)
    except Exception as e:
        print("Falhou leitura de pós-processamento.\n" + str(e))
        sys.exit(1)


def isListType(ftype):
    return ftype in [1, 3, 5, 7, 13]


def parse_ogr_list(ogr_list):
    result = ogr_list[1:-1].split(',')
    if len(result) > 0:
        result[0] = result[0][2:]
    # print(result)

    return result


def print_object_methods(obj):
    object_methods = [method_name for method_name in dir(obj)
                      if callable(getattr(obj, method_name))]
    print(object_methods)


def getProjection(proj):
    if not proj:
        return 'Unknown'
    else:
        return proj


def get_feat_type(feature):
    return FeatureTypes[OGRwkbGeomTypes[feature.GetGeometryRef().GetGeometryType()]]


def dataSource_tostring(data_source, layer_count):
    result = ''
    result += "\tProjeção:\t" + getProjection(data_source.GetProjection())
    result += "\n\tN.º Camadas:\t" + str(layer_count)

    return result


def layer_tostring(save_layer):
    result = ''
    result += '\t\tNome: ' + save_layer['nome']
    result += '\n\t\tGeometria: ' + save_layer['geometria']
    result += '\n\t\tElementos: ' + str(save_layer['elementos'])
    result += '\n\t\tCampos:'
    for field in save_layer['campos']:
        result += '\n\t\t\t' + field['nome'] + ' ( ' + field['tipo'] + ' )'

    return result


def validate_base_dict(json_obj):
    shema_dir = './schemas'
    if not os.path.isdir(shema_dir):
        print("Erro directório de schemas em falta.\n")
        sys.exit(1)

    try:
        with open(os.path.join(shema_dir, 'base_schema.json')) as schema_file:
            sch = json.load(schema_file)
            validate(json_obj, sch)
    except ValidationError as ve:
        print("Encontrado json de objecto base inválido.\n" + str(ve))
        sys.exit(1)
    except Exception as e:
        print("Falhou leitura de ficheiros configuração.\n" + str(e))
        sys.exit(1)


def validate_mapping_dict(json_obj):
    shema_dir = './schemas'
    if not os.path.isdir(shema_dir):
        print("Erro directório de schemas em falta.\n")
        sys.exit(1)

    try:
        with open(os.path.join(shema_dir, 'mapping_schema.json')) as schema_file:
            sch = json.load(schema_file)
            validate(json_obj, sch)
    except ValidationError as ve:
        print("Encontrado json de objecto mapping inválido.\n" + str(ve))
        sys.exit(1)
    except Exception as e:
        print("Falhou leitura de ficheiros configuração.\n" + str(e))
        sys.exit(1)
