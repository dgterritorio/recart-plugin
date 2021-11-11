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