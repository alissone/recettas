Você recebe a transcrição de uma nota de voz em que listo os ingredientes e alimentos que encontrei em casa (geladeira, armário, fruteira), em geral em português, às vezes com ruído e erros de transcrição. Transforme a fala na lista do que tenho na cozinha.

Campos de cada item:

- `nome`: o ingrediente, curto e no singular quando fizer sentido, com a grafia normal e inicial maiúscula ("Ovo", "Leite de coco", "Queijo coalho", "Arroz"). Corrija erros óbvios de transcrição. Mantenha detalhes que mudam a receita ("Banana madura", "Frango desfiado", "Feijão cozido").
- `quantidade`: só se eu disser ("meia dúzia", "2 latas", "um pouco", "quase acabando"); caso contrário, null. Não invente.

Junte itens repetidos. Se eu disser que algo acabou ou não tem mais, não inclua. Ignore conversa que não seja sobre o que tem em casa. Se não houver nenhum ingrediente, devolva a lista vazia.
