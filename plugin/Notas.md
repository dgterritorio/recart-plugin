### Guardar todos os estilos de um projeto QGIS em base de dados

```python
mapGeometryType = {
    0: "Point",
    1: "Line",
    2: "Polygon",
    3: "UnknownGeometry",
    4: "NullGeometry",
}

layers = QgsProject.instance().mapLayers()

for layer in layers.values():
    if layer.type() == QgsMapLayer.VectorLayer:
        if mapGeometryType[layer.geometryType()] != "NullGeometry":
            layer.deleteStyleFromDatabase
            layer.saveStyleToDatabase(name=layer.name(),description="Default style for {}".format(layer.name()), useAsDefault=True, uiFileContent="")
```

```
from osgeo import gdal
dataSource = gdal.OpenEx('PG:service=carttop', gdal.OF_VECTOR, open_options=['SCHEMAS=public', 'LIST_ALL_TABLES=YES'])

pc = dataSource.GetLayerByName('lig_valor_tipo_circulacao_seg_via_rodov')
pc = dataSource.GetLayerByName('ponto_cotado')
```

### SQL dos estilos

Replace 'geobox', NULL, '2021-[^']+', por nada
'amria8' por '{schema}'

VALUES \(\d+, 'enderecos',
VALUES (

INSERT INTO public.layer_styles
INSERT INTO public.layer_styles (f_table_schema, f_table_name, f_geometry_column, stylename, styleqml, stylesld, useasdefault, description, type)     

<defaultAction value="{00000000-0000-0000-0000-000000000000}" key="Canvas"/>

### Relações

Name: valor_tipo_curva_id
Referenced Layer: valor_tipo_curva
Referenced Field: identificador

Referencing Layer: Curva de Nível
Referencing Layer id: 
Referencing field: valor_tipo_curva ← Alterar este campo no formulário

```python
layer = iface.activeLayer()
fields = layer.fields()
field_idx = fields.indexOf( 'valor_tipo_curva' )
widget = layer.editorWidgetSetup(field_idx)
widget.type()
'RelationReference'

widget.config()
{'AllowAddFeatures': False, 
'AllowNULL': False, 
'MapIdentification': False, 
'OrderByValue': False, 
'ReadOnly': False, 
'ReferencedLayerDataSource': 'service=\'ortos\' key=\'identificador\' checkPrimaryKeyUnicity=\'1\' table="amria33"."valor_tipo_curva"', 
'ReferencedLayerId': 'valor_tipo_curva_893ee987_56cb_4c29_a933_6cae8f7e3a44', 
'ReferencedLayerName': 'valor_tipo_curva', 
'ReferencedLayerProviderKey': 'postgres', 
'Relation': 'Curva_de_nível_8c7e8424_4b68_464f_b7e3_ce0884cee5fa_valor_tipo_curva_valor_tipo_curva_893ee987_56cb_4c29_a933_6cae8f7e3a44_identificador', 
'ShowForm': False, 
'ShowOpenFormButton': True}
```

```
        layer = rel.referencingLayer()
        fields = layer.fields()
        field = fields[ rel.referencingFields()[0] ]
        field_idx = fields.indexOf(field.name())

        config = {'AllowAddFeatures': False, 
            'AllowNULL': False, 
            'MapIdentification': False, 
            'OrderByValue': False, 
            'ReadOnly': False, 
            'ReferencedLayerDataSource': 'service=\'ortos\' key=\'identificador\' checkPrimaryKeyUnicity=\'1\' table="amria33"."valor_tipo_curva"', 
            'ReferencedLayerId': 'valor_tipo_curva_893ee987_56cb_4c29_a933_6cae8f7e3a44', 
            'ReferencedLayerName': 'valor_tipo_curva', 
            'ReferencedLayerProviderKey': 'postgres', 
            'Relation': 'Curva_de_nível_8c7e8424_4b68_464f_b7e3_ce0884cee5fa_valor_tipo_curva_valor_tipo_curva_893ee987_56cb_4c29_a933_6cae8f7e3a44_identificador', 
            'ShowForm': False, 
            'ShowOpenFormButton': True}

        # config['Relation'] = rel.name()
        config['Relation'] = rel.id()
        # config['ReferencedLayerId'] = rel.referencedLayer().id()
        # config['ReferencedLayerDataSource'] = layer.dataProvider().uri().uri()
        # config['ReferencedLayerName'] = rel.referencedLayer().name()
        
        widget_setup = QgsEditorWidgetSetup('RelationReference',config)
        layer.setEditorWidgetSetup(field_idx, widget_setup)
```

[Sucesso] Camada 'area_trabalho' exportada
Aguarde o carregamento das camadas, por favor...
Relações encontradas: 
Processo exportação terminado

### Geração do ficheiro de mapping para o plugin

```
jgr@dragon:~/dev/python/dgt-recart/tools/gmcc$ python3 generate_plugin_mapping_file.py
```


[Erro]
	Exception: Error while connecting to PostgreSQL [Errno 2] No such file or directory: '/media/jgr/WUHAN/tmp/163_4AGR.dgn"_base.sql'

, ( 'srid=3763;LINESTRING (-34505.08 146558.18,-34535.53 146564.96)', now(), '-99999', '4', '14', '12', '['7.2', '8.4']', '[{"table": "equip_util_coletiva", "fields": {"nome": "SEM DADOS", "valor_tipo_equipamento_coletivo": ["7.4"]}, "connection": "lig_equip_util_coletiva_edificio"}]', 6120106, 'elements' )

Editar a tool à mão...

tools/gmcc/mapping_tool.py

[Erro]
	Exception: Error while connecting to PostgreSQL lwgeom_unaryunion_prec: GEOS Error: TopologyException: side location conflict at -34490.874676624648 139335.33373398212. This can occur if the input geometry is invalid.

2021-06-05 22:31:22.913 WEST [87757] geobox@enderecos ERROR:  lwgeom_unaryunion_prec: GEOS Error: TopologyException: side location conflict at -34490.874676624648 139335.33373398212. This can occur if the input geometry is invalid.

/media/jgr/WUHAN/CAD2SIG/AMRia/AMRia_TOP_DGN_V7/143_4CON.dgn

[Erro]
	Exception: Error while connecting to PostgreSQL relation "amria_con._aux_elem_assoc_eletricidade" does not exist
LINE 83572: from amria_con._aux_elem_assoc_eletricidade

[Erro]                 ^

Converter dados
Erro a guardar ficheiro '/media/jgr/WUHAN/tmp33/20210614193512_features.sql': 'MultiLineString'
Erro a guardar ficheiro de remaining: ''MultiLineString25D''
[Erro]
	Exception: Error while connecting to PostgreSQL syntax error at end of input
LINE 2369: , 
             ^
### Validação

[Erro]
	Exception: Error while connecting to PostgreSQL relation "valor_tipo_no_trans_rodov" does not exist
LINE 20:   from amria33.no_trans_rodov ntr, valor_tipo_no_trans_rodov...
                                            ^
QUERY:  with 
shortest_line_itr_svr as (SELECT
  all_itr.identificador as itr_id,
  closest_svr.identificador as svr_mais_proximo_id,
  closest_svr.dist as distancia,
  ST_3DShortestLine( all_itr.geometria, closest_svr.geometria) as geometria
 from amria33.infra_trans_rodov as all_itr
CROSS JOIN LATERAL (SELECT
      identificador, 
      geometria,
      ST_3DDistance(svr.geometria, all_itr.geometria) as dist
      from amria33.seg_via_rodov svr
      ORDER BY all_itr.geometria <-> svr.geometria
     LIMIT 1
   ) AS closest_svr),
total as (select count(*) from amria33.infra_trans_rodov),
good as (select count(*)
  from shortest_line_itr_svr
  where st_endpoint(geometria) in (select ntr.geometria 
		from amria33.no_trans_rodov ntr, valor_tipo_no_trans_rodov vtntr 
		where ntr.valor_tipo_no_trans_rodov = vtntr.identificador and vtntr.descricao = 'Infraestrutura')),
bad as (  select count(*)
  from shortest_line_itr_svr
  where st_endpoint(geometria) not in (select ntr.geometria 
		from amria33.no_trans_rodov ntr, valor_tipo_no_trans_rodov vtntr 
		where ntr.valor_tipo_no_trans_rodov = vtntr.identificador and vtntr.descricao = 'Infraestrutura'))
select total.count as total, good.count as good, bad.count as bad
from total, good, bad 
CONTEXT:  PL/pgSQL function validation.do_validation(boolean) line 17 at EXECUTE

Terminada a validação

### Exportação para Geopackage

A carregar camadas da fonte de dados...
[Sucesso] Camadas carregadas
A exportar camadas ...
A exportar para /home/jgr/export.gpkg
A exportar a camada concelho
A exportar a camada distrito
A exportar a camada fronteira
A exportar a tabela valor_estado_fronteira
A exportar a camada freguesia
A exportar a camada designacao_local
A exportar a tabela valor_local_nomeado
A exportar a camada curva_de_nivel
A exportar a tabela valor_tipo_curva
A exportar a camada linha_de_quebra
A exportar a tabela valor_classifica
A exportar a tabela valor_natureza_linha
A exportar a camada ponto_cotado
A exportar a tabela valor_classifica_las
A exportar a camada agua_lentica
A exportar a tabela valor_agua_lentica
A exportar a tabela valor_persistencia_hidrologica
A exportar a camada barreira
A exportar a tabela valor_barreira
A exportar a camada curso_de_agua_area
A exportar a camada curso_de_agua_eixo
A exportar a tabela valor_posicao_vertical
A exportar a tabela valor_curso_de_agua
A exportar a camada fronteira_terra_agua
A exportar a camada margem
A exportar a tabela valor_tipo_margem
A exportar a camada nascente
A exportar a tabela valor_tipo_nascente
A exportar a camada queda_de_agua
A exportar a camada no_hidrografico
A exportar a tabela valor_tipo_no_hidrografico
A exportar a camada zona_humida
A exportar a tabela valor_zona_humida
A exportar a camada area_infra_trans_via_navegavel
A exportar a tabela valor_tipo_area_infra_trans_via_navegavel
A exportar a camada area_infra_trans_cabo
A exportar a camada area_infra_trans_rodov
A exportar a tabela infra_trans_rodov
A exportar a camada area_infra_trans_ferrov
A exportar a tabela infra_trans_ferrov
A exportar a camada area_infra_trans_aereo
A exportar a tabela valor_tipo_area_infra_trans_aereo
A exportar a camada infra_trans_via_navegavel
A exportar a tabela valor_tipo_infra_trans_via_navegavel
A exportar a camada linha_ferrea
A exportar a camada infra_trans_aereo
A exportar a tabela valor_categoria_infra_trans_aereo
A exportar a tabela valor_restricao_infra_trans_aereo
A exportar a tabela valor_tipo_infra_trans_aereo
A exportar a camada no_trans_rodov
A exportar a tabela valor_tipo_no_trans_rodov
A exportar a camada obra_arte
A exportar a tabela valor_tipo_obra_arte
A exportar a camada seg_via_cabo
A exportar a tabela valor_tipo_via_cabo
A exportar a camada seg_via_ferrea
A exportar a tabela lig_segviaferrea_linhaferrea
A exportar a tabela valor_categoria_bitola
A exportar a tabela valor_estado_linha_ferrea
A exportar a tabela valor_posicao_vertical_transportes
A exportar a tabela valor_tipo_linha_ferrea
A exportar a tabela valor_tipo_troco_via_ferrea
A exportar a tabela valor_via_ferrea
A exportar a camada seg_via_rodov
A exportar a tabela lig_valor_tipo_circulacao_seg_via_rodov
[Erro]
	Exception: Received a NULL pointer.


### TIN

drop table if exists validation.curva_de_nivel_points_interval;
create table validation.curva_de_nivel_points_interval as
SELECT concat( identificador::text, '-', path[1]::text) as identificador, geom::geometry(POINTZ, 3763) as geometria
FROM (
SELECT cdn.identificador, (ST_DumpPoints(ST_LineInterpolatePoints(geometria, 1.0/st_length(geometria)))).*
from infoportugal.curva_de_nivel cdn
where st_length(geometria) > 1) as pontos;

drop table if exists validation.curva_de_nivel_ponto_cotado;
create table validation.curva_de_nivel_ponto_cotado as
SELECT pc.identificador::text, pc.geometria
from infoportugal.ponto_cotado pc, infoportugal.valor_classifica_las vc 
where pc.valor_classifica_las = vc.identificador and vc.descricao = 'Terreno'
union
select * 
from validation.curva_de_nivel_points_interval;

with tin as (SELECT ST_DelaunayTriangles(st_union(geometria)) as geom
from infoportugal.ponto_cotado pc)
select (ST_Dump(geom)).geom As geometria from tin;

CREATE TABLE IF NOT EXISTS validation.tin (
    id integer generated by default as identity NOT NULL PRIMARY KEY,
    geometria geometry(POLYGONZ, 3763) not null
);

insert into validation.tin ( geometria)
with tin as (SELECT ST_DelaunayTriangles(st_union(geometria)) as geom
from infoportugal.ponto_cotado pc)
select (ST_Dump(geom)).geom As geometria from tin;


with nos as (
	SELECT ST_GeomFromText('POINT(-23580 237270 70)', 3763) as geometria
	union 
	SELECT ST_GeomFromText('POINT(-23580 237260 70)', 3763) as geometria
),
neighbours as (
	select n.*, closest.identificador, closest.distancia, closest.z
	from nos as n
	cross join lateral (
	select identificador, ST_Distance(pc.geometria, n.geometria) as distancia,
	st_z( pc.geometria) as z
	from infoportugal.ponto_cotado pc
	ORDER BY n.geometria <-> pc.geometria
	limit 5
	) as closest
)
select neighbours.geometria, SUM(z/distancia)/SUM(1/distancia) as z_estimado
from neighbours
group by neighbours.geometria;


-- Com base no TIN
-- Ir buscar o TIN que contém o ponto
-- Usar o IDW com base nos 3 cantos do TIN
with nos as (
	SELECT ST_GeomFromText('POINT(-23580 237270 70)', 3763) as geometria
	union 
	SELECT ST_GeomFromText('POINT(-23580 237260 70)', 3763) as geometria
),
tin as (
select t.id, t.geometria, n.geometria as amostra
from validation.tin t, nos as n
where st_contains(t.geometria, n.geometria)
),
aux as (select amostra, (ST_DumpPoints(geometria)).*
from tin)
select amostra, array_agg(ST_Z(geom))
from aux
group by amostra;

