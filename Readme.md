## A aplicações informática recartDGT

A aplicação recartDGT oferece algumas funcionalidades para se tirar o melhor partido do novo modelo CartTop. O modelo CartTop resulta das [especificações técnicas](https://www.dgterritorio.pt/sites/default/files/ficheiros-cartografia/NormasEspecificacoesTecnicasCartTop.pdf) de cartografia topográfica publicadas pela Direção Geral do Território.

### Plugin QGIS recartDGT

O plugin recartDGT é uma aplicação informática, que funciona a partir do QGIS, com as seguintes funcionalidades:
- Visualização da Informação Geográfica (adquirida ao abrigo das normas CartTop)
- Validação da Informação Geográfica (adquirida ao abrigo das normas CartTop)
- Conversão da Informação Geográfica (adquirida ao abrigo das normas CartTop) para outros formatos (GPKG, SHP e GeoJSON)
- Conversão da Informação Geográfica antiga (produzida usando o modelo numérico, multicodificada, em DGN/DWG) para CartTop

### Instalação do plugin recartDGT

#### Descarregar o plugin recartDGT

O plugin recartDGT está disponível em [recartDGT.zip](https://gitlab.com/geomaster/dgt-recart/-/blob/master/plugin/recartDGT.zip). 

No [repositório do recart](https://gitlab.com/geomaster/dgt-recart) está disponível o código fonte. Pode-se e deve-se usar o repositório para reportar questões.

#### Instalar o plugin

O plugin deve ser instalado numa versão do QGIS 3.x. 

Para instalar o plugin, escolhe-se no menu a opção Plugins → Manage and Install Plugins...
1. Escolher "Install from ZIP"
2. Escolher o arquivo recartDGT.zip descarregado
3. Proceder à instalação, primindo o botão Install Plugin

O plugin é instalado e fica disponível no menu Plugins.

### Utilização do plugin

O plugin tem funcionalidades distintas e, por isso, tem desde logo três opções no menu, consoante o trabalho pretendido.

#### Visualização de informação CartTop

![](images/carttop2qgis.webm)

#### Validação da informação em CatTop

![](images/carttop-validation.webm)

#### Cartografia antiga (multicodificada) para CartTop

![](images/mnt2carttop.webm)

#### CartTop para Shapfile ou Geopackage

![](images/carttop2gpkg.webm)

### Limitações

Por desenho, a conversão de DGN/DWG deve ser feita para um esquema novo, sem dados. O plugin não tem a capacidade de acrescentar dados a uma conversão anterior. Por essa razão, deve-se escolher um esquema novo para o destino da conversão de MNT para CartTop.

### Opções avançadas

Segue uma breve descrição das opções de conversão de MNt para CartTop.
#### Forçar dimensões da geometria

O CartTop estabelece as geometrias que têm que ser 2D ou 3D. 

Com esta opção ativada, o plugin tenta ajustar a dimensão da geometria original para a adequada em CartTop. Por exemplo, se a geometria tiver que ser 3D, como no caso das curvas de nível, é acrescentada essa dimensão se estiver em falta (com o valor 0).
#### Forçar polígonos

Com esta opção ativada, o plugin tenta correr um algoritmo de **poligonização** de linhas. Por exemplo, se uma construção estiver como linha, tenta-se formar um polígono com as linhas das geometrias originais.

#### Associar código desconhecidos a códigos existentes

Na conversão de cartografia, podem surgir códigos nos DGN/DWG desconhecidos. 

Os códigos desconhecidos podem ser tratados de duas formas:
1. A forma mais complexa consiste em acrescentar novos mapeamentos para esses códigos desconhecidos, há semelhança dos muitos mapeamentos existentes. Para tal, é preciso editar o `plugin/convert/mapping.py`.
2. A forma amis simples consiste em mapear os códigos desconhecidos em códigos conhecidos. Isso faz-se criando um ficheiro de __alias p/ códigos__, que depois é indicado na correspondente opção no plugin.

##### Alias p/ Códigos

É um ficheiro com pares: __código desconhecido__ x __código conhecido__. Exemplo fictício:

```json
{
    "04060704-T_IGREJA": "04060704",
    (...)
}
```

No caso ilustrado, sempre que o multicódigo `04060704-T_IGREJA` apareça, é substituído pelo multicódigo `04060704`.

Para ajudar a identificar os multicódigos presentes num arquivo que se pretende converter, pode-se usar a ferramenta `create_map.py`. Exemplo de invocação:
```bash
python3 create_map.py -f 29_2_31MNT2K.dwg -a Layer
```
É gerado um arquivo `map.json` com todos os multicódigos presentes em `29_2_31MNT2K.dwg`. Deve ser posteriormente editado manualmente.
