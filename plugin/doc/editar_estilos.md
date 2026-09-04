# Editar estilos do plugin

Os estilos das camadas Recart estão em `plugin/convert/processing/<versão>/layer_styles.sql`. O plugin injeta este SQL na base de dados PostGIS e usa o QML no projeto GeoPackage.

Há um ficheiro por versão CartTop (`v1.1.2`, `v2.0.1`, `v2.0.2`). Apenas se deve editar estilos a partir de um projeto da **mesma** versão.

## 1. Abrir o projeto

Com o RecartDGT, carregar a base PostGIS CartTop da versão alvo. Confirmar que `public.layer_styles` existe na base de dados e que estão no projeto QGIS todas as camadas a alterar.

## 2. Alterar no QGIS

Editar simbologia, etiquetas e o resto do estilo nas camadas.

## 3. Gravar todas as camadas na base de dados

Limpar os estilos antigos **depois** das edições e **antes** de gravar. Sem isto ficam linhas duplicadas:

```sql
DELETE FROM public.layer_styles;
```

Na consola Python do QGIS, correr o código abaixo:

```python
mapGeometryType = {
    0: "Point",
    1: "Line",
    2: "Polygon",
    3: "UnknownGeometry",
    4: "NullGeometry",
}

export_categories = (
    QgsMapLayer.StyleCategory.LayerConfiguration
    | QgsMapLayer.StyleCategory.Symbology
    | QgsMapLayer.StyleCategory.Labeling
    | QgsMapLayer.StyleCategory.Fields
    | QgsMapLayer.StyleCategory.Rendering
    | QgsMapLayer.StyleCategory.Relations
)

layers = QgsProject.instance().mapLayers()

for layer in layers.values():
    if layer.type() == QgsMapLayer.VectorLayer:
        if mapGeometryType[layer.geometryType()] != "NullGeometry":
            print(layer.name())
            layer.saveStyleToDatabase(
                name=layer.name(),
                description="Default style for {}".format(layer.name()),
                useAsDefault=True,
                uiFileContent="",
                categories=export_categories,
            )
```

## 4. Exportar para o plugin

Utilizar o seguinte script para criar o novo `layer_styles`:

```bash
./plugin/export_layer_styles.sh -p 5434 \
  -o plugin/convert/processing/<versão>/layer_styles.sql \
  <pg_service>
```

Ajustar a versão no caminho (`v1.1.2`, `v2.0.1`, `v2.0.2`), o serviço PostgreSQL e `-p` se a porta não for 5434.
