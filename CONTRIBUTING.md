## Pull requests

São bem-vindas possíveis contribuições para este repositório. Os PR devem ser acompanhados de uma descrição clara do seu objetivo e do impacto inerente.

### PR para atualizar / corrigir mapeamentos

Para alterar um mapeamento do anterior sistema MNT para o Recart deve ser editado o ficheiro corresponde ao código MNT localizado na pasta `tools/gmcc/mapping`.

Quando o PR for submetido é executada uma ação automática no GitHub onde o ficheiro de mapeamento global utilizado pelo plugin é atualizado.

## Releases do plugin (contribuidores com _write access_)

Para criar uma nova release do plugin incluindo a mais recente versão do repositório deve ser criada uma nova tag. O seguinte código exemplifica a criação de uma tag, assumindo que o repositório do recart-plugin está configurado como _upstream_.


```bash
git checkout main
git pull upstream main
git tag -a v1.3 -m "Release 1.3"
```

Quando se realiza o push de uma nova tag para o repositório é executada uma ação automática no GitHub que compila um novo plugin e o publica.

```bash
git push upstream --tags
```
