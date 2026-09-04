# -*- coding: utf-8 -*-
"""Build and embed a Recart QGIS project inside an exported GeoPackage."""

import os
import re
import sqlite3

from qgis.PyQt.QtXml import QDomDocument
from qgis.core import (
    QgsCoordinateReferenceSystem,
    QgsDataProvider,
    QgsEditorWidgetSetup,
    QgsLayerTreeGroup,
    QgsLayerTreeLayer,
    QgsProject,
    QgsRelation,
    QgsVectorLayer,
    QgsVectorLayerJoinInfo,
)

from .aux_export import displayList, form_nullable_fields, joins, recartStructure

PROJECT_NAME = 'Recart'
LABEL_VIEWS = (
    'ls_edificio_label_view',
    'ls_areas_artificializadas_label_view',
    'ls_seg_via_rodov_label_view',
    'ls_seg_via_ferrea_label_view',
)


def copy_layer_as_attributes(src_layer, dest_ds, dest_name, log_cb=None):
    """Copy an OGR layer into dest_ds as a geometryless attribute table."""
    from osgeo import ogr

    def log(msg):
        if log_cb:
            log_cb(msg)

    if src_layer is None or dest_ds is None:
        log("[Aviso] copy_layer_as_attributes: camada ou dataset em falta")
        return False

    src_defn = src_layer.GetLayerDefn()
    dst_layer = dest_ds.CreateLayer(
        dest_name, geom_type=ogr.wkbNone, options=['SPATIAL_INDEX=NO'])
    if dst_layer is None:
        log("[Aviso] Falha a criar tabela de atributos '{}'".format(dest_name))
        return False

    for i in range(src_defn.GetFieldCount()):
        if dst_layer.CreateField(src_defn.GetFieldDefn(i)) != 0:
            log("[Aviso] Falha a criar campo em '{}': {}".format(
                dest_name, src_defn.GetFieldDefn(i).GetName()))
            return False

    dst_defn = dst_layer.GetLayerDefn()
    src_layer.ResetReading()
    try:
        for feat in src_layer:
            if feat is None:
                continue
            new_feat = ogr.Feature(dst_defn)
            new_feat.SetFrom(feat, True)
            if new_feat.GetGeometryRef() is not None:
                new_feat.SetGeometry(None)
            err = dst_layer.CreateFeature(new_feat)
            new_feat = None
            if err != 0:
                log("[Aviso] Falha a copiar feature para '{}'".format(dest_name))
                return False
    except Exception as e:
        log("[Aviso] Falha a copiar '{}' como tabela de atributos: {}".format(
            dest_name, e))
        return False

    return True


_INSERT_HEADER = re.compile(
    r"INSERT INTO public\.layer_styles \( f_table_catalog, f_table_schema, "
    r"f_table_name, f_geometry_column, stylename, styleqml, stylesld, "
    r"useasdefault, description, type\) VALUES \( current_database\(\), "
    r"'\{schema\}', '([^']+)', '([^']+)', '((?:''|[^'])*)', '",
)

_GEOM_SUFFIX = re.compile(
    r'\((POINT|POLYGON|LINESTRING|MULTIPOINT|MULTIPOLYGON|MULTILINESTRING)Z?\)$',
    re.IGNORECASE,
)

_RECART_TO_OGR_GEOM = {
    'POINT': 'Point',
    'POINTZ': 'Point',
    'MULTIPOINT': 'MultiPoint',
    'MULTIPOINTZ': 'MultiPoint',
    'LINESTRING': 'LineString',
    'LINESTRINGZ': 'LineString',
    'MULTILINESTRING': 'MultiLineString',
    'MULTILINESTRINGZ': 'MultiLineString',
    'POLYGON': 'Polygon',
    'POLYGONZ': 'Polygon',
    'MULTIPOLYGON': 'MultiPolygon',
    'MULTIPOLYGONZ': 'MultiPolygon',
}


def _read_sql_string(text, i):
    """Read a SQL single-quoted string starting at index i; return (value, next_index)."""
    if i >= len(text) or text[i] != "'":
        raise ValueError('Expected opening quote for SQL string')
    i += 1
    out = []
    while i < len(text):
        ch = text[i]
        if ch == "'":
            if i + 1 < len(text) and text[i + 1] == "'":
                out.append("'")
                i += 2
            else:
                return ''.join(out), i + 1
        else:
            out.append(ch)
            i += 1
    raise ValueError('Unterminated SQL string')


def _geom_type_from_stylename(stylename):
    match = _GEOM_SUFFIX.search(stylename or '')
    if not match:
        return None
    return match.group(1).upper()


def load_styles_from_sql(vrs, plugin_dir=None):
    """Parse layer_styles.sql into {(table, geom_type_or_None): qml_string}."""
    if plugin_dir is None:
        plugin_dir = os.path.dirname(os.path.realpath(__file__))
    path = os.path.join(plugin_dir, 'convert', 'processing', vrs, 'layer_styles.sql')
    styles = {}
    if not os.path.isfile(path):
        return styles

    text = open(path, encoding='utf-8').read()
    for match in _INSERT_HEADER.finditer(text):
        table = match.group(1)
        stylename = match.group(3).replace("''", "'")
        qml_start = match.end() - 1
        try:
            qml, _ = _read_sql_string(text, qml_start)
        except ValueError:
            continue
        geom_type = _geom_type_from_stylename(stylename)
        styles[(table, geom_type)] = qml
        if geom_type is None and (table, None) not in styles:
            styles[(table, None)] = qml
    return styles


def _quote_ident(name):
    return '"' + str(name).replace('"', '""') + '"'


def _gpkg_table_names(conn):
    rows = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    ).fetchall()
    return {r[0] for r in rows}


def _rebuild_gpkg_table_with_fks(conn, table, fk_defs):
    """
    Recreate a GPKG table including FOREIGN KEY clauses.

    GDAL's AddRelationship only supports many-to-many (Related Tables Extension).
    One-to-many relations that QGIS discoverRelations finds come from SQLite FKs.
    """
    row = conn.execute(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name=?", (table,)
    ).fetchone()
    if not row or not row[0]:
        raise ValueError("Tabela '{}' sem CREATE TABLE".format(table))
    create_sql = row[0].rstrip()
    if not create_sql.endswith(')'):
        raise ValueError("CREATE TABLE inesperado para '{}'".format(table))

    cols = [r[1] for r in conn.execute(
        'PRAGMA table_info({})'.format(_quote_ident(table)))]
    if not cols:
        raise ValueError("Tabela '{}' sem colunas".format(table))

    fk_clauses = []
    for src_cols, dst_table, dst_cols in fk_defs:
        fk_clauses.append(
            'FOREIGN KEY({src}) REFERENCES {dst}({ref})'.format(
                src=','.join(_quote_ident(c) for c in src_cols),
                dst=_quote_ident(dst_table),
                ref=','.join(_quote_ident(c) for c in dst_cols),
            )
        )

    new_create = create_sql[:-1] + ', ' + ', '.join(fk_clauses) + ')'
    tmp = table + '__fknew'
    new_create = re.sub(
        r'CREATE TABLE\s+("?){0}\1'.format(re.escape(table)),
        'CREATE TABLE {0}'.format(_quote_ident(tmp)),
        new_create,
        count=1,
        flags=re.IGNORECASE,
    )

    # Export uses SPATIAL_INDEX=NO, so no rtree housekeeping is needed here.
    # Triggers/indexes on the feature table are removed with DROP TABLE.
    conn.execute(new_create)
    col_list = ', '.join(_quote_ident(c) for c in cols)
    conn.execute(
        'INSERT INTO {tmp} ({cols}) SELECT {cols} FROM {tbl}'.format(
            tmp=_quote_ident(tmp), cols=col_list, tbl=_quote_ident(table))
    )
    conn.execute('DROP TABLE {}'.format(_quote_ident(table)))
    conn.execute(
        'ALTER TABLE {} RENAME TO {}'.format(_quote_ident(tmp), _quote_ident(table))
    )


def create_gpkg_spatial_indexes(gpkg_path, log_cb=None):
    """Create spatial indexes for all geometry layers (after FK rebuild)."""
    from osgeo import gdal

    def log(msg):
        if log_cb:
            log_cb(msg)

    gdal.UseExceptions()
    ds = None
    created = 0
    try:
        conn = sqlite3.connect(gpkg_path)
        try:
            layers = conn.execute(
                'SELECT table_name, column_name FROM gpkg_geometry_columns'
            ).fetchall()
        finally:
            conn.close()

        if not layers:
            return 0

        ds = gdal.OpenEx(gpkg_path, gdal.OF_VECTOR | gdal.OF_UPDATE)
        for table, geom_col in layers:
            try:
                ds.ExecuteSQL(
                    'SELECT CreateSpatialIndex({t}, {g})'.format(
                        t=_quote_ident(table), g=_quote_ident(geom_col))
                )
                created += 1
            except Exception as e:
                log("[Aviso] CreateSpatialIndex em '{}': {}".format(table, e))
        log('[Sucesso] {} índices espaciais criados no GeoPackage'.format(created))
    except Exception as e:
        log('[Aviso] Falha a criar índices espaciais: {}'.format(e))
    finally:
        ds = None
    return created


def write_gpkg_relationships(gpkg_path, relationships, log_cb=None):
    """
    Persist PostgreSQL foreign keys into the GeoPackage as SQLite FKs.

    relationships: iterable of dicts with src_table, src_cols, dst_table, dst_cols, name

    Expects layers to have been copied with SPATIAL_INDEX=NO; call
    create_gpkg_spatial_indexes() afterward.
    """
    from osgeo import gdal

    def log(msg):
        if log_cb:
            log_cb(msg)

    if not relationships:
        log('[Aviso] Sem foreign keys PostgreSQL para gravar no GeoPackage')
        return 0

    # Group FKs by referencing table (one rebuild per table)
    by_src = {}
    for rel in relationships:
        src = rel['src_table']
        dst = rel['dst_table']
        by_src.setdefault(src, []).append(
            (list(rel['src_cols']), dst, list(rel['dst_cols']), rel.get('name') or '')
        )

    conn = sqlite3.connect(gpkg_path, timeout=60)
    try:
        conn.execute('PRAGMA foreign_keys=OFF')
        tables = _gpkg_table_names(conn)
        rebuilt = 0
        skipped = 0
        for src_table, fks in sorted(by_src.items()):
            if src_table not in tables:
                skipped += len(fks)
                continue
            fk_defs = []
            for src_cols, dst_table, dst_cols, _name in fks:
                if dst_table not in tables:
                    skipped += 1
                    continue
                fk_defs.append((src_cols, dst_table, dst_cols))
            if not fk_defs:
                continue
            try:
                conn.execute('BEGIN')
                _rebuild_gpkg_table_with_fks(conn, src_table, fk_defs)
                conn.commit()
                rebuilt += len(fk_defs)
            except Exception as e:
                conn.rollback()
                log("[Aviso] Falha a gravar FKs em '{}': {}".format(src_table, e))
    finally:
        conn.close()

    try:
        ds = gdal.OpenEx(gpkg_path)
        names = (ds.GetRelationshipNames() or []) if ds is not None else []
        ds = None
        log('[Sucesso] {} foreign keys aplicadas no GeoPackage '
            '({} relações GDAL reportadas)'.format(rebuilt, len(names)))
        if skipped:
            log('[Aviso] {} foreign keys ignoradas (tabela em falta no GPKG)'.format(skipped))
    except Exception as e:
        log('[Aviso] Não foi possível listar relações GPKG: {}'.format(e))

    return rebuilt


def ogr_geometrytype(recart_geom):
    if not recart_geom:
        return None
    return _RECART_TO_OGR_GEOM.get(recart_geom.upper(), recart_geom.capitalize())


def gpkg_layer_uri(gpkg_path, table, recart_geom=None):
    uri = '{0}|layername={1}'.format(gpkg_path, table)
    ogr_type = ogr_geometrytype(recart_geom)
    if ogr_type:
        uri += '|geometrytype={0}'.format(ogr_type)
    return uri


def _apply_style(layer, table, recart_geom, styles, log_cb):
    key = (table, None)
    if recart_geom:
        base = re.sub(r'Z$', '', recart_geom.upper())
        if (table, base) in styles:
            key = (table, base)
        elif (table, recart_geom.upper()) in styles:
            key = (table, recart_geom.upper())
    qml = styles.get(key) or styles.get((table, None))
    if not qml:
        return
    doc = QDomDocument()
    if not doc.setContent(qml):
        if log_cb:
            log_cb("[Aviso] QML inválido para camada '{}'".format(table))
        return
    # QGIS versions differ: (bool, str) or (str, bool). Detect by type.
    result = layer.importNamedStyle(doc)
    ok = True
    err = ''
    if isinstance(result, tuple) and len(result) >= 2:
        if isinstance(result[0], bool):
            ok, err = result[0], result[1]
        elif isinstance(result[1], bool):
            err, ok = result[0], result[1]
    elif isinstance(result, bool):
        ok = result
    if not ok and log_cb:
        log_cb("[Aviso] Falha a aplicar estilo em '{}': {}".format(table, err))


def _ensure_group(parent, name, index):
    existing = parent.findGroup(name)
    if existing:
        return existing
    pos = min(max(index, 0), len(parent.children()))
    return parent.insertGroup(pos, name)


def _add_layer(project, parent_group, group_name, group_index, layer):
    tree_group = _ensure_group(parent_group, group_name, group_index)
    project.addMapLayer(layer, False)
    tree_group.addLayer(layer)
    return layer


def _configure_relation_widget(rel):
    layer = rel.referencingLayer()
    fields = layer.fields()
    ref_fields = rel.referencingFields()
    if not ref_fields:
        return
    field = fields[ref_fields[0]]
    field_idx = fields.indexOf(field.name())
    config = {
        'Relation': rel.id(),
        'ShowOpenFormButton': False,
    }
    if field.name() not in form_nullable_fields:
        config['AllowNULL'] = False
    else:
        allow = False
        for token in form_nullable_fields[field.name()]:
            if (
                token in rel.referencedLayer().name()
                or token in rel.referencingLayer().name()
                or token == '*'
            ):
                allow = True
                break
        config['AllowNULL'] = allow
    layer.setEditorWidgetSetup(field_idx, QgsEditorWidgetSetup('RelationReference', config))


def _layers_by_source_table(project):
    """Map GPKG layername -> list of QgsVectorLayer in the project."""
    by_table = {}
    for layer in project.mapLayers().values():
        if not isinstance(layer, QgsVectorLayer):
            continue
        source = layer.source()
        table = None
        for pattern in (
            r'layername=([^|&]+)',
            r"table=(?:'|\")?([^|'\"&]+)",
            r'\.gpkg[:|]([^|&]+)$',
        ):
            match = re.search(pattern, source, flags=re.IGNORECASE)
            if match:
                table = match.group(1).strip().strip('"').strip("'")
                break
        if not table:
            # Provider sometimes only exposes layerid — fall back to layer name
            # when it matches a bare table id (aux tables use table as title)
            table = layer.name()
        by_table.setdefault(table, []).append(layer)
    return by_table


def _new_relation(project):
    """Create a QgsRelation bound to project (not QgsProject.instance())."""
    try:
        from qgis.core import QgsRelationContext
        return QgsRelation(QgsRelationContext(project))
    except Exception:
        return QgsRelation()


def _create_ref_relations(project, vrs, log_cb):
    """Create valor_* relations from recartStructure when discoverRelations finds none."""
    manager = project.relationManager()
    structure = recartStructure.get(vrs, {})
    by_table = _layers_by_source_table(project)
    created = 0

    for table, conf in structure.items():
        refs = conf.get('refs') or []
        if not refs or table not in by_table:
            continue
        for referencing in by_table[table]:
            fields = referencing.fields()
            for ref_table in refs:
                if ref_table not in by_table:
                    continue
                fk = ref_table
                if fields.indexOf(fk) < 0:
                    fk_alt = ref_table + '_id'
                    if fields.indexOf(fk_alt) < 0:
                        continue
                    fk = fk_alt
                referenced = by_table[ref_table][0]
                if referenced.fields().indexOf('identificador') < 0:
                    continue
                dup = False
                for rel in manager.relations().values():
                    if (
                        rel.referencingLayerId() == referencing.id()
                        and rel.referencedLayerId() == referenced.id()
                        and rel.referencingFields()
                        and fields[rel.referencingFields()[0]].name() == fk
                    ):
                        dup = True
                        break
                if dup:
                    continue
                rel = _new_relation(project)
                rel_id = 'recart_{0}_{1}_{2}'.format(
                    table, fk, referencing.id().replace('{', '').replace('}', '')[:8])
                rel.setId(rel_id)
                rel.setName('{0}_{1}'.format(table, ref_table))
                rel.setReferencingLayer(referencing.id())
                rel.setReferencedLayer(referenced.id())
                rel.addFieldPair(fk, 'identificador')
                try:
                    rel.setStrength(QgsRelation.Association)
                except Exception:
                    pass
                if not rel.isValid():
                    continue
                manager.addRelation(rel)
                _configure_relation_widget(rel)
                created += 1

    if log_cb:
        log_cb('Relações Recart criadas a partir da estrutura: {}'.format(created))
    return created


def _apply_gdal_relationships(project, gpkg_path, log_cb=None):
    """
    Create QgsRelations from GDAL-reported GPKG relationships.

    QGIS discoverRelations often returns nothing for OGR layers opened with
    geometrytype filters, even when Dataset.GetRelationshipNames() is populated
    from SQLite FOREIGN KEYs. Map them explicitly instead.

    GDAL reports FK-backed relations as ONE_TO_MANY with:
      left  = referenced/parent (PK table)
      right = referencing/child (FK table)
    """
    from osgeo import gdal

    def log(msg):
        if log_cb:
            log_cb(msg)

    by_table = _layers_by_source_table(project)
    manager = project.relationManager()
    created = 0
    skip_reasons = {
        'missing_layer': 0,
        'bad_fields': 0,
        'many_to_many': 0,
        'invalid_relation': 0,
        'invalid_layer': 0,
    }
    ds_rel_defs = []

    ds = None
    try:
        ds = gdal.OpenEx(gpkg_path)
        for name in list(ds.GetRelationshipNames() or []):
            try:
                grel = ds.GetRelationship(name)
                ds_rel_defs.append({
                    'name': name,
                    'left': grel.GetLeftTableName(),
                    'right': grel.GetRightTableName(),
                    'left_fields': list(grel.GetLeftTableFields() or []),
                    'right_fields': list(grel.GetRightTableFields() or []),
                    'cardinality': grel.GetCardinality(),
                })
            except Exception:
                continue
    except Exception as e:
        log('[Aviso] Não foi possível ler relações GDAL do GPKG: {}'.format(e))
        return 0
    finally:
        ds = None

    log('Camadas no projeto (por tabela GPKG): {}'.format(len(by_table)))

    for defn in ds_rel_defs:
        left = defn['left']
        right = defn['right']
        left_fields = defn['left_fields']
        right_fields = defn['right_fields']
        if not left_fields or not right_fields or len(left_fields) != len(right_fields):
            skip_reasons['bad_fields'] += 1
            continue
        if left not in by_table or right not in by_table:
            skip_reasons['missing_layer'] += 1
            continue
        if defn['cardinality'] == gdal.GRC_MANY_TO_MANY:
            skip_reasons['many_to_many'] += 1
            continue

        for referencing in by_table[right]:
            for referenced in by_table[left]:
                if not referencing.isValid() or not referenced.isValid():
                    skip_reasons['invalid_layer'] += 1
                    continue
                refing_fields = referencing.fields()
                refed_fields = referenced.fields()
                if any(refing_fields.indexOf(f) < 0 for f in right_fields):
                    skip_reasons['bad_fields'] += 1
                    continue
                if any(refed_fields.indexOf(f) < 0 for f in left_fields):
                    skip_reasons['bad_fields'] += 1
                    continue

                dup = False
                for existing in manager.relations().values():
                    if (
                        existing.referencingLayerId() == referencing.id()
                        and existing.referencedLayerId() == referenced.id()
                        and existing.referencingFields()
                        and refing_fields[existing.referencingFields()[0]].name()
                        == right_fields[0]
                    ):
                        dup = True
                        break
                if dup:
                    continue

                rel = _new_relation(project)
                rel_id = 'gpkg_{0}_{1}'.format(
                    defn['name'],
                    referencing.id().replace('{', '').replace('}', '')[:8],
                )
                rel.setId(rel_id)
                rel.setName(defn['name'])
                rel.setReferencingLayer(referencing.id())
                rel.setReferencedLayer(referenced.id())
                for child_field, parent_field in zip(right_fields, left_fields):
                    rel.addFieldPair(child_field, parent_field)
                try:
                    rel.setStrength(QgsRelation.Association)
                except Exception:
                    pass
                if not rel.isValid():
                    skip_reasons['invalid_relation'] += 1
                    continue
                manager.addRelation(rel)
                _configure_relation_widget(rel)
                created += 1

    skipped = sum(skip_reasons.values())
    log('Relações GDAL aplicadas ao projeto: {} (ignoradas: {})'.format(
        created, skipped))
    if skipped and created == 0:
        log('Motivos: {}'.format(
            ', '.join('{}={}'.format(k, v) for k, v in skip_reasons.items() if v)))
    return created


def _apply_discovered_relations(project, log_cb):
    manager = project.relationManager()
    relations = manager.relations()
    layers = project.mapLayers()
    try:
        rels = manager.discoverRelations(list(relations.values()), list(layers.values()))
    except Exception as e:
        if log_cb:
            log_cb('[Aviso] discoverRelations falhou: {}'.format(e))
        rels = []
    if log_cb:
        log_cb('Relações descobertas: {}'.format(len(rels)))

    rel_names = {}
    for rel in rels:
        if rel.name() in rel_names:
            rel_names[rel.name()] += 1
            rel.setName(rel.name() + '_' + str(rel_names[rel.name()]))
        else:
            rel_names[rel.name()] = 0
        manager.addRelation(rel)
        _configure_relation_widget(rel)


def _apply_joins(project, log_cb):
    for layer_name, conf in joins.items():
        targets = project.mapLayersByName(layer_name)
        if not targets:
            continue
        join_layers = project.mapLayersByName(conf['join_table'])
        if not join_layers:
            if log_cb:
                log_cb("[Aviso] Tabela de join '{}' em falta para '{}'".format(
                    conf['join_table'], layer_name))
            continue
        jo = QgsVectorLayerJoinInfo()
        jo.setJoinLayer(join_layers[0])
        jo.setJoinFieldName(conf['join_field'])
        jo.setTargetFieldName(conf['target_field'])
        jo.setJoinFieldNamesSubset(conf['joined_fields'])
        jo.setUsingMemoryCache(conf['memory_cache'])
        jo.setPrefix(conf['prefix'])
        targets[0].addJoin(jo)


def _set_feature_counts(root):
    for child in root.children():
        if isinstance(child, QgsLayerTreeGroup):
            _set_feature_counts(child)
        elif isinstance(child, QgsLayerTreeLayer):
            child.setCustomProperty('showFeatureCount', True)


def _gpkg_has_layer(gpkg_path, table):
    layer = QgsVectorLayer(gpkg_layer_uri(gpkg_path, table), table, 'ogr')
    return layer.isValid()


def build_and_embed_recart_project(gpkg_path, layer_list, vrs, srsid, log_cb=None,
                                   exported_tables=None):
    """
    Build a temporary QgsProject from GPKG layers and embed it as project 'Recart'.

    Does not modify QgsProject.instance().
    """
    def log(msg):
        if log_cb:
            log_cb(msg)

    gpkg_path = os.path.abspath(gpkg_path)
    if not os.path.isfile(gpkg_path):
        log("[Erro] GeoPackage não encontrado: {}".format(gpkg_path))
        return False

    styles = load_styles_from_sql(vrs)

    project = QgsProject()
    try:
        try:
            crs = QgsCoordinateReferenceSystem.fromEpsgId(int(srsid))
        except Exception:
            crs = QgsCoordinateReferenceSystem('EPSG:{}'.format(srsid))
        if crs.isValid():
            project.setCrs(crs)

        root = project.layerTreeRoot()
        dgt_group = root.addGroup('DGT Recart')

        exported = set(exported_tables or [])
        added_tables = set()
        missing_labels = []

        for slayer in layer_list:
            if slayer not in displayList:
                continue
            meta = displayList[slayer]
            geoms = meta.get('geom') or []
            if geoms:
                for gt in geoms:
                    title = meta['alias'] if len(geoms) == 1 else '{} ({})'.format(
                        meta['alias'], gt)
                    uri = gpkg_layer_uri(gpkg_path, slayer, gt)
                    layer = QgsVectorLayer(uri, title, 'ogr')
                    if not layer.isValid():
                        # Fallback without geometry filter (single-type layers)
                        layer = QgsVectorLayer(
                            gpkg_layer_uri(gpkg_path, slayer), title, 'ogr')
                    if not layer.isValid():
                        log("[Aviso] Camada inválida no GPKG: {} ({})".format(slayer, gt))
                        continue
                    _apply_style(layer, slayer, gt, styles, log)
                    _add_layer(project, dgt_group, meta['name'], meta['index'], layer)
            else:
                uri = gpkg_layer_uri(gpkg_path, slayer)
                layer = QgsVectorLayer(uri, meta['alias'], 'ogr')
                if not layer.isValid():
                    log("[Aviso] Camada inválida no GPKG: {}".format(slayer))
                    continue
                _apply_style(layer, slayer, None, styles, log)
                _add_layer(project, dgt_group, meta['name'], meta['index'], layer)

            added_tables.add(slayer)

        # Remaining exported tables (refs/ligs/valores) under Tabelas Auxiliares
        aux_group_index = 0
        for table in sorted(exported):
            if table in added_tables:
                continue
            if table in layer_list and table in displayList:
                continue
            if not _gpkg_has_layer(gpkg_path, table):
                continue
            layer = QgsVectorLayer(gpkg_layer_uri(gpkg_path, table), table, 'ogr')
            if not layer.isValid():
                continue
            _add_layer(project, dgt_group, 'Tabelas Auxiliares', aux_group_index, layer)
            added_tables.add(table)

        for view in LABEL_VIEWS:
            if view in added_tables:
                continue
            if not _gpkg_has_layer(gpkg_path, view):
                missing_labels.append(view)
                continue
            layer = QgsVectorLayer(gpkg_layer_uri(gpkg_path, view), view, 'ogr')
            if not layer.isValid():
                missing_labels.append(view)
                continue
            _add_layer(project, dgt_group, 'Tabelas Auxiliares', aux_group_index, layer)
            added_tables.add(view)

        if missing_labels:
            log("[Aviso] Views de etiquetas em falta no GPKG (joins de labeling podem falhar): {}".format(
                ', '.join(missing_labels)))

        _apply_discovered_relations(project, log)
        _apply_gdal_relationships(project, gpkg_path, log)
        _create_ref_relations(project, vrs, log)
        _apply_joins(project, log)

        # Prefer relative GPKG paths so the project survives moving the file.
        # After relations/joins — setDataSource clears joins, so re-apply them.
        rel_base = './' + os.path.basename(gpkg_path)
        project.setPresetHomePath(os.path.dirname(gpkg_path))
        for layer in list(project.mapLayers().values()):
            if not isinstance(layer, QgsVectorLayer):
                continue
            src = layer.source()
            if not src.startswith(gpkg_path):
                continue
            style_doc = QDomDocument('qgis')
            layer.exportNamedStyle(style_doc)
            new_src = rel_base + src[len(gpkg_path):]
            layer.setDataSource(
                new_src, layer.name(), 'ogr', QgsDataProvider.ProviderOptions())
            if layer.isValid():
                layer.importNamedStyle(style_doc)
            else:
                layer.setDataSource(
                    src, layer.name(), 'ogr', QgsDataProvider.ProviderOptions())
                layer.importNamedStyle(style_doc)

        _apply_joins(project, log)

        _set_feature_counts(root)
        ta = dgt_group.findGroup('Tabelas Auxiliares')
        if ta:
            ta.setExpanded(False)

        uri = 'geopackage:{0}?projectName={1}'.format(gpkg_path, PROJECT_NAME)
        project.setFileName(uri)
        ok = project.write(uri)
        if ok:
            log("[Sucesso] Projeto QGIS '{}' gravado em {}".format(
                PROJECT_NAME, gpkg_path))
            log("Abrir em QGIS: Projeto → Abrir de → GeoPackage "
                "(ou URI geopackage:{}?projectName={})".format(gpkg_path, PROJECT_NAME))
        else:
            log("[Erro] Falha a gravar projeto QGIS no GeoPackage")
        return bool(ok)
    finally:
        project.clear()
