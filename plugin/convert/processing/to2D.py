def get_feature(feature):
    geom = feature.GetGeometryRef()
    if geom.Is3D():
        geom.FlattenTo2D()

    return "'srid=3763;" + geom.ExportToWkt() + "'"
