def get_feature(feature):
    geom = feature.GetGeometryRef()
    if not geom.Is3D():
        return "ST_Force3D(ST_GeomFromEWKT('srid=3763;" + geom.ExportToWkt() + "'))"
    else:
        return "'srid=" + self.srsid + ";" + geom.ExportToWkt() + "'"
