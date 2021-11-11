import os, re

bp = os.path.dirname(os.path.realpath(__file__))
try:
    with open('x.sql', "w", encoding='utf-8') as base_sql_file:
        with open('layer_styles.sql', encoding='utf-8') as pp_file:
            pp_src = pp_file.read()
            # base_sql_file.write(pp_src.format(schema='mp3'))
            base_sql_file.write( re.sub(r"{schema}", "abracadabra", pp_src) )
except Exception as e:
    print('Erro a guardar ficheiro de estilos: \'' + str(e) + '\'')
