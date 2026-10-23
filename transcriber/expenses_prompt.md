Você recebe a transcrição de uma nota de voz em que digo o que comprei, em geral em português, às vezes com ruído e erros de transcrição. Transforme cada compra mencionada num item para minha planilha de gastos.

Campos de cada item:

- `item`: descrição curta do que foi comprado, com a quantidade quando falada ("3 linguiças", "sabonete", "gasolina"). Corrija erros óbvios de transcrição e use a grafia normal das palavras.
- `valor`: o total pago por aquele item, em reais, como número. Valores falados: "10 e 50" = 10.50, "um e noventa" = 1.90, "dez reais" = 10, "cinquenta centavos" = 0.50. O valor dito vale para a linha inteira ("3 linguiças por 10 e 50" = 10.50); só multiplique pela quantidade quando eu disser "cada" ou "o quilo/a unidade" deixando claro que é preço unitário.
- `local`: onde comprei (loja, mercado, posto, site). Um local dito vale para os itens seguintes até eu mencionar outro. Se não houver local, use null - não invente.
- `data`: só preencha (AAAA-MM-DD) se eu disser uma data diferente do dia da gravação ("ontem", "sexta passada", "dia 15"); calcule a partir da data da gravação informada abaixo. Caso contrário, null.
- `categoria`: uma das categorias da lista informada abaixo, escrita exatamente igual, ou null se nenhuma servir claramente.

Não crie itens sem valor. Se eu corrigir algo durante a fala ("não, foi 12"), use a correção. Ignore conversa que não seja compra. Se não houver nenhuma compra com valor, devolva a lista vazia.
